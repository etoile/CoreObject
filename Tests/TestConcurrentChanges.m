#import "TestCommon.h"
#import <CoreObject/COObject.h>
#import <UnitKit/UnitKit.h>

@interface TestConcurrentChanges : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
    COBranch *testBranch;
}
@end

@implementation TestConcurrentChanges

- (id) init
{
    self = [super init];
    persistentRoot =  [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    testBranch =  [[persistentRoot currentBranch] makeBranchWithLabel: @"test"];
    [ctx commit];
    return self;
}


- (void)testsDetectsStoreSetCurrentRevisionDistributedNotification
{
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COObject *rootObj = [ctx2persistentRoot rootObject];
        
        [rootObj setValue: @"hello" forProperty: @"label"];
        
        //NSLog(@"Committing change to %@", [persistentRoot persistentRootUUID]);
        [ctx2 commit];
    }

    // Wait a bit for a distributed notification to arrive to ctx
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];

    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: @"label"]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetCurrentRevision
{
    CORevisionID *firstRevid = [[persistentRoot revision] revisionID];
    UKNotNil(firstRevid);
    
    [[persistentRoot rootObject] setLabel: @"change"];
    [ctx commit];
    CORevisionID *secondRevid = [[persistentRoot revision] revisionID];
    UKNotNil(secondRevid);
    UKObjectsNotEqual(firstRevid, secondRevid);
    
    [store beginTransactionWithError: NULL];
    // Revert persistentRoot back to the first revision using the store API
    UKTrue([store setCurrentRevision: firstRevid
                        tailRevision: nil
                           forBranch: [[persistentRoot currentBranch] UUID]
                    ofPersistentRoot: [persistentRoot persistentRootUUID]
                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(firstRevid, [[persistentRoot revision] revisionID]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreCreateBranch
{
    ETUUID *secondbranchUUID = [ETUUID UUID];
    
    [store beginTransactionWithError: NULL];
    UKTrue([store createBranchWithUUID: secondbranchUUID
                          parentBranch: nil
                       initialRevision: [[persistentRoot revision] revisionID]
                     forPersistentRoot: [persistentRoot persistentRootUUID]
                                 error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    COBranch *secondBranch = [persistentRoot branchForUUID: secondbranchUUID];
    UKNotNil(secondBranch);
    UKObjectsEqual([persistentRoot revision], [secondBranch currentRevision]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreDeleteBranch
{
    [store beginTransactionWithError: NULL];
    UKTrue([store deleteBranch: [testBranch UUID]
              ofPersistentRoot: [persistentRoot persistentRootUUID]
                         error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKTrue(testBranch.deleted);
    UKTrue([[persistentRoot branchesPendingDeletion] containsObject: testBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreUndeleteBranch
{
    testBranch.deleted = YES;
    [ctx commit];

    UKTrue([[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]]
             branchInfoForUUID: [testBranch UUID]]
            isDeleted]);
    
    [store beginTransactionWithError: NULL];
    UKTrue([store undeleteBranch: [testBranch UUID]
                ofPersistentRoot: [persistentRoot persistentRootUUID]
                           error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKFalse(testBranch.deleted);
    UKFalse([[persistentRoot branchesPendingDeletion] containsObject: testBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetBranchMetadata
{
    NSDictionary *metadata = @{ @"hello" : @"world" };
    
    [store beginTransactionWithError: NULL];
    UKTrue([store setMetadata: metadata
                    forBranch: [testBranch UUID]
             ofPersistentRoot: [persistentRoot persistentRootUUID]
                        error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(metadata, [testBranch metadata]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetCurrentBranch
{
    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentBranch: [testBranch UUID]
                 forPersistentRoot: [persistentRoot persistentRootUUID]
                             error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(testBranch, [persistentRoot currentBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetCurrentBranchInTransaction
{
    UKTrue([store beginTransactionWithError: NULL]);
    UKTrue([store setCurrentBranch: [testBranch UUID]
                 forPersistentRoot: [persistentRoot persistentRootUUID]
                             error: NULL]);
    UKTrue([store commitTransactionWithError: NULL]);
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(testBranch, [persistentRoot currentBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreDeletePersistentRoot
{
    [store beginTransactionWithError: NULL];
    UKTrue([store deletePersistentRoot: [persistentRoot persistentRootUUID] error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKTrue(persistentRoot.deleted);
    UKTrue([[ctx deletedPersistentRoots] containsObject: persistentRoot]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreUndeletePersistentRoot
{
    persistentRoot.deleted = YES;
    [ctx commit];
    
    [store beginTransactionWithError: NULL];
    UKTrue([store undeletePersistentRoot: [persistentRoot persistentRootUUID] error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKFalse(persistentRoot.deleted);
    UKFalse([[ctx deletedPersistentRoots] containsObject: persistentRoot]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreCreatePersistentRoot
{
    [store beginTransactionWithError: NULL];
    COPersistentRootInfo *info = [store createPersistentRootWithInitialRevision: [[persistentRoot revision] revisionID]
                                                                           UUID: [ETUUID UUID]
                                                                     branchUUID: [ETUUID UUID]
                                                                          error: NULL];
    [store commitTransactionWithError: NULL];
    UKNotNil(info);
    
    // N.B.: If we make the store async, we'll need to wait here a bit.
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    
    BOOL found = NO;
    for (COPersistentRoot *root in [ctx persistentRoots])
    {
        if ([[root persistentRootUUID] isEqual: [info UUID]])
        {
            found = YES;
        }
    }
    UKTrue(found);
    UKNotNil([ctx persistentRootForUUID: [info UUID]]);
    UKFalse([ctx hasChanges]);
}

@end
