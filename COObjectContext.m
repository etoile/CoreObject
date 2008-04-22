/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObjectContext.h"
#import "COSerializer.h"
#import "NSObject+CoreObject.h"

#define AVERAGE_MANAGED_OBJECTS_COUNT 1000
#define RECORD_STACK_SIZE 10


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
	//ETLog(@"---> Push on record stack: %@", object);
	[_recordedObjectStack addObject: object];
}

/** Pops the last recorded and pushed object from the record session stack. */
- (void) endRecord
{
	//ETLog(@"---> Pop from record stack: %@", [_recordedObjectStack lastObject]);
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
	else
	{
		return [self deltaSerializer];
	}
}

/** Retrieve the snapshot serializer for a given object. */
- (ETSerializer *) snapshotSerializerForObject: (id)object
{
	if ([object respondsToSelector: @selector(snapshotSerializer)])
	{
		return [object snapshotSerializer];
	}
	else
	{
		return [self snapshotSerializer];
	}
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

/** Restores the full-save version closest to the requested one. */
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

	return [snapshotDeserializer restoreObjectGraph];
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

	[self playbackInvocationsWithObject: rolledbackObject 
	                        fromVersion: baseVersion
	                          toVersion: aVersion];

	return rolledbackObject;
}

/** Play back each of the subsequent invocations */
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

	for (int v = baseVersion + 1; v <= finalVersion; v++)
	{
		[deltaDeserializer setVersion: v];
		CREATE_AUTORELEASE_POOL(pool);
		inv = [deltaDeserializer restoreObjectGraph];
		[inv invokeWithTarget: object];
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

- (void) recordInvocation: (NSInvocation *)inv
{
	if ([self isRecording])
	{
		[self beginRecordObject: [inv target]];
	}
	else /* Initiate a new record session */
	{
		[self beginRecordSessionWithObject: [inv target]];
	}

	/* Only record if needed, although we always push the target of the record 
	   on the recorded object stack.
	   That may change in future, we could return NO when the target of the 
	   of the record is already on stack and the message won't be recorded. We 
	   would return YES otherwise, when pushing the target on the record stack 
	   for the first time. This change would mean not to call -endRecord if NO
	   is returned. This check could be hidden in END_RECORD macro by keeping 
	   around the boolean result of -recordInvocation: with RECORD. */
	if ([[inv target] isEqual: [self currentRecordedObject]])
		return;

	int newObjectVersion = [self serializeInvocation: inv];

	[self logInvocation: inv recordVersion: newObjectVersion];
}

- (int) serializeInvocation: (NSInvocation *)inv
{
	id object = [inv target];
	id deltaSerializer = nil;
	int version = -1;

	/* Record */
	deltaSerializer = [self deltaSerializerForObject: object];
	version = [deltaSerializer newVersion];
	[inv setTarget: nil];
	[deltaSerializer serializeObject: inv withName: "Delta"];

	/* Forward if needed */
	[inv setTarget: object];
	[self forwardInvocationIfNeeded: inv];

	/* Snapshot if needed, by periodically saving a full copy */
	if (version % [self snapshotTimeInterval] == 0)
		[self snapshotObject: object];

	return version;
}

/** Logs all invocations properly interleaved and indexed by delta versions in 
	a way that makes possible to support undo/redo transparently and in a
	persistent manner for multiple managed objects. */
- (void) logInvocation: (NSInvocation *)inv recordVersion: (int)aVersion
{
	ETLog(@"Record %@ version %d in %@", inv, aVersion, self);
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

- (void) snapshotObject: (id)object
{
	id snapshotSerializer = [self snapshotSerializerForObject: object];

	[snapshotSerializer setVersion: [object version]];
	[snapshotSerializer serializeObject: object withName:"FullSave"];
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
