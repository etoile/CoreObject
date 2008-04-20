/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>


@interface COObjectContext : NSObject
{
	// TODO: To be able to use shared serializers in the managed object context, 
	// the related classes must become reusable, otherwise the cost of 
	// constantly allocating and deallocating serializers and serializer 
	// backends each time an invocation is processed is surely going to be an
	// issue.
	id _deltaSerializer;
	id _fullSaveSerializer;
	int _fullSaveTimeInterval;
	/* Managed Objects belonging to the context */
	NSMutableSet *_registeredObjects;
	/* Successive senders inside a record session (invocation sequence) */
	NSMutableArray *_recordedObjectStack;
	id _revertedObject;
	id _delegate;
	int _version;
}

+ (id) defaultContext;

/* Registering Managed Objects */

- (void) registerObject: (id)object;
- (void) unregisterObject: (id)object;
- (NSSet *) registeredObjects;
- (BOOL) replaceObject: (id)object byObject: (id)temporalInstance;

/* Controlling Record Session */

- (BOOL) isRecording;
- (id) currentRecordSessionObject;
- (id) currentRecordedObject;
- (void) beginRecordSessionWithObject: (id)object;
- (void) endRecordSession;
- (void) beginRecordObject: (id)object;
- (void) endRecord;
/*- (void) pushObjectInRecordSessionStack: 
- (void) popObjectFromRecordSessionStack:*/

/* Retrieving Serializers */

- (ETSerializer *) deltaSerializer;
- (ETSerializer *) snapshotSerializer;
- (ETSerializer *) deltaSerializerForObject: (id)object;
- (ETSerializer *) snapshotSerializerForObject: (id)object;

/* Navigating Context History */

// FIXME: Implement
#if 0
- (int) version;
- (void) rollbackToVersion: (int)aVersion;
- (void) snapshot;
//- (id) undoManager;
- (void) undo;
- (void) redo;
- (void) isRevertingContext;
#endif

/* Navigating Object History */

- (int) lastSnapshotVersionOfObject: (id)object forVersion: (int)aVersion;
- (id) lastSnapshotOfObject: (id)object 
                 forVersion: (int)aVersion 
            snapshotVersion: (int *)snapshotVersion;
- (id) objectByRollingbackObject: (id)object toVersion: (int)version;
//- (void) getObject: (id *)object byRollingbackToVersion: (int)version;
- (void) playbackInvocationsWithObject: (id)object 
                           fromVersion: (int)baseVersion 
                             toVersion: (int)finalVersion;
- (BOOL) isReverting; /** Rolling back or playing back */
- (id) currentRevertedObject;
- (BOOL) isRolledbackObject: (id)object;
- (void) beginRevertObject: (id)object;
- (void) endRevert;
//- (BOOL) canApplyChangesToObject: (id)object; 
- (BOOL) shouldIgnoreChangesToObject: (id)object;

/* Message-based Persistency */

- (BOOL) shouldRecordChangesToObject: (id)object;
- (void) recordInvocation: (NSInvocation *)inv;
- (int) serializeInvocation: (NSInvocation *)inv; //-storeInvocation:
- (void) logInvocation: (NSInvocation *)inv recordVersion: (int)aVersion;
- (void) forwardInvocationIfNeeded: (NSInvocation *)inv;

/* Snapshot-based Persistency */

- (int) snapshotTimeInterval;
- (void) snapshotObject: (id)object;

/* COProxy Compatibility */

- (int) setVersion: (int)aVersion forObject: (id)object;

@end
