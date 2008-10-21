/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#include <stdio.h>
#import "COObjectContext.h"
#import "COObject.h"
#import "COGroup.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COMetadataServer.h"
#import "COObjectServer.h"
#import "NSObject+CoreObject.h"

#define AVERAGE_MANAGED_OBJECTS_COUNT 1000
#define RECORD_STACK_SIZE 10

NSString *COObjectContextDidMergeObjectsNotification = @"COObjectContextDidMergeObjectsNotification";
NSString *COMergedObjectsKey = @"COMergedObjectsKey";

@interface COObject (FrameworkPrivate)
- (void) setObjectContext: (COObjectContext *)ctxt;
- (void) _setObjectVersion: (int)version;
@end

@interface COObjectContext (Private)
- (int) latestVersion;
- (void) tryMergeRelationshipsOfObject: (id)anObject intoInstance: (id)targetInstance;
- (void) commitMergeOfInstance: (id)temporalInstance forObject:  (id)anObject;
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
	_recordedObjectStack = [[NSMutableArray alloc] initWithCapacity: RECORD_STACK_SIZE];
	_objectUnderRestoration = nil;
	[self setSnapshotTimeInterval: 100];
	[self setDelegate: nil];
	[self setMergePolicy: COOldChildrenMergePolicy];

	return self;
}

- (void) dealloc
{
	// NOTE: Delegate is a weak reference.
	DESTROY(_objectUnderRestoration);
	DESTROY(_recordedObjectStack);
	DESTROY(_registeredObjects);
	DESTROY(_uuid);

	[super dealloc];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@ version: %i", [super description], [self version]];
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
   object belongs to.
   If object isn't registered, returns nil. */
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
	return [self objectForUUID: aFault];;
}

/** Returns the UUIDs of the all the objects that belongs the receiver for the 
    given version. 
    If you substract the UUIDs of the registered objects from the returned set, 
    the resulting set contains every faults that belongs to the object context. */
- (NSArray *) allObjectUUIDsMatchingContextVersion: (int)aVersion
{
	return [[self findAllObjectVersionsMatchingContextVersion: aVersion] allKeys];
}

/** Loads and register all the objects that belongs to the receiver but are not
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
    Merging only occurs if you roll back one or several registered objects, if 
    the whole object context is reverted to a past version, the resulting object 
    graph will be in a coherent state and this method won't be called. */
- (COMergeResult) replaceObject: (id)anObject 
                       byObject: (id)temporalInstance 
               collectAllErrors: (BOOL)tryAll
{
	// TODO: This XOR is a bit verbose...
	if (([anObject isKindOfClass: [COGroup class]] == NO && [temporalInstance isKindOfClass: [COGroup class]])
	 || ([anObject isKindOfClass: [COGroup class]] && [temporalInstance isKindOfClass: [COGroup class]] == NO))
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"Replaced Object %@ and replacement object %@ "
		                     "must be the same kind, either group or strict object", 
		                     anObject, temporalInstance];
		return COMergeResultFailed;
	}

	NSMutableArray *objectsRefusingReplacement = [NSMutableArray array];
	COMergeResult mergeResult = COMergeResultFailed;
	BOOL isTemporal = [temporalInstance isTemporalInstance: anObject];
	NSError *mergeError = NULL;

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

	// TODO: All the following code will have to be modified to support multiple 
	/// object contexts per process.

	/* Merge Parent References */
	FOREACHI([self registeredObjects], managedObject) // NOTE: iterating through kCOParentsProperty of anObject could work probably
	{

		// TODO: Asks each managed object if the merge is possible before 
		// attempting to apply it. If the merge fails, we are in an invalid 
		// state with both object and temporalInstance being referenced in 
		// relationships
		if ([managedObject isKindOfClass: [COGroup class]])
		{
			mergeResult = [managedObject replaceObject: anObject 
			                                  byObject: temporalInstance 
			                           isTemporalMerge: isTemporal
			                                     error: &mergeError];
			if (mergeResult == COMergeResultFailed)
				[objectsRefusingReplacement addObject: managedObject];
		}
	}

	/* Report which objects haven't handled the merge */
	if ([objectsRefusingReplacement count] > 0)
	{
		// TODO: Rather return an NSError which can be used for UI feedback 
		// rather than logging or raising an exception.
		NSLog(@"WARNING: Failed to merge temporal instance %@ of %@ into the "
			@"following %@ whose faulty classes implement "
			@"-anObjectject:byObject: in a partial or incorrect way.", 
			temporalInstance, anObject, objectsRefusingReplacement);
	}

	 /* Now that parent references or backward pointers are fixed, if the two 
	    objects are groups we need to merge their member/children references. */
	[self tryMergeRelationshipsOfObject: anObject intoInstance: temporalInstance];

	/* Swap the instances in the context */
	[self unregisterObject: anObject];
	[self registerObject: temporalInstance];

	[self commitMergeOfInstance: temporalInstance forObject: anObject];

	if (isTemporal)
		[self endRestore];

	return mergeResult;
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
	[self snapshotObject: temporalInstance shouldIncrementObjectVersion: YES];
	if (anObject == nil)
		anObject = temporalInstance;
	[self logRecord: anObject objectVersion: [anObject objectVersion] 
		timestamp: [NSDate date] shouldIncrementContextVersion: isSingleObjectChange];	
}

/** Returns the errors that occured the last time 
   -replaceObject:byObject:collectAllErrors: was called.
   The previous errors are discarded each time the latter method is called. */
- (NSArray *) lastMergeErrors
{
	return _lastMergeErrors;
}

/* Controlling Record Session */

/** Returns whether the receiver is currently in the middle of a record 
	session. */
- (BOOL) isRecording
{
	return ([self currentRecordSessionObject] != nil);
}

/** Returns the bottom object in the record session stack. */
- (id) currentRecordSessionObject
{
	return [_recordedObjectStack firstObject];
}

/** Returns the top object in the record session stack. */
- (id) currentRecordedObject
{
	return [_recordedObjectStack lastObject];
}

/** Begins a record group for a given managed core object.
	The behavior bound to the record session stack is the responsability of the 
	receiver and may be overriden in subclasses. 
	By default, the receiver only records the messages sent to the objects that 
	initiated the record session, the first one in the stack. All other objects 
	pushed onto the stack gets ignored by -recordInvocation:. */
- (void) beginRecordSessionWithObject: (id)object
{
	NSAssert1([_recordedObjectStack isEmpty], @"The record session stack must "
		@"be empty when a new record session is initiated in %@", self);

	[self beginRecordObject: object];
}

/** Ends a record group for a given managed core object. */
- (void) endRecordSession
{
	NSAssert1([[_recordedObjectStack lastObject] isEqual: 
		[self currentRecordSessionObject]], @"The record session stack must "
		@"contain only the object that initiated the session when the session "
		@"ends in %@", self);

	[self endRecord];

	NSAssert1([_recordedObjectStack isEmpty], @"The record session stack must "
		@"be empty when a record session has been terminated in %@", self);
}

/** Pushes the given object on the record session stack. 
	The behavior bound to the record session stack is the responsability of the 
	receiver and may be overriden in subclasses. */
- (void) beginRecordObject: (id)object
{
	ETDebugLog(@"---> Push on record stack: %@", object);
	[_recordedObjectStack addObject: object];
}

/** Pops the last recorded and pushed object from the record session stack. */
- (void) endRecord
{
	ETDebugLog(@"---> Pop from record stack: %@", [_recordedObjectStack lastObject]);
	[_recordedObjectStack removeLastObject];
}

- (ETSerializer *) deltaSerializer
{
	return _deltaSerializer;
}

- (ETSerializer *) snapshotSerializer
{
	return _fullSaveSerializer;
}

/** Retrieve the delta serializer for a given object. */
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

/** Retrieve the snapshot serializer for a given object. */
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
    reverts to it a later point. The state of all registered objects remain 
    untouched until the next time this version value gets incremented. 
    An object context version is a timemark in the interleaved history of all 
    the registered objects. Each object context version is associated with a 
    unique set of object versions. If at a later point, you set the context 
    version to a past version, the context will revert back to the unique set of 
    temporal instances bound to this version. */
- (int) version
{
	return _version;
}

- (void) restoreToVersion: (int)aVersion
{
	[self _restoreToVersion: aVersion];
}

/** Reverts the receiver to the last version right before the one currently 
    returned by -version.
    This method calls -restoreToVersion:. */
- (void) undo
{
	// TODO: Implement a real undo model.
	[self restoreToVersion: ([self version] - 1)];
}

- (void) redo
{
	// TODO: Implement redo based on the undo model.
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
    receiver also returns -1. Hence this method returns -1 for rolledback 
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
    so you can get back the version number by reference. */
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
	[snapshotObject deserializerDidFinish: snapshotDeserializer forVersion: fullSaveVersion];
	return snapshotObject;
}

/** Returns a temporal instance of the given object, by finding the last 
    snapshot before aVersion, deserializing it and replaying all the serialized 
    invocations between this snapshot version and aVersion.
    The returned instance has no object context and isn't equal to anObject, 
    but returns YES to -isTemporalInstance:, because both anObject and the 
    rolled back object share the same UUID 
    even if they differ by their object version. 
    You cannot use a rolled back object as a persistent object until it 
    gets inserted in an object context. No invocations will ever be recorded 
    until it is inserted. It can either replace anObject in the receiver, or 
    anObject can be unregistered from the receiver to allow the insertion of the 
    rolled back object into another object context. This is necessary because a 
    given object identity (all temporal instances included) must belong to a 
    single object context per process.
    A managed core object identity is defined by its UUID. 
    The state of a rolled back object can be altered before inserting it in an 
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
		ETLog(@"WARNING: Failed to roll back, the version %i is beyond the object history %i",
			aVersion, lastObjectVersion);
		return nil;
	}
	else if (aVersion == [anObject objectVersion])
	{
		ETLog(@"WARNING: Failed to roll back, the version matches the object passed in parameter");
		return anObject;
	}

	int baseVersion = -1;
	id rolledbackObject = [self lastSnapshotOfObject: anObject 
	                                      forVersion: aVersion
	                                 snapshotVersion: &baseVersion];
	ETDebugLog(@"Roll back object %@ with snapshot %@ at version %d", anObject,
		rolledbackObject, baseVersion);

	[self playbackInvocationsWithObject: rolledbackObject 
	                        fromVersion: baseVersion
	                          toVersion: aVersion];
	
	if ([rolledbackObject isKindOfClass: [COGroup class]])
		[rolledbackObject setHasFaults: YES];

	if (mergeNow)
		[self replaceObject: anObject byObject: rolledbackObject collectAllErrors: YES];

	return rolledbackObject;
}

/** Play back each of the subsequent invocations on object.
    The invocations that will be invoked on the object as target will be the 
    all invocation serialized between baseVersion and finalVersion. The first 
    replayed invocation will be 'baseVersion + 1' and the last one 
    'finalVersion'.  */
- (void) playbackInvocationsWithObject: (id)object 
                           fromVersion: (int)baseVersion 
                             toVersion: (int)finalVersion 
{
	if ([self isRestoring])
	{
		[NSException raise: NSInternalInconsistencyException format: 
			@"Invocations cannot be played back on %@ when the context %@ is "
			@"already reverting another object %@", object, self, 
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

/** Returns the registered object for which -objectByRestoringObject:toVersion: 
    is currently executed. */
- (id) currentObjectUnderRestoration
{
	return _objectUnderRestoration;
}

/** Returns whether object is a temporal instance of a given object owned by
	the context. 
	The latter object is called a reverted object in such situation.
	The rolled back object doesn't belong to the receiver because it is a 
	temporal instance that can be retrieved only by requesting it to the 
	receiver for a given object with the same UUID (the reverted object already 
	inserted/owned by the receiver context). */
- (BOOL) isRestoredObject: (id)object
{
	return ([[object UUID] isEqual: [[self currentObjectUnderRestoration] UUID]]
		&& ([[self registeredObjects] containsObject: object] == NO));
}

/** Marks the start of a revert operation.
    A revert operations typically involves exchanges of messages among the 
    registered objects or state alteration, that must not be recorded.
    By calling this method, you ensure -shouldIgnoreChangesToObject: will 
    behave correctly. */
- (void) beginRestoreObject: (id)object
{
	ASSIGN(_objectUnderRestoration, object);
}

/** Marks the end of a revert operation, thereby enables the recording of 
    invocations. */
- (void) endRestore
{
	ASSIGN(_objectUnderRestoration, nil);
}

/** Returns YES if anObject is a temporal instance of an object registered in 
    the receiver and a revert operation is underway, otherwise returns NO.
    This method is mainly useful to decide whether a managed method should 
    return immediately or execute and mutate the state of the model object its 
    belongs to. 
    The rule is to ignore all side-effects triggered by a managed method during 
    a revert. If a revert is underway, all changes must be applied only to the 
    rolled back object (not belonging to the object context) and any other 
    messages sent by the rolled back object to other objects must be ignored. 
    The fact these objects belongs to the object context or not doesn't matter: 
    temporal instances when they got just rolled back are in a state that can be
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
    - the basic object infos stored in the metadata DB are updated for the invocation target
    - the record operation is logged in the receiver history.
    For more details on each step, see respectively -serializeInvocation;,
    -updateMetadatasForObject:, logInvocation:recordVersion:timestamp:.
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
	// NOTE: Don't use [deltaSerializer newVersion]; here because 
	// -serializeObject:withName: already takes care of calling -newVersion.
	// We instead retrieve the version right after serializing the invocation.
	[inv setTarget: nil];
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
}

/** Commonly used to forward the invocation to the real object if the 
	initial receiver (the target of the invocation) was a CoreObject proxy.
	By default, this method checks the type of the target of the invocation and 
	forwards it only if it is a COProxy instance. */
- (void) forwardInvocationIfNeeded: (NSInvocation *)inv
{
	if ([[inv target] isCoreObjectProxy])
		[inv invoke];
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
	id snapshotSerializer = [self snapshotSerializerForObject: object];

	if ([object objectVersion] == -1)
	{
		// TODO: Serialize right in the object bundle and not in a branch.
		[snapshotSerializer serializeObject: object withName:@"BaseVersion"];
	}
	else
	{
		[snapshotSerializer serializeObject: object withName:@"FullSave"];
	}

	if (updateVersion)
	{
		int newObjectVersion = [object objectVersion] + 1;
		[object serializerDidFinish: snapshotSerializer 
		                 forVersion: newObjectVersion];
		[self updateMetadatasForObject: object recordVersion: newObjectVersion];
	}
}

/** Updates the metadatas of object in the current metadata server. */
- (void) updateMetadatasForObject: (id)object recordVersion: (int)aVersion
{
	NSURL *url = [self serializationURLForObject: object];

	ETDebugLog(@"Update %@ %@ metadatas with new version %d", object, [object UUID], aVersion);

	/* This first recorded invocation is always preceded by a snapshot with 
	   version 0. */
	if (aVersion == 0) /* Insert UUID/URL pair (on first serialization) */
	{
		/* Register the object in the metadata server */
		[[self metadataServer] setURL: url forUUID: [object UUID]
			withObjectVersion: aVersion 
			             type: [object className] 
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

/** COProxy compatibility method. Probably to be removed. */
- (int) setVersion: (int)aVersion forObject: (id)object
{
	int foundVersion = -1;
	int rolledbackVersion = -1;
	id rolledbackObject = [self lastSnapshotOfObject: object 
	                                      forVersion: aVersion
	                                 snapshotVersion: &foundVersion];

	//[self objectByRestoringObject: rolledbackObject toVersion:

	[object release];
	object = rolledbackObject;
	return rolledbackVersion;
}

@end
