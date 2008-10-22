/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import <CoreObject/COPersistentPool.h>

@class COMetadataServer, COObjectServer;

/** Notification posted at the end of a merge. For now, this notification is only 
    posted for -restoreToVersion:, -undo, -redo.
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


@interface COObjectContext : COPersistentPool
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
	id _objectUnderRestoration;
	BOOL _restoringContext;
	id _delegate;
	int _version;
	ETUUID *_uuid;
	NSArray *_lastMergeErrors;
	COChildrenMergePolicy _mergePolicy;
}

+ (COObjectContext *) currentContext;
+ (void) setCurrentContext: (COObjectContext *)aContext;

- (id) init;
- (id) initWithUUID: (ETUUID *)aContextUUID;

- (COMetadataServer *) metadataServer;
- (COObjectServer *) objectServer;

- (id) delegate;
- (void) setDelegate: (id)aDelegate;

/* Registering Managed Objects */

- (id) objectForUUID: (ETUUID *)anUUID;

- (void) insertObject: (id)anObject;
- (void) registerObject: (id)object;
- (void) unregisterObject: (id)object;
- (NSSet *) registeredObjects;
- (NSURL *) serializationURLForObject: (id)object;
- (BOOL) setSerializationURL: (NSURL *)url forObject: (id)object;

/* Faulting */

- (id) resolvedObjectForFault: (id)aFault;
- (NSArray *) allObjectUUIDsMatchingContextVersion: (int)aVersion;
- (void) loadAllObjects;

/* Merging */

- (COChildrenMergePolicy) mergePolicy;
- (void) setMergePolicy: (COChildrenMergePolicy)aPolicy;
- (COMergeResult) replaceObject: (id)anObject 
                       byObject: (id)temporalInstance
               collectAllErrors: (BOOL)tryAll;
- (NSArray *) lastMergeErrors;

/* Retrieving Serializers */

- (ETSerializer *) deltaSerializer;
- (ETSerializer *) snapshotSerializer;
- (ETSerializer *) deltaSerializerForObject: (id)object;
- (ETSerializer *) snapshotSerializerForObject: (id)object;

/* Navigating Context History */

- (ETUUID *) UUID;
- (int) version;
- (void) restoreToVersion: (int)aVersion;
- (void) undo;
- (void) redo;
- (BOOL) isRestoringContext;
//- (void) snapshot;

/* Navigating Object History */

- (int) lastVersionOfObject: (id)object;
- (int) lastSnapshotVersionOfObject: (id)object forVersion: (int)aVersion;
- (id) lastSnapshotOfObject: (id)object 
                 forVersion: (int)aVersion 
            snapshotVersion: (int *)snapshotVersion;
- (id) objectByRestoringObject: (id)anObject 
                     toVersion: (int)aVersion
              mergeImmediately: (BOOL)mergeNow;
- (void) playbackInvocationsWithObject: (id)object 
                           fromVersion: (int)baseVersion 
                             toVersion: (int)finalVersion;
- (BOOL) isRestoring;
- (id) currentObjectUnderRestoration;
- (BOOL) isRestoredObject: (id)object;
- (void) beginRestoreObject: (id)object;
- (void) endRestore;
//- (BOOL) canApplyChangesToObject: (id)object; 
- (BOOL) shouldIgnoreChangesToObject: (id)object;

/* Message-based Persistency */

- (BOOL) shouldRecordChangesToObject: (id)object;
- (int) recordInvocation: (NSInvocation *)inv;
- (int) serializeInvocation: (NSInvocation *)inv;
- (void) logRecord: (id)aRecord objectVersion: (int)aVersion 
	timestamp: (NSDate *)recordTimestamp shouldIncrementContextVersion: (BOOL)updateContextVersion;
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
