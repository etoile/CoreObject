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


/** <p>COObjectContext implements the core persistency logic that makes up 
    CoreObject. Both COObject and COProxy are bound a context to which they 
    fully delegate the handling of their persistency.</p>
    <p>Each object context can own multiple objects. These can be instances of 
    COObject hierarchy or foreign model objects wrapped behind a COProxy 
    instance. With CoreObject, each object that is inserted in an object context 
    becomes a persistent root. By default, objects are inserted in the object 
    context returned by -currentContext. Once an object has been inserted, you 
    cannot move it to another object context (at least for now).</p>
    <p>Each persistent root will be stored in an object bundle on disk. By default, 
    objects are serialized automatically in ~/CoreObjectLibrary, although 
    nothing prevents you to move or rename the object bundle if you update 
    the URL/UUID mapping infos in the metadata DB by yourself (see 
    COMetadataServer).</p>
    <p>For each metadata DB, by default one for each user, a single core 
    object graph exists. All core objects tracked by this metadata DB makes up 
    this graph. This object graph is usually further partionned into multiple 
    object contexts which are versionned independently. Because each core object 
    is also a versionned persistent root, versionning is supported at two 
    granularity level per objects and per contexts (or object graphs). This 
    allows to have indepent versionning of subsets of the overall core object 
    graph. These core object subgraphs are each one owned and managed by their 
    own context. Because relationships between core objects are allowed exactly 
    in the same way within a context or across context boundaries, there is 
    really a single core object graph rather than multiple object graphs which 
    can be unionned to behave like a single one.</p>
    <p>The history of the entire core object graph is logged in the metadata DB 
    (see COMetadataServer), including restore operations. By running queries 
    over the history, the history specific to a given context can be extracted 
    and used to restored it to a a past version by restoring multiple objects 
    which have changed in the version interval. 
    Then restoring each object consists identifying the most recent snapshot 
    before the wanted object version, and replaying all the invocations 
    serialized as deltas until this version. This history data is stored as 
    deltas and snapshots/fullsaves in each object bundle. The storage model and
    the serialization/deserialized based on snapshots/fullsaves and deltas is 
    almost entirely delegated to EtoileSerialize.</p>
    <p>A context is uniquely identified by an UUID. By passing this UUID to 
    -initWithUUID:, a context previously deallocated, can be recreated. Every 
    time, an object is inserted into a context, the object is marked as 
    belonging to this context in the metadata DB and the insertion is logged 
    into the history. Hence you can recreate a context, that was used prior to 
    the last launch of your currently running application, and the entire object 
    graph it is in charge of. Here is a summary of what needs to be done:
    <list>
    <item>retrieve the UUID with -UUID and store it with NSUserDefaults for 
    example (see NSUserDefaults additions in EtoileFoundation for that)</item>
    <item>retrieve this UUID from its store location and pass it to a new 
    context like that [[COObjectContext alloc] initWithUUID: ctxtUUID]</item>
    <item>retrieve an entry point in the object graph from the recreated 
    context, by calling [ctxt objectForUUID: anObjectUUID]. This is necessary 
    because all objects are faults initially because of the lazy loading of 
    core objects. Alternatively you can force the loading of all objects that 
    belong to this context with -loadAllObjects.</item></list>
    Take note that you need to store the UUID of the object playing the role 
    of an entry point somewhere (NSUserDefaults for example).</p> */
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

	/* Low-level Undo/Redo */
	int _firstUndoVersion;
	int _restoredVersionUndoCursor;
	BOOL _isUndoing;
	BOOL _isRedoing;
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
- (BOOL) canRedo;
- (void) redo;
- (BOOL) isUndoing;
- (BOOL) isRedoing;
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

@end

@interface NSObject (COObjectContextDelegate)
// TODO: Eventually add a delegate method to control the merge process...
// - (BOOL) objectContext:willMergeObject:withObject:inPlace:isTemporal:
- (void) objectContextDidMergeObjects: (NSNotification *)notif;
@end
