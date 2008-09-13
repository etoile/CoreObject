/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>

@class COMetadataServer, COObjectServer;

typedef enum _COMergeResult
{
	COMergeResultNone,
	COMergeResultFailed,
	COMergeResultSucceeded
} COMergeResult;


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
	ETUUID *_uuid;
	NSArray *_lastMergeErrors;
}

+ (id) defaultContext;

- (COMetadataServer *) metadataServer;
- (COObjectServer *) objectServer;

/* Registering Managed Objects */

- (void) registerObject: (id)object;
- (void) unregisterObject: (id)object;
- (NSSet *) registeredObjects;
- (NSURL *) serializationURLForObject: (id)object;
- (BOOL) setSerializationURL: (NSURL *)url forObject: (id)object;

/* Faulting */

- (id) resolvedObjectForFault: (id)aFault;

/* Merging */

- (COMergeResult) replaceObject: (id)anObject 
                       byObject: (id)temporalInstance
               collectAllErrors: (BOOL)tryAll;
- (NSArray *) lastMergeErrors;

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

- (ETUUID *) UUID;
- (int) version;
#if 0
// FIXME: Implement
- (void) rollbackToVersion: (int)aVersion;
- (void) snapshot;
//- (id) undoManager;
- (void) undo;
- (void) redo;
- (void) isRevertingContext;
#endif

/* Navigating Object History */

- (int) lastVersionOfObject: (id)object;
- (int) lastSnapshotVersionOfObject: (id)object forVersion: (int)aVersion;
- (id) lastSnapshotOfObject: (id)object 
                 forVersion: (int)aVersion 
            snapshotVersion: (int *)snapshotVersion;
- (id) objectByRollingbackObject: (id)anObject 
                       toVersion: (int)aVersion
                mergeImmediately: (BOOL)mergeNow;
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
- (int) recordInvocation: (NSInvocation *)inv;
- (int) serializeInvocation: (NSInvocation *)inv; //-storeInvocation:
- (void) logInvocation: (NSInvocation *)inv 
         recordVersion: (int)aVersion
             timestamp: (NSDate *)recordTimestamp;
- (void) forwardInvocationIfNeeded: (NSInvocation *)inv;

- (void) updateMetadatasForObject: (id)object recordVersion: (int)aVersion;

/* Snapshot-based Persistency */

- (int) snapshotTimeInterval;
- (void) snapshotObject: (id)object;

/* COProxy Compatibility */

- (int) setVersion: (int)aVersion forObject: (id)object;

@end
