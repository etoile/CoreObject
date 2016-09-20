/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "CORevisionCache.h"

@interface TestEditingContext : EditingContextTestCase <UKTest>
{
	NSNotification *unloadNotification;
}
@end

@implementation TestEditingContext

- (id) init
{
    SUPERINIT;
	[[NSNotificationCenter defaultCenter]
		addObserver: self
		   selector: @selector(didUnloadPersistentRoots:)
	           name: COEditingContextDidUnloadPersistentRootsNotification
	         object: ctx];
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)didUnloadPersistentRoots: (NSNotification *)notif
{
	unloadNotification = notif;
}

- (void)testCustomModelDescriptionRepository
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];

	ctx = [[COEditingContext alloc] initWithStore: store modelDescriptionRepository: repo];

	UKDoesNotRaiseException([ctx insertNewPersistentRootWithEntityName: @"OutlineItem"]);
}


- (void)testExceptionOnNewPersistentRootForModelDescriptionRepositoryMismatch
{
	ETModelDescriptionRepository *newRepo = [ETModelDescriptionRepository new];
	ETEntityDescription *rootEntity =
		[ctx.modelDescriptionRepository entityDescriptionForClass: [COObject class]];

	[newRepo addDescription: rootEntity];
	[newRepo setEntityDescription: rootEntity forClass: [COObject class]];

	COObjectGraphContext *objectGraph =
		[COObjectGraphContext objectGraphContextWithModelDescriptionRepository: newRepo];
	COObject *rootObject = [[COObject alloc] initWithObjectGraphContext: objectGraph];

	UKObjectsNotEqual(newRepo, [ctx modelDescriptionRepository]);
	UKRaisesException([ctx insertNewPersistentRootWithRootObject: rootObject]);
}

- (void) validateNewPersistentRoot: (COPersistentRoot *)persistentRoot UUID: (ETUUID *)uuid
{
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
    UKFalse(persistentRoot.deleted);
	UKFalse(persistentRoot.isZombie);
}

- (void)testDeleteUncommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    ETUUID *uuid = persistentRoot.UUID;
    
	[self validateNewPersistentRoot: persistentRoot UUID: uuid];
    
    persistentRoot.deleted = YES;
    
    UKFalse([ctx hasChanges]);
    UKTrue([[ctx persistentRoots] isEmpty]);
    UKTrue([[ctx persistentRootsPendingDeletion] isEmpty]);
    UKNil([ctx persistentRootForUUID: uuid]);
	UKNil([ctx loadedPersistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
	UKTrue(persistentRoot.isZombie);
}

- (void)testUndeleteUncommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    ETUUID *uuid = persistentRoot.UUID;
    
	[self validateNewPersistentRoot: persistentRoot UUID: uuid];
	
	persistentRoot.deleted = YES;
	
	// can't undelete since it's a zombie
	UKRaisesException(persistentRoot.deleted = NO);
	
	UKFalse([ctx hasChanges]);
	UKTrue([[ctx persistentRoots] isEmpty]);
	UKTrue([[ctx persistentRootsPendingDeletion] isEmpty]);
	UKNil([ctx persistentRootForUUID: uuid]);
	UKNil([ctx loadedPersistentRootForUUID: uuid]);
	UKNil([store persistentRootInfoForUUID: uuid]);
	UKTrue(persistentRoot.isZombie);
}

- (void)testDeleteCommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    ETUUID *uuid = persistentRoot.UUID;
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKFalse([testCtx hasChanges]);
		 UKObjectsEqual(S(testProot), [testCtx persistentRoots]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingDeletion]);
		 UKObjectsEqual([NSSet set], [testCtx deletedPersistentRoots]);
		 UKNotNil([testCtx persistentRootForUUID: uuid]);
		 UKNotNil([[testCtx store] persistentRootInfoForUUID: uuid]);
		 UKFalse(testProot.deleted);
	 }];
    
    persistentRoot.deleted = YES;

    UKTrue([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx deletedPersistentRoots]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKTrue(persistentRoot.deleted);
    
    [ctx commit];
	
	UKObjectsEqual(S(persistentRoot), unloadNotification.userInfo[kCOUnloadedPersistentRootsKey]);

	// Force unloaded persistent root to be reloaded
	persistentRoot = [ctx persistentRootForUUID: persistentRoot.UUID];

    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx deletedPersistentRoots]);
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKFalse([testCtx hasChanges]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRoots]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingDeletion]);
		 UKIntsEqual(1, [[testCtx deletedPersistentRoots] count]);
		 /* You can still retrieve a deleted persistent root, until the deletion is finalized */
		 UKNotNil([testCtx persistentRootForUUID: uuid]);
		 UKNotNil([[testCtx store] persistentRootInfoForUUID: uuid]);
		 UKTrue(testProot.deleted);
	 }];
}

- (void)testUndeleteCommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    ETUUID *uuid = persistentRoot.UUID;
    [ctx commit];
    
    persistentRoot.deleted = YES;
    [ctx commit];
	
	UKObjectsEqual(S(persistentRoot), unloadNotification.userInfo[kCOUnloadedPersistentRootsKey]);

	// Force unloaded persistent root to be reloaded
	persistentRoot = [ctx persistentRootForUUID: persistentRoot.UUID];
    
    [persistentRoot setDeleted: NO];

    UKTrue([[store persistentRootInfoForUUID: uuid] isDeleted]);
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingUndeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKFalse(persistentRoot.deleted);
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		UKFalse([[[testCtx store] persistentRootInfoForUUID: uuid] isDeleted]);
		UKFalse([testCtx hasChanges]);
		UKObjectsEqual(S(testProot), [testCtx persistentRoots]);
		UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingDeletion]);
		UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingUndeletion]);
		UKObjectsEqual([NSSet set], [testCtx deletedPersistentRoots]);
		UKFalse(testProot.deleted);
	 }];
}

- (void)testUnloadPeristentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    ETUUID *uuid = persistentRoot.UUID;
	
	[ctx commit];
	[ctx unloadPersistentRoot: persistentRoot];
	
	UKObjectsEqual(S(persistentRoot), unloadNotification.userInfo[kCOUnloadedPersistentRootsKey]);
	
    UKFalse(ctx.hasChanges);
	UKFalse(persistentRoot.isZombie);
    UKNil([ctx loadedPersistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
	
	// Triggers reload
    UKNotNil([ctx persistentRootForUUID: uuid]);
	UKNotNil([ctx loadedPersistentRootForUUID: uuid]);
}

- (void)testUnloadUncommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    ETUUID *uuid = persistentRoot.UUID;
	
	[ctx unloadPersistentRoot: persistentRoot];
	
	UKObjectsEqual(S(persistentRoot), unloadNotification.userInfo[kCOUnloadedPersistentRootsKey]);
	
    UKFalse(ctx.hasChanges);
	UKTrue(persistentRoot.isZombie);
    UKNil([ctx loadedPersistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
    UKNil([ctx persistentRootForUUID: uuid]);
}

/**
 * Try to test all of the requirements of -persistentRoots and the other accessors
 */
- (void) testPersistentRootsAccessors
{
    COPersistentRoot *regular;
    COPersistentRoot *deletedOnDisk;
    COPersistentRoot *pendingInsertion;
    COPersistentRoot *pendingDeletion;
    COPersistentRoot *pendingUndeletion;
    
    // 1. Setup the persistent roots
    {
        regular = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        [regular commit];
        
        deletedOnDisk = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        [deletedOnDisk commit];
        deletedOnDisk.deleted = YES;
        [deletedOnDisk commit];
		// Force unloaded persistent root to be reloaded
		deletedOnDisk = [ctx persistentRootForUUID: deletedOnDisk.UUID];
        
        pendingInsertion = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        
        pendingDeletion = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        [pendingDeletion commit];
        pendingDeletion.deleted = YES;
        
        pendingUndeletion = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        [pendingUndeletion commit];
        pendingUndeletion.deleted = YES;
        [pendingUndeletion commit];
		// Force unloaded persistent root to be reloaded
		pendingUndeletion = [ctx persistentRootForUUID: pendingUndeletion.UUID];
        pendingUndeletion.deleted = NO;
        
        // Check that the constraints we wanted to set up hold
        UKTrue([[store persistentRootUUIDs] containsObject: [regular UUID]]);
        UKTrue([[store deletedPersistentRootUUIDs] containsObject: [deletedOnDisk UUID]]);
        UKNil([store persistentRootInfoForUUID: [pendingInsertion UUID]]);
        UKTrue([[store persistentRootUUIDs] containsObject: [pendingDeletion UUID]]);
        UKTrue([[store deletedPersistentRootUUIDs] containsObject: [pendingUndeletion UUID]]);
		UKTrue(deletedOnDisk.deleted);
		UKTrue(pendingDeletion.deleted);
		UKFalse(pendingUndeletion.deleted);
    }
    
    // 2. Test the accessors
    
    UKObjectsEqual(S(regular, pendingInsertion, pendingUndeletion), [ctx persistentRoots]);
    UKObjectsEqual(S(deletedOnDisk, pendingDeletion), [ctx deletedPersistentRoots]);
    UKObjectsEqual(S(pendingInsertion), [ctx persistentRootsPendingInsertion]);
    UKObjectsEqual(S(pendingDeletion), [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(pendingUndeletion), [ctx persistentRootsPendingUndeletion]);

	UKObjectsEqual(regular, [ctx persistentRootForUUID: [regular UUID]]);
	UKObjectsEqual(deletedOnDisk, [ctx persistentRootForUUID: [deletedOnDisk UUID]]);
   	UKObjectsEqual(pendingInsertion, [ctx persistentRootForUUID: [pendingInsertion UUID]]);
	UKObjectsEqual(pendingDeletion, [ctx persistentRootForUUID: [pendingDeletion UUID]]);
   	UKObjectsEqual(pendingUndeletion, [ctx persistentRootForUUID: [pendingUndeletion UUID]]);

    // 3. Test what happens when we commit (all pending changes are made and no longer pending)
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: regular
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testRegular, COBranch *testBranch, BOOL isNewContext)
	 {
		 COPersistentRoot *testDeletedOnDisk = [testCtx persistentRootForUUID: deletedOnDisk.UUID];
		 COPersistentRoot *testPendingInsertion = [testCtx persistentRootForUUID: pendingInsertion.UUID];
		 COPersistentRoot *testPendingDeletion = [testCtx persistentRootForUUID: pendingDeletion.UUID];
		 COPersistentRoot *testPendingUndeletion = [testCtx persistentRootForUUID: pendingUndeletion.UUID];
		 
		 UKObjectsEqual(S(testRegular, testPendingInsertion, testPendingUndeletion), [testCtx persistentRoots]);
		 UKObjectsEqual(S(testDeletedOnDisk, testPendingDeletion), [testCtx deletedPersistentRoots]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingInsertion]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingDeletion]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingUndeletion]);
	 }];
}

- (void) testRequestNilPersistentRoot
{
    UKNil([ctx persistentRootForUUID: nil]);
}

- (void) testWithNoStore
{
	UKRaisesException([[COEditingContext alloc] initWithStore: nil]);
	UKRaisesException([[COEditingContext alloc] initWithStore: nil
	                               modelDescriptionRepository: [ETModelDescriptionRepository mainRepository]]);
	UKRaisesException([[COEditingContext alloc] initWithStore: nil
	                               modelDescriptionRepository: [ETModelDescriptionRepository mainRepository]
	                                     migrationDriverClass: [COSchemaMigrationDriver class]
	                                           undoTrackStore: [COUndoTrackStore defaultStore]]);
	UKRaisesException([[COEditingContext alloc] init]);
}

- (void)testWithNoUndoTrackStore
{
	// Will retain the store as argument but not release it due to the exception
	UKRaisesException([[COEditingContext alloc] initWithStore: store
	                               modelDescriptionRepository: [ETModelDescriptionRepository mainRepository]
	                                     migrationDriverClass: [COSchemaMigrationDriver class]
	                                           undoTrackStore: nil]);
}

- (void) testRevisionEqualityFromMultipleEditingContexts
{
	COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	[ctx commit];
	
	CORevision *firstRevision = persistentRoot.currentRevision;
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 if (isNewContext)
		 {
			 CORevision *testRevision = testProot.currentRevision;
			 UKObjectsNotSame(testRevision, firstRevision);
			 UKObjectsEqual(testRevision.UUID, firstRevision.UUID);
			 UKObjectsEqual(testRevision, firstRevision);
		 }
	 }];
}

- (void) testRevisionLifetime
{
	COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	[ctx commit];
	CORevision *r1 = persistentRoot.currentRevision;
	
	[persistentRoot.rootObject setLabel: @"test"];
	[ctx commit];
	CORevision *r2 = persistentRoot.currentRevision;
		
	CORevision *r2cxt2 = nil;
	
	@autoreleasepool
	{
		COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore:
			[[COSQLiteStore alloc] initWithURL: [[self class] storeURL]]];
		
		r2cxt2 = [ctx2 persistentRootForUUID: persistentRoot.UUID].currentRevision;
	}
	
	// At this point, r2ctx2's editing context is deallocated, so calling
	// any methods on r2ctx2 that require loading more revisions should throw
	// an exception
	
	UKObjectsEqual(r2.UUID, r2cxt2.UUID);

	UKObjectsEqual(r1, [r2 parentRevision]);
	UKRaisesException([r2cxt2 parentRevision]);
}

- (void) testCommitWithinCommitNotificationIllegal
{
	__block BOOL receivedNotification = NO;
	__block BOOL insideCommit = NO;
	
	id observer = [[NSNotificationCenter defaultCenter]
		addObserverForName: COEditingContextDidChangeNotification
		            object: ctx
	                 queue: nil
	            usingBlock: ^(NSNotification *notif)
	{
		receivedNotification = YES;
		UKTrue(insideCommit);
		UKRaisesException([ctx commit]);
	}];
		
	COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];

	insideCommit = YES;
	[ctx commit];
	insideCommit = NO;
	
	UKTrue(receivedNotification);
	
	[[NSNotificationCenter defaultCenter] removeObserver: observer];
}

- (void) testPersistentRootsPropertyNotLazy
{
	COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	[ctx commit];

	COEditingContext *ctx2 = [self newContext];
	NSSet *ctx2persistentRoots = ctx2.persistentRoots;
	UKIntsEqual(1, ctx2persistentRoots.count);
	UKObjectsEqual(persistentRoot.UUID, [ctx2persistentRoots.anyObject UUID]);
}

- (void) testDeletedPersistentRootsPropertyNotLazy
{
	COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	[ctx commit];
	
	persistentRoot.deleted = YES;
	[ctx commit];
	
	COEditingContext *ctx2 = [self newContext];
	NSSet *ctx2deletedPersistentRoots = ctx2.deletedPersistentRoots;
	UKIntsEqual(1, ctx2deletedPersistentRoots.count);
	UKObjectsEqual(persistentRoot.UUID, [ctx2deletedPersistentRoots.anyObject UUID]);
}

- (void) testPersistentRootInsertionInOtherContextIsLazy
{
	ETUUID *uuid;
	UKObjectsEqual(S(), ctx.loadedPersistentRoots);
	
	// Insert a persistent root in a second context
	{
		COEditingContext *ctx2 = [self newContext];
		COPersistentRoot *persistentRoot = [ctx2 insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
		uuid = persistentRoot.UUID;
		[ctx2 commit];
		
		UKObjectsEqual(S(persistentRoot), ctx2.loadedPersistentRoots);
	}
	
	[self wait];	
	
	// That should not have caused `ctx` to load the persistent root
	UKObjectsEqual(S(), ctx.loadedPersistentRoots);
	
	// Check that we can load it explicitly
	COPersistentRoot *persistentRoot = [ctx persistentRootForUUID: uuid];
	UKNotNil(persistentRoot);
	UKObjectsEqual(S(persistentRoot), ctx.loadedPersistentRoots);
}


@end
