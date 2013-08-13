#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestEditingContext : TestCommon <UKTest>
{
    COPersistentRoot *persistentRoot;
}
@end

@implementation TestEditingContext

- (id) init
{
    SUPERINIT;
    ASSIGN(persistentRoot, [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"]);
    return self;
}

- (void) dealloc
{
    DESTROY(persistentRoot);
    [super dealloc];
}

- (void)testDeleteUncommittedPersistentRoot
{
    ETUUID *uuid = [[[persistentRoot persistentRootUUID] retain] autorelease];
    
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
    UKFalse([persistentRoot isDeleted]);
    
    [ctx deletePersistentRoot: persistentRoot];
    
    UKFalse([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKNil([ctx persistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
}

- (void)testDeleteCommittedPersistentRoot
{
    ETUUID *uuid = [[[persistentRoot persistentRootUUID] retain] autorelease];
    
    [ctx commit];
    
    UKFalse([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKFalse([persistentRoot isDeleted]);
    
    [ctx deletePersistentRoot: persistentRoot];

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
    ETUUID *uuid = [[[persistentRoot persistentRootUUID] retain] autorelease];    
    [ctx commit];
    
    [ctx deletePersistentRoot: persistentRoot];
    [ctx commit];
    
    [persistentRoot setDeleted: NO];

    UKTrue([[store persistentRootInfoForUUID: uuid] isDeleted]);
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingUndeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx deletedPersistentRoots]);
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

@end
