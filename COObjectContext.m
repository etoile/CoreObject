/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObjectContext.h"
#import "COObject.h"
#import "COSerializer.h"
#import "COMetadataServer.h"
#import "NSObject+CoreObject.h"

#define AVERAGE_MANAGED_OBJECTS_COUNT 1000
#define RECORD_STACK_SIZE 10

@interface COObjectContext (Private)
- (void) snapshotObject: (id)object shouldIncrementObjectVersion: (BOOL)updateVersion;
@end


@implementation COObjectContext

static COObjectContext *defaultObjectContext = nil;

+ (id) defaultContext
{
	if (defaultObjectContext == nil)
		defaultObjectContext = [[COObjectContext alloc] init];

	return defaultObjectContext;
}

- (id) init
{
	SUPERINIT

	//_deltaSerializer;
	//_fullSaveSerializer;
	_fullSaveTimeInterval = 100;
	_registeredObjects = [[NSMutableSet alloc] initWithCapacity: AVERAGE_MANAGED_OBJECTS_COUNT];
	_recordedObjectStack = [[NSMutableArray alloc] initWithCapacity: RECORD_STACK_SIZE];
	_revertedObject =nil;
	_delegate = nil;
	_version = 0;

	return self;
}

- (void) dealloc
{
	DESTROY(_revertedObject);
	DESTROY(_recordedObjectStack);
	DESTROY(_registeredObjects);
	//_deltaSerializer;
	//_fullSaveSerializer;

	[super dealloc];
}

/** Returns the metadata server bound to this object context. 
    By default, returns -[COMetadataServer defaultServer]. */
- (COMetadataServer *) metadataServer
{
	// TODO: Make possible to use other metadata servers rather than just the 
	// default one. That will on the object context and object server in use. 
	return [COMetadataServer defaultServer];
}	

/* Registering Managed Objects */

- (void) registerObject: (id)object
{
	[_registeredObjects addObject: object];
}

- (void) unregisterObject: (id)object
{
	[_registeredObjects removeObject: object];
}

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
	if ([_registeredObjects containsObject: object] == NO)
		return NO;

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

/** Use double-dispatch style */
- (BOOL) replaceObject: (id)object byObject: (id)temporalInstance
{
	BOOL hasReplaced = NO;

	[self snapshotObject: object];
	FOREACHI([self registeredObjects], managedObject)
	{
		// TODO: Asks each managed object if the merge is possible before 
		// attempting to apply it. If the merge fails, we are in an invalid 
		// state with both object and temporalInstance being referenced in 
		// relationships
		hasReplaced = [managedObject replaceObject: object byObject: temporalInstance];
	}

	return hasReplaced;
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
	return [ETSerializer defaultCoreObjectDeltaSerializerForObject: object];

	if ([object respondsToSelector: @selector(deltaSerializer)])
	{
		return [object deltaSerializer];
	}
	else
	{
		return [self deltaSerializer];
	}
}

/** Retrieve the snapshot serializer for a given object. */
- (ETSerializer *) snapshotSerializerForObject: (id)object
{
	return [ETSerializer defaultCoreObjectFullSaveSerializerForObject: object];

	if ([object respondsToSelector: @selector(snapshotSerializer)])
	{
		return [object snapshotSerializer];
	}
	else
	{
		return [self snapshotSerializer];
	}
}

/** Returns the first version forward in time which corresponds to a snapshot or
    a delta. If no such version can be found (no snapshot or delta available 
    unless an error occured), returns -1. */
- (int) lastVersionOfObject: (id)object
{
	if ([object isPersistent] == NO)
		return -1;

	// TODO: Move this code into ETSerialObjectBundle, probably by adding 
	// methods such -lastVersion:inBranch: and -lastVersion. We may also cache 
	// the last version in a plist stored in the bundle to avoid the linear 
	// search in the directory.
	NSURL *serializationURL = [[[ETSerializer serializationURLForObject: object] 
		URLByAppendingPath: @"Delta"] URLByAppendingPath: @"root"];
	NSArray *deltaFileNames = [[NSFileManager defaultManager] 
		directoryContentsAtPath: [[serializationURL path] stringByStandardizingPath]];
	int aVersion = -1;

	/* Directory content isn't sorted so we must iterate through all the content */
	FOREACH(deltaFileNames, deltaName, NSString *)
	{
		ETDebugLog(@"Test delta %@ to find last version of %@", deltaName, object);
		int deltaVersion = [[deltaName stringByDeletingPathExtension] intValue];

		if (deltaVersion > aVersion)
			aVersion = deltaVersion;
	}

	return aVersion;
}

/** Returns the first version back in time which corresponds to a snapshot and 
	not a delta. If no such version can be found (probably no snapshot 
	available), returns -1. */
- (int) lastSnapshotVersionOfObject: (id)object forVersion: (int)aVersion
{
	id snapshotDeserializer = [[self snapshotSerializerForObject: object] deserializer];
	int snapshotVersion = aVersion;

	while (snapshotVersion >= 0 
	 && [snapshotDeserializer setVersion: snapshotVersion] != snapshotVersion)
	{
		snapshotVersion--;
	}

	return snapshotVersion;
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

/** Not really useful right now */
#if 0
- (void) getObject: (id *)object byRollingbackToVersion: (int)version
{
	id oldObject = [self objectByRollingbackObject: *object toVersion: version];

	if (oldObject != nil)
	{
		DESTROY(object);
		object = &oldObject;
	}
}
#endif

- (id) objectByRollingbackObject: (id)object toVersion: (int)aVersion
{
	int baseVersion = -1;
	id rolledbackObject = [self lastSnapshotOfObject: object 
	                                      forVersion: aVersion
	                                 snapshotVersion: &baseVersion];
	ETDebugLog(@"Roll back object %@ with snapshot %@ at version %d", object,
		rolledbackObject, baseVersion);

	[self playbackInvocationsWithObject: rolledbackObject 
	                        fromVersion: baseVersion
	                          toVersion: aVersion];

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
	if ([self isReverting])
	{
		[NSException raise: NSInternalInconsistencyException format: 
			@"Invocations cannot be played back on %@ when the context %@ is "
			@"already reverting another object %@", object, self, 
			[self currentRevertedObject]];
	}
	
	[self beginRevertObject: object];

	id deltaDeserializer = [[self deltaSerializerForObject: object] deserializer];
	NSInvocation *inv = nil;

	/*NSAssert3([deltaDeserializer version] == [object objectVersion], 
		@"Delta deserializer version %d and object version %d must match for "
		@"invocations playback on %@", [deltaDeserializer version], 
		[object objectVersion], object);*/

	for (int v = baseVersion + 1; v <= finalVersion; v++)
	{
		[deltaDeserializer setVersion: v];
		CREATE_AUTORELEASE_POOL(pool);
		inv = [deltaDeserializer restoreObjectGraph];
		ETDebugLog(@"Play back %@ at version %d", inv, v);
		[inv invokeWithTarget: object];
		[object deserializerDidFinish: deltaDeserializer forVersion: v];
		DESTROY(inv);
		DESTROY(pool);
	}

	[self endRevert];
}

#if 0
- (BOOL) canApplyChangesToObject: (id)object
{
	return ![self shouldIgnoreChangesToObject: object];
}
#endif

- (BOOL) isReverting
{
	return ([self currentRevertedObject] != nil);
}

- (id) currentRevertedObject
{
	return _revertedObject;
}

/** Returns whether object is a temporal instance of a given object owned by
	the context. 
	The latter object is called a reverted object in such situation. */
- (BOOL) isRolledbackObject: (id)object
{
	return ([[object UUID] isEqual: [[self currentRevertedObject] UUID]]
		&& ([[self registeredObjects] containsObject: object] == NO));
}

- (void) beginRevertObject: (id)object
{
	ASSIGN(_revertedObject, object);
}

- (void) endRevert
{
	ASSIGN(_revertedObject, nil);
}

/** We can ignore changes only during a revert. If it is the case, all changes 
	must be applied only to the rolledback object (not belonging to the 
	object context) and any other messages sent by the rolledback object to other 
	objects must be ignored. The fact these objects belongs to the object 
	context or not doesn't matter. 
	The rolledback object doesn't belong to the receiver because it is a 
	temporal instance that can be retrieved only by requesting to the receiver 
	for a given object with the same UUID (the reverted object already 
	inserted/owned by the receiver context).
	The relationships broken between the rolledback object and its related 
	objects have to be fixed when the rolledback object gets inserted into the 
	context, to replace the current temporal instance in use. A new temporal 
	instance can be inserted into the receiver and its relationships corrected
	by calling the method -replaceObject:byObject:. */
- (BOOL) shouldIgnoreChangesToObject: (id)object
{
	return ([self isReverting] && ([self isRolledbackObject: object] == NO));
}

- (BOOL) shouldRecordChangesToObject: (id)object
{
	return [object isEqual: [self currentRecordSessionObject]];
}

/** Returns the new object version of the target for which the invocation was 
    recorded. If the invocation isn't recorded, then the returned version is 
    identical to the current object version of the invocation target. 
    See also RECORD macro in ETUtility.h */
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
	[self logInvocation: inv recordVersion: newObjectVersion];

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
		[self snapshotObject: object shouldIncrementObjectVersion: YES];
		version = [object objectVersion];
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
- (void) logInvocation: (NSInvocation *)inv recordVersion: (int)aVersion
{
	ETLog(@"Record %@ version %d in %@", inv, aVersion, self);
	_version++;
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

- (int) snapshotTimeInterval
{
	return _fullSaveTimeInterval;
}

/** Snapshots an object and updates the object metadatas in the metadata server
    by calling -updateMetadasForObject:. */
- (void) snapshotObject: (id)object
{
	[self snapshotObject: object shouldIncrementObjectVersion: YES];
	[self updateMetadatasForObject: object recordVersion: [object objectVersion]];
}

/** Snapshots an object but doesn't update the object metadatas in the 
    metadata server. You must call -updateMetadasForObject:recordVersion: if you 
    want to. */
- (void) snapshotObject: (id)object shouldIncrementObjectVersion: (BOOL)updateVersion
{
	id snapshotSerializer = [self snapshotSerializerForObject: object];

	//[snapshotSerializer setVersion: [object objectVersion]];
	if ([object objectVersion] == -1)
	{
		// TODO: Serialize right in the object bundle and not in a branch
		[snapshotSerializer serializeObject: object withName:@"BaseVersion"];
	}
	else
	{
		[snapshotSerializer serializeObject: object withName:@"FullSave"];
	}

	if (updateVersion)
	{
		[object serializerDidFinish: snapshotSerializer 
		                 forVersion: [object objectVersion] + 1];
	}
}

/** Updates the metadatas of object in the current metadata server. */
- (void) updateMetadatasForObject: (id)object recordVersion: (int)aVersion
{
	NSURL *url = [self serializationURLForObject: object];

	ETDebugLog(@"Update %@ %@ metadatas with new version %d", object, [object UUID], aVersion);

	/* This first recorded invocation results in a snapshot with version 0, 
       immediately followed by an invocation record with version 1. */
	if (aVersion == 0 || aVersion == 1) /* Insert UUID/URL pair (on first serialization) */
	{
		/* Register the object in the metadata server */
		[[self metadataServer] setURL: url forUUID: [object UUID]
			withObjectVersion: aVersion 
			             type: [object className] 
			          isGroup: [object isGroup]
			        timestamp: [NSDate date]];
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

	//[self objectByRollingbackObject: rolledbackObject toVersion:

	[object release];
	object = rolledbackObject;
	return rolledbackVersion;
}

@end
