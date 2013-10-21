#import "TestCommon.h"
#import <CoreObject/COObject.h>
#import <CoreObject/COEditingContext+Private.h>
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
	// Load the revision history (to support testing it it is updated in reaction to a commit)
	NSArray *revs = [[persistentRoot editingBranch] nodes];
	CORevisionID *newRevID = nil;

    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		UKIntsEqual(persistentRoot.lastTransactionID, ctx2persistentRoot.lastTransactionID);
        COObject *rootObj = [ctx2persistentRoot rootObject];
        
        [rootObj setValue: @"hello" forProperty: @"label"];
        
        //NSLog(@"Committing change to %@", [persistentRoot persistentRootUUID]);
        [ctx2 commit];
		newRevID = [[rootObj revision] revisionID];
    }

    // Wait a bit for a distributed notification to arrive to ctx
    [self wait];

	CORevision *newRev = [ctx revisionForRevisionID: newRevID];

	UKObjectsEqual([revs arrayByAddingObject: newRev], [[persistentRoot editingBranch] nodes]);
    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: @"label"]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetCurrentRevision
{
    CORevisionID *firstRevid = [[persistentRoot currentRevision] revisionID];
    UKNotNil(firstRevid);
    
    [[persistentRoot rootObject] setLabel: @"change"];
    [ctx commit];
    CORevisionID *secondRevid = [[persistentRoot currentRevision] revisionID];
    UKNotNil(secondRevid);
    UKObjectsNotEqual(firstRevid, secondRevid);
    

    // Revert persistentRoot back to the first revision using the store API
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
	
	[txn setCurrentRevision: [firstRevid revisionUUID]
			   headRevision: nil
				  forBranch: [[persistentRoot currentBranch] UUID]
		   ofPersistentRoot: [persistentRoot UUID]];
    
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
	
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(firstRevid, [[persistentRoot currentRevision] revisionID]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreCreateBranch
{
    ETUUID *secondbranchUUID = [ETUUID UUID];
    
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
	[txn createBranchWithUUID: secondbranchUUID
				 parentBranch: nil
			  initialRevision: [[[persistentRoot currentRevision] revisionID] revisionUUID]
			forPersistentRoot: [persistentRoot UUID]];

	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
	
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    COBranch *secondBranch = [persistentRoot branchForUUID: secondbranchUUID];
    UKNotNil(secondBranch);
    UKObjectsEqual([persistentRoot currentRevision], [secondBranch currentRevision]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreDeleteBranch
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn deleteBranch: [testBranch UUID]
	 ofPersistentRoot: [persistentRoot UUID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKTrue(testBranch.deleted);
	UKTrue([[persistentRoot deletedBranches] containsObject: testBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreUndeleteBranch
{
    testBranch.deleted = YES;
    [ctx commit];

    UKTrue([[[store persistentRootInfoForUUID: [persistentRoot UUID]]
             branchInfoForUUID: [testBranch UUID]]
            isDeleted]);
    
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn undeleteBranch: [testBranch UUID]
	   ofPersistentRoot: [persistentRoot UUID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKFalse(testBranch.deleted);
    UKFalse([[persistentRoot deletedBranches] containsObject: testBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetBranchMetadata
{
    NSDictionary *metadata = @{ @"hello" : @"world" };
    
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn setMetadata: metadata
		   forBranch: [testBranch UUID]
	ofPersistentRoot: [persistentRoot UUID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(metadata, [testBranch metadata]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetCurrentBranch
{
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn setCurrentBranch: [testBranch UUID]
		forPersistentRoot: [persistentRoot UUID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(testBranch, [persistentRoot currentBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreSetCurrentBranchInTransaction
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn setCurrentBranch: [testBranch UUID]
		forPersistentRoot: [persistentRoot UUID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKObjectsEqual(testBranch, [persistentRoot currentBranch]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreDeletePersistentRoot
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
	[txn deletePersistentRoot: [persistentRoot UUID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
    UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKTrue(persistentRoot.deleted);
    UKTrue([[ctx deletedPersistentRoots] containsObject: persistentRoot]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreUndeletePersistentRoot
{
    persistentRoot.deleted = YES;
    [ctx commit];
    
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn undeletePersistentRoot: [persistentRoot UUID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
	UKTrue([store commitStoreTransaction: txn]);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    UKFalse(persistentRoot.deleted);
    UKFalse([[ctx deletedPersistentRoots] containsObject: persistentRoot]);
    UKFalse([ctx hasChanges]);
}

- (void) testsDetectsStoreCreatePersistentRoot
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    COPersistentRootInfo *info = [txn createPersistentRootWithUUID: [ETUUID UUID]
														branchUUID: [ETUUID UUID]
												  parentBranchUUID: nil
															isCopy: YES
												   initialRevision: [[persistentRoot currentRevision] revisionID]];
	[txn setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: [persistentRoot UUID]];
	UKTrue([store commitStoreTransaction: txn]);
    UKNotNil(info);
    
    [self wait];
    
    // Check that a notification was sent to the editing context, and it automatically updated.
    
    BOOL found = NO;
    for (COPersistentRoot *root in [ctx persistentRoots])
    {
        if ([[root UUID] isEqual: [info UUID]])
        {
            found = YES;
        }
    }
    UKTrue(found);
    UKNotNil([ctx persistentRootForUUID: [info UUID]]);
    UKFalse([ctx hasChanges]);
}

@end
