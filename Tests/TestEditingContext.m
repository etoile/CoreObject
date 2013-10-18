#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestEditingContext : EditingContextTestCase <UKTest>
{
}
@end

@implementation TestEditingContext

- (id) init
{
    SUPERINIT;
    return self;
}


- (void)testDeleteUncommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    ETUUID *uuid = [persistentRoot UUID];
    
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
    UKFalse([persistentRoot isDeleted]);
    
    persistentRoot.deleted = YES;
    
    UKFalse([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKNil([ctx persistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
}

- (void)testDeleteCommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    ETUUID *uuid = [persistentRoot UUID];
    
    [ctx commit];
    
	[self testPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKFalse([testCtx hasChanges]);
		 UKObjectsEqual(S(testProot), [testCtx persistentRoots]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingDeletion]);
		 UKObjectsEqual([NSSet set], [testCtx deletedPersistentRoots]);
		 UKNotNil([testCtx persistentRootForUUID: uuid]);
		 UKNotNil([[testCtx store] persistentRootInfoForUUID: uuid]);
		 UKFalse([testProot isDeleted]);
	 }];
    
    persistentRoot.deleted = YES;

    UKTrue([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKTrue([persistentRoot isDeleted]);
    
    [ctx commit];
	
	[self testPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKFalse([testCtx hasChanges]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRoots]);
		 UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingDeletion]);
		 UKIntsEqual(1, [[testCtx deletedPersistentRoots] count]);
		 /* You can still retrieve a deleted persistent root, until the deletion is finalized */
		 UKNotNil([testCtx persistentRootForUUID: uuid]);
		 UKNotNil([[testCtx store] persistentRootInfoForUUID: uuid]);
		 UKTrue([testProot isDeleted]);
	 }];
}

- (void)testUndeleteCommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    ETUUID *uuid = [persistentRoot UUID];
    [ctx commit];
    
    persistentRoot.deleted = YES;
    [ctx commit];
    
    [persistentRoot setDeleted: NO];

    UKTrue([[store persistentRootInfoForUUID: uuid] isDeleted]);
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingUndeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKFalse([persistentRoot isDeleted]);
    
    [ctx commit];
    
	[self testPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		UKFalse([[[testCtx store] persistentRootInfoForUUID: uuid] isDeleted]);
		UKFalse([testCtx hasChanges]);
		UKObjectsEqual(S(testProot), [testCtx persistentRoots]);
		UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingDeletion]);
		UKObjectsEqual([NSSet set], [testCtx persistentRootsPendingUndeletion]);
		UKObjectsEqual([NSSet set], [testCtx deletedPersistentRoots]);
		UKFalse([testProot isDeleted]);
	 }];
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
        
        pendingInsertion = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        
        pendingDeletion = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        [pendingDeletion commit];
        pendingDeletion.deleted = YES;
        
        pendingUndeletion = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
        [pendingUndeletion commit];
        pendingUndeletion.deleted = YES;
        [pendingUndeletion commit];
        pendingUndeletion.deleted = NO;
        
        // Check that the constraints we wanted to set up hold
        UKTrue([[store persistentRootUUIDs] containsObject: [regular UUID]]);
        UKTrue([[store deletedPersistentRootUUIDs] containsObject: [deletedOnDisk UUID]]);
        UKNil([store persistentRootInfoForUUID: [pendingInsertion UUID]]);
        UKTrue([[store persistentRootUUIDs] containsObject: [pendingDeletion UUID]]);
        UKTrue([[store deletedPersistentRootUUIDs] containsObject: [pendingUndeletion UUID]]);
    }
    
    // 2. Test the accessors
    
    UKObjectsEqual(S(regular, pendingInsertion, pendingUndeletion), [ctx persistentRoots]);
    UKObjectsEqual(S(deletedOnDisk), [ctx deletedPersistentRoots]);
    UKObjectsEqual(S(pendingInsertion), [ctx persistentRootsPendingInsertion]);
    UKObjectsEqual(S(pendingDeletion), [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(pendingUndeletion), [ctx persistentRootsPendingUndeletion]);
    
    // 3. Test what happens when we commit (all pending changes are made and no longer pending)
    
    [ctx commit];
    
	[self testPersistentRootWithExistingAndNewContext: regular
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testRegular, COBranch *testBranch, BOOL isNewContext)
	 {
		 COPersistentRoot *testDeletedOnDisk = [testCtx persistentRootForUUID: [deletedOnDisk UUID]];
		 COPersistentRoot *testPendingInsertion = [testCtx persistentRootForUUID: [pendingInsertion UUID]];
		 COPersistentRoot *testPendingDeletion = [testCtx persistentRootForUUID: [pendingDeletion UUID]];
		 COPersistentRoot *testPendingUndeletion = [testCtx persistentRootForUUID: [pendingUndeletion UUID]];
		 
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

@end
