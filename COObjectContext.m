/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#include <stdio.h>
#import "COObjectContext.h"
#import "COObject.h"
#import "COGroup.h"
#import "COProxy.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COMetadataServer.h"
#import "COObjectServer.h"
#import "NSObject+CoreObject.h"

#define AVERAGE_MANAGED_OBJECTS_COUNT 1000

NSString *COObjectContextDidMergeObjectsNotification = @"COObjectContextDidMergeObjectsNotification";
NSString *COMergedObjectsKey = @"COMergedObjectsKey";

@interface COObject (FrameworkPrivate)
- (void) setObjectContext: (COObjectContext *)ctxt;
- (void) _setObjectVersion: (int)version;
@end

@interface COProxy (FrameworkPrivate)
- (id) _realObject;
- (void) _setRealObject: (id)anObject;
- (void) _setObjectVersion: (int)aVersion;
- (void) setObjectContext: (COObjectContext *)ctxt;
@end

@interface COObjectContext (Private)
- (int) latestVersion;
- (BOOL) isInvalidObject: (id)newObject forReplacingObject: (id)anObject;
- (void) tryMergeRelationshipsOfObject: (id)anObject intoInstance: (id)targetInstance;
- (void) commitMergeOfInstance: (id)temporalInstance forObject:  (id)anObject;
- (void) beginUndoSequenceIfNeeded;
- (void) endUndoSequenceIfNeeded;
- (void) endUndoSequence;
- (void) snapshotObject: (id)object shouldIncrementObjectVersion: (BOOL)updateVersion;
@end

@interface COObjectContext (GraphRollback)
- (void) _restoreToVersion: (int)aVersion;
- (NSMutableDictionary *) findAllObjectVersionsMatchingContextVersion: (int)aVersion;
@end

@implementation COObjectContext

static COObjectContext *currentObjectContext = nil;

+ (void) initialize
{
	if (self != [COObjectContext class])
		return;

	[self setCurrentContext: AUTORELEASE([[COObjectContext alloc] init])];	
}

/** Returns the current object context. */
+ (COObjectContext *) currentContext
{
	return currentObjectContext;
}

/** Sets the current object context. */
+ (void) setCurrentContext: (COObjectContext *)aContext
{
	ASSIGN(currentObjectContext, aContext);
}

/** Initializes and returns a new object context with a random UUID. */
- (id) init
{
	return [self initWithUUID: nil];
}

/** <init /> Initializes and returns a new object context for a given UUID. 
    If the UUID refers to an object context that is already known in the 
    metadata server, the returned instance will have a version that matches the 
    last change logged in the history of this context. */
- (id) initWithUUID: (ETUUID *)aContextUUID
{
	SUPERINIT

	BOOL isNewContext = (aContextUUID == nil);

	if (isNewContext)
	{
		_uuid = [[ETUUID alloc] init];
	}
	else
	{
		ASSIGN(_uuid, aContextUUID);
	}
	_version = [self latestVersion];

	_registeredObjects = [[NSMutableSet alloc] initWithCapacity: AVERAGE_MANAGED_OBJECTS_COUNT];
	_objectUnderRestoration = nil;
	[self setSnapshotTimeInterval: 100];
	[self setDelegate: nil];
	[self setMergePolicy: COOldChildrenMergePolicy];
	_firstUndoVersion = -1;
	_restoredVersionUndoCursor = -1;
	_isUndoing = NO;
	_isRedoing = NO;

	return self;
}

- (void) dealloc
{
	// NOTE: Delegate is a weak reference.
	DESTROY(_objectUnderRestoration);
	DESTROY(_registeredObjects);
	DESTROY(_uuid);

	[super dealloc];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@ id: %@ version: %i", 
 		[super description], [self UUID], [self version]];
}

/** Returns the lastest object context version in the metadata server.
    If the object context is new and hasn't logged a version in the metadata 
    server yet, returns 0. */
- (int) latestVersion
{
	/* The two following queries are equivalent, but max() returns a null row 
	   when no rows are selected, we could eventually modify 
	   -[COMetadataServer queryResultObjectWithPGResult:] to return NSNull in 
	   such case... the coalesce function may also eliminate this null row, but 
	   I cannot figure how to use it. 

	   SELECT max(contextVersion) FROM History WHERE contextUUID = '946e8e7c-9be5-4a79-7985-e6932736d058';
	   SELECT contextVersion FROM History WHERE contextUUID = '5901dd38-949-4245-6331-ed1019adc254' 
	   ORDER BY contextVersion DESC LIMIT 1; */

	id versionNumber = [[self metadataServer] executeDBQuery: [NSString stringWithFormat: 
		@"SELECT contextVersion FROM History WHERE contextUUID = '%@' "
		 "ORDER BY contextVersion DESC LIMIT 1;", [[self UUID] stringValue]]];

	if (versionNumber == nil)
		return 0;

	return [versionNumber intValue];
}

/** Returns the metadata server bound to this object context. 
    By default, returns -[COMetadataServer defaultServer]. */
- (COMetadataServer *) metadataServer
{
	// TODO: Make possible to use other metadata servers rather than just the 
	// default one. That will on the object context and object server in use. 
	return [COMetadataServer defaultServer];
}

/** Returns the object server bound to this object context. 
    By default, returns -[COObjectServer defaultServer]. */
- (COObjectServer *) objectServer
{
	return [COObjectServer defaultServer];
}	

/** Returns the delegate set for the receiver, otherwise returns nil. */
- (id) delegate
{
	return _delegate;
}

/** Sets the delegate for the receiver.
    The delegate is not retained. */
- (void) setDelegate: (id)aDelegate
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	if (_delegate != nil)
		[nc removeObserver: _delegate name: nil object: self];

	_delegate = aDelegate;

	if ([_delegate respondsToSelector: @selector(objectContextDidMergeObjects:)])
	{
		[nc addObserver: _delegate
		       selector: @selector(objectContextDidMergeObjects:)
		           name: COObjectContextDidMergeObjectsNotification 
		         object: self];
	}
}

/* Registering Managed Objects */

/** Returns the object identified by anUUID, if it exists and belongs to the 
    receiver or by deserializing a new instance if it doesn't exist. If the 
    object is cached in the object server but belongs to another object 
    context or no serialized object exists for an UUID, returns nil.
    If the returned object is a new instance deserialized by this method, 
    the new instance is registered in the receiver before getting returned. 
    If no serialized object exists for anUUID, this means either no such 
    UUID entry exist in the metadata server or that the URL bound to anUUID 
    doesn't point to a stored object that can be deserialized. */
- (id) objectForUUID: (ETUUID *)anUUID
{
	id object = [[self objectServer] cachedObjectForUUID: anUUID];
	BOOL boundToCachedObject = (object != nil);

	if (boundToCachedObject)
	{
		if ([_registeredObjects containsObject: object])
		{
			return object;
		}
		return nil;
	}
	
	object = [[self objectServer] objectWithUUID: anUUID];
	BOOL noPersistentObjectAvailable = (object == nil);

	if (noPersistentObjectAvailable)
		return nil;
	
	if ([object isKindOfClass: [COGroup class]])
		[object setHasFaults: YES];
	[self registerObject: object];
	
	return object;
}

/** Registers an object to belong to the receiver, then takes a base version 
    snapshot to make it immediately persistent. This inserts the object into 
    the metadata DB.
    See also -registerObject:. */
- (void) insertObject: (id)anObject
{
	[self registerObject: anObject];
	[self snapshotObject: anObject];
}

/** Registers an object to belong to the receiver.
    A managed core object can belong to a single object context at a time. Hence 
    you must unregister it before being able to move it from one context to 
    another one. 
    If you try to register an object that is already registered, an 
    NSInvalidArgumentException exception will be raised.
    You shouldn't usually called this method but rather -insertObject:. */
- (void) registerObject: (id)object
{
	if ([object objectContext] != nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Object %@ "
			"must not belong to another object context %@ to be registered", 
			object, [object objectContext]];
		return;
	}

	BOOL isAlreadyCached = ([[self objectServer] cacheObject: object] == NO);

	if (isAlreadyCached)
	{
		ETLog(@"WARNING: Object %@ has no object context but is wrongly cached "
			"in the object server %@. Won't register it.", object, [self objectServer]);
		return;
	}
	[[self objectServer] cacheObject: object];
	[object setObjectContext: self];
	[_registeredObjects addObject: object];
}

/** Unregisters an object so it doesn't belong anymore to the receiver.
    You must retain the object, otherwise it will be released. */
- (void) unregisterObject: (id)object
{
	[[self objectServer] removeCachedObject: object];
	/* Set the weak reference on the context to nil, before removing the object
	   because it may trigger its deallocation. */
	[object setObjectContext: nil];
	[_registeredObjects removeObject: object];
}

/** Returns all the managed core objects that belongs to receiver. */
- (NSSet *) registeredObjects
{
	return AUTORELEASE([_registeredObjects copy]);
}

/* Retrieves the URL where an object is presently serialized, or if it hasn't 
   been serializerd yet, builds the URL by taking the library to which the 
   object belongs to. */
- (NSURL *) serializationURLForObject: (id)object
{
	// NOTE: Don't check if object is registered because it might be a temporal 
	// instance (not registered) when -playbackInvocationsWithObject:toVersion:
	// calls us. If we want to enforce a check, we may add a category method 
	// -containsTemporalInstance: and/or -temporalMember: to NSSet.

	NSURL *url = [[self metadataServer] URLForUUID: [object UUID]];

	if (url == nil)
	{
		// TODO: Modify once we have proper library support.
		url = [[ETSerializer defaultLibraryURL] URLByAppendingPath: [[object UUID] stringValue]];
	}

	return url;
}

/** Sets the URL where the object will be serialized on the first save.
    If the object has already been saved in the past, isn't registered or url is 
    nil, returns NO.
    TODO: Raises an invalid argument exception is url is nil? */
- (BOOL) setSerializationURL: (NSURL *)url forObject: (id)object
{
	if ([_registeredObjects containsObject: object] == NO)
		return NO;

	NSURL *existingURL = [[self metadataServer] URLForUUID: [object UUID]];

	if (existingURL != nil)
		return NO;

	NSAssert2(existingURL == nil && [object objectVersion] == -1, @"If no URL/UUID "
		"pair exists in %@, the object version is expected to be -1 and not %i",
		[self metadataServer], [object objectVersion]);

	[[self metadataServer] setURL: url forUUID: [object UUID]];

	return YES;
}

/* Faulting */

/** Returns a real object by resolving the fault object passed in parameter.
    If the resolved object doesn't exist as a cached object and has to be 
    deserialized, the new instance is automatically registered into the receiver 
   and cached in the object server. */
- (id) resolvedObjectForFault: (id)aFault
{
	id cachedObject = [[self objectServer] cachedObjectForUUID: aFault];

	if (cachedObject != nil)
		return cachedObject;
	
	// TODO: We should delegate the choice of the object context to the object
	// server rather than simply inserting it into the receiver. This means 
	// managed object must be associated with a main object context that plays 
	// the role of an owner.
	return [self objectForUUID: aFault];
}

/** Returns the UUIDs of the all the objects that belongs the receiver for the 
    given version. 
    If you substract the UUIDs of the registered objects from the returned set, 
    the resulting set contains every faults that belongs to the object context. */
- (NSArray *) allObjectUUIDsMatchingContextVersion: (int)aVersion
{
	return [[self findAllObjectVersionsMatchingContextVersion: aVersion] allKeys];
}

/** Loads and registers all the objects that belongs to the receiver but are not
    yet loaded.
    These objects may exist as faults in the object graph by being referenced 
    by other objects. Take note this method won't resolve existing faults 
    that points to these objects within the loaded object graph. These pending 
    faults will lazily resolved the next time they are accessed (for example by 
    calling -members on a group). If you want to resolve them immediately, 
    you must call -[COObjectServer resolvePendingFaultsWithinCachedObjectGraph]. */
- (void) loadAllObjects
{
	NSArray *faults =  [self allObjectUUIDsMatchingContextVersion: [self version]];

	FOREACH(faults, eachFault, ETUUID *)
	{
		[self objectForUUID: eachFault];
	}
}

/* Merging */

/** Returns the current merge policy for children objects when a temporal 
    instance of a group is merged back into the receiver.
    See COChildrenMergePolicy for details. */
- (COChildrenMergePolicy) mergePolicy
{
	return _mergePolicy;
}

/** Sets the current merge policy for children objects when a temporal 
    instance of a group is merged back into the receiver.
   See COChildrenMergePolicy for details. */
- (void) setMergePolicy: (COChildrenMergePolicy)aPolicy
{
	_mergePolicy = aPolicy;
}

/** Replaces anObject registered in the receiver by another one which is 
    usually a temporal instance, but doesn't have to. Hence you can also use 
    this method to substitute an object by another one in the object context,
    and update the relationships of the first object to reference the new one. 
    Because the relationships are carried over, a replacement involves a merge.
    which adjusts the parent groups of the replaced object, so they now refer.
    Merging only occurs if you restore one or several registered objects, if 
    the whole object context is restored to a past version, the resulting object 
    graph will be in a coherent state and this method won't be called. */
- (COMergeResult) replaceObject: (id)anObject 
                       byObject: (id)temporalInstance 
               collectAllErrors: (BOOL)tryAll
{
	if ([self isInvalidObject: temporalInstance forReplacingObject: anObject])
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"Replaced Object %@ and replacement object %@ "
		                     "must be the same kind, either group or strict object", 
		                     anObject, temporalInstance];
		return COMergeResultFailed;
	}

	BOOL isTemporal = [temporalInstance isTemporalInstance: anObject];
	COMergeResult mergeResult = COMergeResultFailed;

	/* We disable the persistency, especially the recording of the invocations 
	   when a temporal instance is merged. The identity of the object to be 
	   merged is the same than the replaced object (UUIDs are identical), hence 
	   only the object replacement itself needs to be recorded, but not the 
	   relationships which are tracked by UUIDs. However relationships have to be 
	   fixed because the instance they refer to is now invalid.
	   Object replacement is recorded by simply snapshoting temporalInstance, 
	   this creates a new version with the old object state right after the last 
	   version of anObject. */
	if (isTemporal)
		[self beginRestoreObject: anObject];

	// HACK: Work around the issue explained in -[COGroup mergeObjectsWithObjectsOfGroup:]
	// It is safe to be do that here, because anObject still has a context and 
	// any UUID references that will got resolved to anObject are going to be 
	// properly replaced by temporalInstance by -updateRelationshipsToObject:
	if ([anObject isKindOfClass: [COGroup class]])
		[anObject resolveFaults];

	/* Swap the instances in the context */
	[self unregisterObject: anObject];
	[self registerObject: temporalInstance];

	// HACK: Next part of the work around.
	if ([temporalInstance isKindOfClass: [COGroup class]])
		[temporalInstance resolveFaults];

	mergeResult = [[self objectServer] updateRelationshipsToObject: anObject 
	                                                  withInstance: temporalInstance];

	 /* Now that parent references or backward pointers are fixed, if the two 
	    objects are groups we need to merge their member/children references. */
	[self tryMergeRelationshipsOfObject: anObject intoInstance: temporalInstance];

	[self commitMergeOfInstance: temporalInstance forObject: anObject];
	if (isTemporal)
		[self endRestore];

	return mergeResult;
}

- (BOOL) isInvalidObject: (id)newObject forReplacingObject: (id)anObject
{
	return (([anObject isKindOfClass: [COGroup class]] == NO && [newObject isKindOfClass: [COGroup class]])
	 || ([anObject isKindOfClass: [COGroup class]] && [newObject isKindOfClass: [COGroup class]] == NO));
}

/* Merges the members of anObject into the members of temporalInstance, if both 
   are COGroup or subclass instances.
   TODO: Eventually extends the merge facility to COObject, so that COObject 
   subclasses can create their own core objects relationships and handle the 
   merge in their own way, rather restricting this feature to COGroup. */
- (void) tryMergeRelationshipsOfObject: (id)anObject intoInstance: (id)targetInstance
{
	if ([targetInstance isKindOfClass: [COGroup class]] == NO)
		return;
	
	[targetInstance mergeObjectsWithObjectsOfGroup: anObject policy: [self mergePolicy]];
	// TODO: If the temporal instance is a group, we need to fix the 
	// kCOParentsProperty of all objects owned by this group.
	// We could handle this on COObject, but the best is probably in
	// -mergeObjectsWithObjectsOfGroup:policy: of COGroup.

}

/** Commits an object merge by syncing the object version and taking a snaphot 
    of the temporal instance now in use. 
    Right after that, both anObject and temporalInstance will reply to 
    -lastObjectVersion by returning [anObject objectVersion] + 1. */
- (void) commitMergeOfInstance: (id)temporalInstance forObject: (id)anObject
{
	BOOL isSingleObjectChange = ([self isRestoringContext] == NO);

	if (anObject != nil)
	{
		[temporalInstance _setObjectVersion: [anObject objectVersion]];
	}
	else
	{
		int lastObjectVersion = [[self metadataServer] objectVersionForUUID: [temporalInstance UUID]];
		[temporalInstance _setObjectVersion: lastObjectVersion];
	}

	// TODO: May be write unit tests to ensure we write the expected .save file 
	// and log the correct incremented version.
	[self snapshotObject: temporalInstance shouldIncrementObjectVersion: YES];
	ETDebugLog(@"Commit merge of %@", temporalInstance);
	[self logRecord: temporalInstance objectVersion: [temporalInstance objectVersion] 
		timestamp: [NSDate date] shouldIncrementContextVersion: isSingleObjectChange];	
}

/** Returns the errors that occured the last time 
   -replaceObject:byObject:collectAllErrors: was called.
   The previous errors are discarded each time the latter method is called. */
- (NSArray *) lastMergeErrors
{
	return _lastMergeErrors;
}

- (ETSerializer *) deltaSerializer
{
	return _deltaSerializer;
}

- (ETSerializer *) snapshotSerializer
{
	return _fullSaveSerializer;
}

/** Retrieves the delta serializer for a given object. */
- (ETSerializer *) deltaSerializerForObject: (id)object
{
	if ([object respondsToSelector: @selector(deltaSerializer)])
	{
		return [object deltaSerializer];
	}
	else /* Default case */
	{
		NSURL *serializationURL = [self serializationURLForObject: object];

		return [ETSerializer defaultCoreObjectDeltaSerializerForURL: serializationURL 
	                                                    version: [object objectVersion]];
		// FIXME: return [self deltaSerializer];
	}
}

/** Retrieves the snapshot serializer for a given object. */
- (ETSerializer *) snapshotSerializerForObject: (id)object
{
	if ([object respondsToSelector: @selector(snapshotSerializer)])
	{
		return [object snapshotSerializer];
	}
	else /* Default case */
	{
		NSURL *serializationURL = [self serializationURLForObject: object];

		return [ETSerializer defaultCoreObjectFullSaveSerializerForURL: serializationURL 
	                                                           version: [object objectVersion]];
		// FIXME: return [self snapshotSerializer];
	}
}

/* Navigating Context History */

/** Returns the UUID of the receiver that is used to identify the history of 
    the object context in the Metadata DB. */
- (ETUUID *) UUID
{
	return _uuid;
}

/** Returns the last version of the receiver that can be used to identify 
    the current state of the all the registered objects and eventually 
    restores to it a later point. The state of all registered objects remain 
    untouched until the next time this version value gets incremented. 
    An object context version is a timemark in the interleaved history of all 
    the registered objects. Each object context version is associated with a 
    unique set of object versions. If at a later point, you set the context 
    version to a past version, the context will restore back to the unique set of 
    temporal instances bound to this version. */
- (int) version
{
	return _version;
}

/** Restores the receiver to the given version.
    See also -version.*/
- (void) restoreToVersion: (int)aVersion
{
	[self _restoreToVersion: aVersion];
}

- (void) beginUndoSequence
{
	_firstUndoVersion = [self version] + 1;
	_restoredVersionUndoCursor = [self version];
}

- (void) endUndoSequence
{
	_firstUndoVersion = -1;
}

/** Restores the receiver to the last version right before the one currently 
    returned by -version, if no undo/redo sequence is underway. Then a new 
    undo/redo sequence is started.
    If an undo/redo sequence has already been started by calling -undo, restores
    the receiver to the last version right before the version restored by the 
    previous undo/redo action.
    An undo/redo sequence is cleared, when the context version is incremented 
    by another method than -undo or -redo.
    Be aware that undo/redo actions are logged into the history, then once 
    you exit an undo/redo sequence and you want to revert to a version and state 
    anterior to this undo/redo sequence, it's necessary to undo all undo/redo
    operations that belongs to the sequence and recorded by the context.
    This method calls -restoreToVersion:. */
- (void) undo
{
	BOOL noCurrentUndoSequence = (_firstUndoVersion == -1);

	if (noCurrentUndoSequence)
		[self beginUndoSequence];

	_isUndoing = YES;
	// TODO: Implement more useful undo models on top of this low-level model.
	[self restoreToVersion: --_restoredVersionUndoCursor];
	_isUndoing = NO;
}

/** Returns whether we are in an undo sequence or not. If YES, -redo will 
    restore the receiver to a past version. */
- (BOOL) canRedo
{
	return (_firstUndoVersion != -1);	
}

/** Restores the receiver to the first version right after the version restored 
    by the previous undo/redo action.
    If -canRedo returns NO, does nothing.
    See also -undo. */
- (void) redo
{
	if ([self canRedo] == NO)
		return;

	_isRedoing = YES;
	[self restoreToVersion: ++_restoredVersionUndoCursor];
	_isRedoing = NO;

	BOOL hasRevertedAllUndoActions = (_firstUndoVersion == _restoredVersionUndoCursor);

	if (hasRevertedAllUndoActions)
		[self endUndoSequence];
}

/** Returns whether an undo action triggered by -undo is currently underway for 
    the receiver. */
- (BOOL) isUndoing
{
	return _isUndoing;
}

/** Returns whether a redo action triggered by -redo is currently underway for 
    the receiver. */
- (BOOL) isRedoing
{
	return _isRedoing;
}

/** Returns YES when the whole context is currently getting restored to another 
    version than the current one, otherwise returns NO.
    See also -isRestoring. */
- (BOOL) isRestoringContext
{
	return _restoringContext;
}

/** Returns the first version forward in time which corresponds to a snapshot or
    a delta. If no such version can be found (no snapshot or delta available 
    unless an error occured), returns -1.
    If object hasn't been made persistent yet or isn't registered in the 
    receiver also returns -1. Hence this method returns -1 for restored 
    objects not yet inserted in an object context. */
- (int) lastVersionOfObject: (id)object
{
	return [[self objectServer] lastVersionOfObjectWithURL: [self serializationURLForObject: object]];
}

/** Returns the first version back in time, right before aVersion, which 
    corresponds to a snapshot and not a delta. If no such version can be found 
    (probably no snapshot available), returns -1. */
- (int) lastSnapshotVersionOfObject: (id)object forVersion: (int)aVersion
{
	NSURL *objectURL = [self serializationURLForObject: object];

	return [[self objectServer] lastSnapshotVersionOfObjectWithURL: objectURL
	                                                    forVersion: aVersion];
}

/** Restores the full-save version closest to the requested one.
    snpashotVersion is the object version of the returned snapshot object. If 
    you pass a non-NULL pointer, snapshotVersion is updated by the method 
    so you can get back the version number by reference.
    If object is a CoreObject proxy, then the returned object is this same proxy
    with its wrapped object set to the requested snapshot. */
- (id) lastSnapshotOfObject: (id)object 
                 forVersion: (int)aVersion 
            snapshotVersion: (int *)snapshotVersion;
{
	id snapshotDeserializer = [[self snapshotSerializerForObject: object] deserializer];
	int fullSaveVersion = [self lastSnapshotVersionOfObject: object forVersion: aVersion];

	if (fullSaveVersion < 0)
	{
		ETLog(@"Failed to find full save of %@ in %@", object, self);
		return nil;
	}

	if (snapshotVersion != NULL)
		*snapshotVersion = fullSaveVersion;

	[snapshotDeserializer setVersion: fullSaveVersion];
	id snapshotObject = [snapshotDeserializer restoreObjectGraph];

	if ([object isCoreObjectProxy])
	{
		[object _setRealObject: snapshotObject];
		[object _setObjectVersion: fullSaveVersion];
		return object;
	}
	else
	{
		[snapshotObject _setObjectVersion: fullSaveVersion];
		return snapshotObject;
	}
}

/** Returns a temporal instance of the given object, by finding the last 
    snapshot before aVersion, deserializing it and replaying all the serialized 
    invocations between this snapshot version and aVersion.
    The returned instance has no object context and isn't equal to anObject, 
    but returns YES to -isTemporalInstance:, because both anObject and the 
    restored object share the same UUID 
    even if they differ by their object version. 
    You cannot use a restored object as a persistent object until it 
    gets inserted in an object context. No invocations will ever be recorded 
    until it is inserted. It can either replace anObject in the receiver, or 
    anObject can be unregistered from the receiver to allow the insertion of the 
    restored object into another object context. This is necessary because a 
    given object identity (all temporal instances included) must belong to a 
    single object context per process.
    A managed core object identity is defined by its UUID. 
    The state of a restored object can be altered before inserting it in an 
    object context, but this is strongly discouraged.
    anObject can be a temporal instance of an object registered in the receiver.
    If aVersions is equal to the version of anObject, returns anObject and logs 
    a warning.
    If aVersion is beyong the version of anObject, returns nil and logs a 
    warning. 
    TODO: Raises exception or returns for nil object and object whose 
   identity/UUID doesn't match the one of any registered objects.

    TODO: Rewrite by including the following doc, make it a bit shorter and 
    moves the details in the CoreObject guide...
    Returns a past temporal instance of object and identified by version in the 
    history of the current object.
    If the requested version doesn't exist, typically by being posterior to the 
    last version, returns nil.
    Pass YES for mergeNow, if you want object to be automatically replaced by 
    the temporal instance the managed object graph. Passing NO is currently 
    discouraged: by sending messages to the temporal instance, the existing 
    object history posterior to version can be messed up by being fully or 
    partially overwritten. Future version of the framework could eventually 
    return locked temporal instances to limit this kind of corruption.
    In the rare case where -[object lastObjectVersion] and 
    -[object objectVersion] doesn't match, you can get an temporal 
    instance more recent than object. This should only happen if you try to 
    call -objectByRestoringObject:toVersion: with a temporal instance that 
    just got returned by the method, and hasn't been merged in the object 
    graph yet (see -anObjectject:byTemporalInstance:). You shouldn't rely on 
    this feature since it could be removed at any point in a future version of 
    the API. */
- (id) objectByRestoringObject: (id)anObject 
                       toVersion: (int)aVersion
                mergeImmediately: (BOOL)mergeNow
{
	int lastObjectVersion = [self lastVersionOfObject: anObject];

	if (aVersion > lastObjectVersion)
	{
		ETLog(@"WARNING: Failed to restore, the version %i is beyond the object history %i",
			aVersion, lastObjectVersion);
		return nil;
	}
	else if (aVersion == [anObject objectVersion])
	{
		ETLog(@"WARNING: Failed to restore, the version matches the object passed in parameter");
		return anObject;
	}

	int baseVersion = -1;
	id restoredObject = [self lastSnapshotOfObject: anObject 
	                                    forVersion: aVersion
	                               snapshotVersion: &baseVersion];
	ETDebugLog(@"Restore object %@ with snapshot %@ at version %d", anObject,
		restoredObject, baseVersion);

	[self playbackInvocationsWithObject: restoredObject 
	                        fromVersion: baseVersion
	                          toVersion: aVersion];
	
	if ([restoredObject isKindOfClass: [COGroup class]])
		[restoredObject setHasFaults: YES];

	// TODO: Simplify by getting rid of the two branches inside the if statement
	if (mergeNow)
	{
		if ([anObject isCoreObjectProxy])
		{
			NSAssert([restoredObject isCoreObjectProxy], @"Restored object must be a proxy if the current object is one");
			NSAssert(restoredObject == anObject, @"Restored object must be identical to the current object, if the latter one is a proxy");
			[self commitMergeOfInstance: restoredObject forObject: nil];
		}
		else
		{
			[self replaceObject: anObject byObject: restoredObject collectAllErrors: YES];
		}
	}

	return restoredObject;
}

/** Plays back each of the subsequent invocations on object.
    The invocations that will be invoked on the object as target will be the 
    all invocation serialized between baseVersion and finalVersion. The first 
    replayed invocation will be 'baseVersion + 1' and the last one 
    'finalVersion'. 
    If you pass a CoreObject proxy, the invocations are transparently replayed 
    on the wrapped object. */
- (void) playbackInvocationsWithObject: (id)object 
                           fromVersion: (int)baseVersion 
                             toVersion: (int)finalVersion 
{
	if ([self isRestoring])
	{
		[NSException raise: NSInternalInconsistencyException format: 
			@"Invocations cannot be played back on %@ when the context %@ is "
			@"already restoring another object %@", object, self, 
			[self currentObjectUnderRestoration]];
	}
	
	[self beginRestoreObject: object];

	ETDeserializer *deltaDeserializer = [[self deltaSerializerForObject: object] deserializer];
	[deltaDeserializer playbackInvocationsWithObject: object fromVersion: baseVersion toVersion: finalVersion];

	[self endRestore];
}

#if 0
- (BOOL) canApplyChangesToObject: (id)object
{
	return ![self shouldIgnoreChangesToObject: object];
}
#endif

/** Returns YES when an object is currently getting restored to a past version, 
    otherwise returns NO.
    See also -isRestoringContext. */
- (BOOL) isRestoring
{
	return ([self currentObjectUnderRestoration] != nil);
}

/** Returns the registered object for which 
    -objectByRestoringObject:toVersion:mergeImmediately: is currently executed. */
- (id) currentObjectUnderRestoration
{
	return _objectUnderRestoration;
}

/** Returns whether object is a temporal instance of a given object owned by
	the context. 
	The latter object is called a current object in such situation.
	The restored object doesn't belong to the receiver, because it is a 
	temporal instance that can be retrieved only by requesting it to the 
	receiver for a current object with the same UUID (the object already 
	inserted/owned by the receiver context). */
- (BOOL) isRestoredObject: (id)object
{
	return ([[object UUID] isEqual: [[self currentObjectUnderRestoration] UUID]]
		&& ([[self registeredObjects] containsObject: object] == NO));
}

/** Marks the start of a restore operation.
    A restore operation might involve exchanges of messages among the 
    registered objects or state alteration, that must not be recorded.
    By calling this method, you ensure -shouldIgnoreChangesToObject: will 
    behave correctly. */
- (void) beginRestoreObject: (id)object
{
	ASSIGN(_objectUnderRestoration, object);
}

/** Marks the end of a restore operation, thereby enables the recording of 
    invocations. */
- (void) endRestore
{
	ASSIGN(_objectUnderRestoration, nil);
}

/** Returns YES if anObject is a temporal instance of an object registered in 
    the receiver and a restore operation is underway, otherwise returns NO.
    This method is mainly useful to decide whether a managed method should 
    return immediately or execute and mutate the state of the model object its 
    belongs to. 
    The rule is to ignore all side-effects triggered by a managed method during 
    a restore. If a restore is underway, all changes must be applied only to the 
    restored object (not belonging to the object context) and any other 
    messages sent by the restored object to other objects must be ignored. 
    The fact these objects belongs to the object context or not doesn't matter: 
    temporal instances when they got just restored are in a state that can be
    incoherent with other objects in memory. 
    See also -isRestoredObject:. */
- (BOOL) shouldIgnoreChangesToObject: (id)anObject
{
	return ([self isRestoring] && ([self isRestoredObject: anObject] == NO));
}

/* If this method returns NO, -recordInvocation: will refuse the invocation 
   serialization. 
   -recordInvocation: calls it with the invocation target.*/
- (BOOL) shouldRecordChangesToObject: (id)object
{
	return [object isEqual: [self currentRecordSessionObject]];
}

/** Returns the new object version of the target for which the invocation was 
    recorded. If the invocation isn't recorded, then the returned version is 
    identical to the current object version of the invocation target. 
    The invocation is recorded in three steps:
    - the invocation is serialized (eventually a snapshot is taken too)
    - the basic object infos stored in the metadata DB are updated for the 
      invocation target
    - the record operation is logged in the receiver history.
    For more details on each step, see respectively -serializeInvocation;,
    -updateMetadatasForObject:recordVersion:, 
    -logRecord:objectVersion:timestamp:shouldIncrementContextVersion:.
    Finally this method returns the new object version to the invocation target 
    that is in charge of updating the value it returns for -objectVersion.
    See also -shouldRecordChangesToObject: and RECORD macro in COUtility.h */
- (int) recordInvocation: (NSInvocation *)inv
{
	id object = [inv target];

	// TODO: Generalize this check to all methods that require it
	if ([_registeredObjects containsObject: object] == NO)
		return [object objectVersion];

	if ([self isRecording])
	{
		[self beginRecordObject: [inv target]];

		/* Only record if needed, although we always push the target of the record 
			on the recorded object stack.
			That may change in future, we could return NO when the target of the 
			of the record is already on stack and the message won't be recorded. We 
			would return YES otherwise, when pushing the target on the record stack 
			for the first time. This change would mean not to call -endRecord if NO
			is returned. This check could be hidden in END_RECORD macro by keeping 
			around the boolean result of -recordInvocation: with RECORD. */
		if ([[inv target] isEqual: [self currentRecordedObject]])
			return [[inv target] objectVersion];
	}
	else /* Initiate a new record session */
	{
		[self beginRecordSessionWithObject: [inv target]];
	}

	int newObjectVersion = [self serializeInvocation: inv];

	/* -[object objectVersion] still returns the old version at this point, 
	   so we pass the new version in parameter with recordVersion: */
	[self updateMetadatasForObject: object recordVersion: newObjectVersion];
	[self logRecord: inv objectVersion: newObjectVersion timestamp: [NSDate date]
		shouldIncrementContextVersion: YES];

	return newObjectVersion;
}

- (int) serializeInvocation: (NSInvocation *)inv
{
	id object = [inv target];
	id deltaSerializer = nil;
	int version = [object objectVersion];

	/* First Snapshot if needed (aka Base Version) */
	if (version == -1)
	{
		/* Don't call simply -snapshotObject: in order to call 
		   -updateMetadatasForObject: a single time on return in -serializeInvocation:
		   In this precise case, we increment the object version directly for 
		   the snapshot. The increment for the recorded invocation will be 
		   handled by 'object' itself when -serializeInvocation: returns. */
		[self snapshotObject: object shouldIncrementObjectVersion: YES];
		version = [object objectVersion];
		[self logRecord: inv objectVersion: version timestamp: [NSDate date]
			shouldIncrementContextVersion: YES];
		NSAssert(version == 0, @"First serialized version should have been reported");
	}

	/* Record */
	deltaSerializer = [self deltaSerializerForObject: object];
	[inv setTarget: nil];
	/* Don't use [deltaSerializer newVersion]; here because 
	   -serializeObject:withName: already takes care of calling -newVersion.
	   No need to call -setVersion: either because -deltaSerializerForObject: 
	   initializes the serializer with the current object version.
	   The invocation is written on disk as (version + 1).save and we 
	   retrieve this new version. */
	[deltaSerializer serializeObject: inv withName: @"Delta"];
	version = [deltaSerializer version];
	ETDebugLog(@"Serialized invocation with version %d", version);

	/* Forward if needed */
	[inv setTarget: object];
	[self forwardInvocationIfNeeded: inv];

	/* Snapshot if needed, by periodically saving a full copy */
	if (version % [self snapshotTimeInterval] == 0)
		[self snapshotObject: object shouldIncrementObjectVersion: NO];

	/* Object version should keep its initial value and is normally set to the 
	   returned 'version' value by the sender, that is usually 'object'. */
	NSAssert(version == ([object objectVersion] + 1), @"Object version must not "
		@"have been updated yet");

	return version;
}

/** Logs all invocations properly interleaved and indexed by delta versions in 
	a way that makes possible to support undo/redo transparently and in a
	persistent manner for multiple managed objects. */
- (void) logRecord: (id)aRecord objectVersion: (int)aVersion 
	timestamp: (NSDate *)recordTimestamp shouldIncrementContextVersion: (BOOL)updateContextVersion
{
	id object = nil;
	
	if ([aRecord isKindOfClass: [NSInvocation class]])
	{
		object = [aRecord target];
	}
	else
	{
		object = aRecord;	
	}

	if (updateContextVersion)
		_version++;

	[[self metadataServer] executeDBRequest: [NSString stringWithFormat: 
		@"INSERT INTO History (objectUUID, objectVersion, contextUUID, "
		"contextVersion, date) "
		"VALUES ('%@', %i, '%@', %i, '%@');", 
			[[object UUID] stringValue],
			aVersion,
			[_uuid stringValue],
			_version,
			recordTimestamp]];

	ETDebugLog(@"Log %@ objectUUID %@ objectVersion %i contextVersion %i", 
		aRecord, [object UUID], aVersion, _version);

	BOOL exitingUndoSequence = ([self isUndoing] == NO || [self isRedoing] == NO);

	if (exitingUndoSequence)
		[self endUndoSequence];
}

/** Commonly used to forward the invocation to the real object if the 
	initial receiver (the target of the invocation) is a CoreObject proxy.
	By default, this method checks the type of the target of the invocation and 
	forwards it only if it is a COProxy instance. */
- (void) forwardInvocationIfNeeded: (NSInvocation *)inv
{
	if ([[inv target] isCoreObjectProxy])
		[inv invokeWithTarget: [[inv target] _realObject]];
}

/** Sets the time interval that has to be elapsed between two snapshots, before 
    taking a new one the next time -recordInvocation: is called. */
- (void) setSnapshotTimeInterval: (int)anInterval
{
	_fullSaveTimeInterval = anInterval;
}

/** Returns the time interval that has to be elapsed, before taking a new 
    sanpshot when -recordInvocation: is called. */
- (int) snapshotTimeInterval
{
	return _fullSaveTimeInterval;
}

/** Snapshots an object, logs the change in the context history and updates the 
    object metadatas in the metadata server. */
- (void) snapshotObject: (id)object
{
	[self snapshotObject: object shouldIncrementObjectVersion: YES];
	int newObjectVersion = [object objectVersion];
	[self logRecord: object objectVersion: newObjectVersion timestamp: [NSDate date]
		shouldIncrementContextVersion: YES];
}

/** Snapshots an object but doesn't log the change in the context history. 
    If updateVersion is equal to YES, the version of object is incremented of 1 
    and the object metadatas are updated in the metadata server, otherwise both 
    are bypassed.
    You should usually call -snapshotObject: rather than this method. */
- (void) snapshotObject: (id)object shouldIncrementObjectVersion: (BOOL)updateVersion
{
	/* -snapshotSerializerForObject: initializes the serializer with the current 
	   object version. */
	id snapshotSerializer = [self snapshotSerializerForObject: object];
	id realObject = ([object isCoreObjectProxy] ? [object _realObject] : object);
	
	if ([object objectVersion] == -1)
	{
		// TODO: Serialize right in the object bundle and not in a branch.
		[snapshotSerializer serializeObject: realObject withName:@"BaseVersion"];
	}
	else
	{
		[snapshotSerializer serializeObject: realObject withName:@"FullSave"];
	}

	if (updateVersion)
	{
		int newObjectVersion = [object objectVersion] + 1;
		[object _setObjectVersion: newObjectVersion];
		[self updateMetadatasForObject: object recordVersion: newObjectVersion];
	}
}

/** Updates the metadatas of object in the current metadata server.
    The update is timestamped by getting the current date inside this method,  
    right before asking the metadata server to apply the update. */
- (void) updateMetadatasForObject: (id)object recordVersion: (int)aVersion
{
	NSURL *url = [self serializationURLForObject: object];

	ETDebugLog(@"Update %@ %@ metadatas with new version %d", object, [object UUID], aVersion);

	/* This first recorded invocation is always preceded by a snapshot with 
	   version 0. */
	if (aVersion == 0) /* Insert UUID/URL pair (on first serialization) */
	{
		/* Register the object in the metadata server
		   NOTE: -[object className] won't work to get the proxy class, in 
		   future we should pass an UTI-based aggregate type 
		   { COProxy, RealObjectClass } .*/
		[[self metadataServer] setURL: url forUUID: [object UUID]
			withObjectVersion: aVersion 
			             type: NSStringFromClass(object)
			          isGroup: [object isGroup]
			        timestamp: [NSDate date]
			    inContextUUID: [self UUID]];
	}
	else /* Update UUID/URL pair */
	{
		/* Modify object version, the metadata server may update other infos 
		   behind the scene, such as the URL modification date .*/
		[[self metadataServer] updateUUID: [object UUID] 
		                  toObjectVersion: aVersion
		                        timestamp: [NSDate date]];
	}
}

@end
