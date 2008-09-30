/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>

@class COMetadataServer, COObjectServer;

/** Notification posted at the end of a merge. For now, this notification is only 
    posted for -rollbackToVersion:, -undo, -redo.
    Includes the following keys in userInfo dictionary:
    - COMergedObjectsKey */
extern NSString *COObjectContextDidMergeObjectsNotification;
/** Key for the objects that just got merged into the object context. */
extern NSString *COMergedObjectsKey;

typedef enum _COMergeResult
{
	COMergeResultNone,
	COMergeResultFailed,
	COMergeResultSucceeded
} COMergeResult;

/** Defines several merge policies for group to child relationship. These 
    policies can be used when a COGroup instance is rolled back to a past 
    version, to specify how the differences in the children between the old and 
    the existing instances must be handled at merge time. 
    Children are returned by -[COGroup members]. Merging is driven by 
    -replaceObject:byObject:collectAllErrors:. The merging policy is passed to 
    COGroup with -mergeObjectsWithObjectsOfGroup:policy:, when the rolled back 
    instance is on the verge of replacing the instance currently registered in 
    the object context. 
    Take note that merge policy doesn't apply when the whole object context is 
    reverted to a past version, but only when registered objects are rolled 
    back and merged one-by-one.
    The default policy is COOldChildrenMergePolicy, but this is subject to 
    change. */
typedef enum _COChildrenMergePolicy
{
	COOldChildrenMergePolicy,
	COExistingChildrenMergePolicy,
	COChildrenUnionMergePolicy,
	COChildrenIntersectionMergePolicy
} COChildrenMergePolicy;


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
	BOOL _revertingContext;
	id _delegate;
	int _version;
	ETUUID *_uuid;
	NSArray *_lastMergeErrors;
	COChildrenMergePolicy _mergePolicy;
}

+ (COObjectContext *) currentContext;
+ (void) setCurrentContext: (COObjectContext *)aContext;

- (id) initWithUUID: (ETUUID *)aContextUUID;

- (COMetadataServer *) metadataServer;
- (COObjectServer *) objectServer;

- (id) delegate;
- (void) setDelegate: (id)aDelegate;

/* Registering Managed Objects */

- (id) objectForUUID: (ETUUID *)anUUID;

// TODO: Move the next methods in other classes
- (id) objectWithUUID: (ETUUID *)anUUID;
- (id) objectWithUUID: (ETUUID *)anUUID version: (int)objectVersion;
- (id) objectWithURL: (NSURL *)objectURL version: (int)objectVersion;
- (int) lastSnapshotVersionOfObjectWithURL: (NSURL *)anURL;

- (void) registerObject: (id)object;
- (void) unregisterObject: (id)object;
- (NSSet *) registeredObjects;
- (NSURL *) serializationURLForObject: (id)object;
- (BOOL) setSerializationURL: (NSURL *)url forObject: (id)object;

/* Faulting */

- (id) resolvedObjectForFault: (id)aFault;

/* Merging */

- (COChildrenMergePolicy) mergePolicy;
- (void) setMergePolicy: (COChildrenMergePolicy)aPolicy;
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
- (void) rollbackToVersion: (int)aVersion;
- (void) undo;
- (void) redo;
- (BOOL) isRevertingContext;
//- (void) snapshot;

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
- (int) serializeInvocation: (NSInvocation *)inv;
- (void) logInvocation: (NSInvocation *)inv 
         recordVersion: (int)aVersion
             timestamp: (NSDate *)recordTimestamp;
- (void) forwardInvocationIfNeeded: (NSInvocation *)inv;

- (void) updateMetadatasForObject: (id)object recordVersion: (int)aVersion;

/* Snapshot-based Persistency */

- (int) snapshotTimeInterval;
- (void) setSnapshotTimeInterval: (int)anInterval;
- (void) snapshotObject: (id)object;

/* COProxy Compatibility */

- (int) setVersion: (int)aVersion forObject: (id)object;

@end

@interface NSObject (COObjectContextDelegate)
// TODO: Eventually add a delegate method to control the merge process...
// - (BOOL) objectContext:willMergeObject:withObject:inPlace:isTemporal:
- (void) objectContextDidMergeObjects: (NSNotification *)notif;
@end
