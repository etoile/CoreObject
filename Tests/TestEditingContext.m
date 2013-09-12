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
    ETUUID *uuid = [persistentRoot persistentRootUUID];
    
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
    ETUUID *uuid = [persistentRoot persistentRootUUID];
    
    [ctx commit];
    
    UKFalse([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKFalse([persistentRoot isDeleted]);
    
    persistentRoot.deleted = YES;

    UKTrue([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKTrue([persistentRoot isDeleted]);
    
    [ctx commit];
  
    UKFalse([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    /* N.B.: -deletedPersistentRoots returns the pending deletions, which is why it's empty here  */
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKIntsEqual(1, [[ctx deletedPersistentRoots] count]);
    /* You can still retrieve a deleted persistent root, until the deletion is finalized */
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKTrue([persistentRoot isDeleted]);
}

- (void)testUndeleteCommittedPersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    ETUUID *uuid = [persistentRoot persistentRootUUID];
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
    
    UKFalse([[store persistentRootInfoForUUID: uuid] isDeleted]);
    UKFalse([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingUndeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKFalse([persistentRoot isDeleted]);
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
        UKTrue([[store persistentRootUUIDs] containsObject: [regular persistentRootUUID]]);
        UKTrue([[store deletedPersistentRootUUIDs] containsObject: [deletedOnDisk persistentRootUUID]]);
        UKNil([store persistentRootInfoForUUID: [pendingInsertion persistentRootUUID]]);
        UKTrue([[store persistentRootUUIDs] containsObject: [pendingDeletion persistentRootUUID]]);
        UKTrue([[store deletedPersistentRootUUIDs] containsObject: [pendingUndeletion persistentRootUUID]]);
    }
    
    // 2. Test the accessors
    
    UKObjectsEqual(S(regular, pendingInsertion, pendingUndeletion), [ctx persistentRoots]);
    UKObjectsEqual(S(deletedOnDisk), [ctx deletedPersistentRoots]);
    UKObjectsEqual(S(pendingInsertion), [ctx persistentRootsPendingInsertion]);
    UKObjectsEqual(S(pendingDeletion), [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(pendingUndeletion), [ctx persistentRootsPendingUndeletion]);
    
    // 3. Test what happens when we commit (all pending changes are made and no longer pending)
    
    [ctx commit];
    
    UKObjectsEqual(S(regular, pendingInsertion, pendingUndeletion), [ctx persistentRoots]);
    UKObjectsEqual(S(deletedOnDisk, pendingDeletion), [ctx deletedPersistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingInsertion]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingUndeletion]);
    
}

- (void) testRequestNilPersistentRoot
{
    UKNil([ctx persistentRootForUUID: nil]);
}

@end
