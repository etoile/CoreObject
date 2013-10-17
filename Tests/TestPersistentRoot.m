#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COBranch.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COPersistentRoot.h"

@interface TestPersistentRoot : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
	OutlineItem *rootObj;
    COBranch *originalBranch;
	
	CORevision *r0;
	CORevision *r1;
}
@end

@implementation TestPersistentRoot

- (id) init
{
    SUPERINIT;
    persistentRoot =  [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	rootObj = [persistentRoot rootObject];
    originalBranch =  [persistentRoot currentBranch];
    
	[ctx commit];
	r0 = persistentRoot.currentRevision;
	
	[[persistentRoot rootObject] setLabel: @"hello"];
	[ctx commit];
	r1 = persistentRoot.currentRevision;
	
    return self;
}

- (void)testBranchCreation
{
    [persistentRoot commit];
    
	CORevision *rev1 = [[persistentRoot currentBranch] currentRevision];
	
	COBranch *branch = [originalBranch makeBranchWithLabel: @"Sandbox"];
	UKNotNil(branch);
	UKObjectsNotEqual([branch UUID], [originalBranch UUID]);
    
    /* Verify that the branch creation is not committed yet. */
    UKIntsEqual(1, [[[[store persistentRootInfoForUUID: [persistentRoot UUID]] branchForUUID] allKeys] count]);
    
    [persistentRoot commit];
	
	[self testBranchWithExistingAndNewContext: branch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKIntsEqual(2, [[testProot branches] count]);
		 UKStringsEqual(@"Sandbox", [testBranch label]);
		 UKObjectsEqual([originalBranch UUID], [[testBranch parentBranch] UUID]);
		 
		 UKObjectsEqual(testProot, [testBranch persistentRoot]);
		 
		 UKObjectsEqual(rev1, [testBranch currentRevision]);
	 }];

	/* Branch creation doesn't switch the branch */
	UKObjectsEqual(originalBranch, [persistentRoot currentBranch]);
	
	/* Branch creation doesn't touch the current persistent root revision */
	UKObjectsEqual(rev1, [rootObj revision]);
	UKObjectsEqual(rev1, [originalBranch currentRevision]);
}

- (void)testBranchSwitch
{
	[rootObj setValue: @"Untitled" forProperty: @"label"];
	[persistentRoot commit];
    
	//CORevision *rev1 = [[persistentRoot currentBranch] currentRevision];
	
	COBranch *branch = [originalBranch makeBranchWithLabel: @"Sandbox"];
    
	/* Switch to the Sandbox branch */
	
	[persistentRoot setCurrentBranch: branch];
	
    UKObjectsEqual([originalBranch UUID],
                   [[store persistentRootInfoForUUID: [persistentRoot UUID]] currentBranchUUID]);
    
	/* Commit some changes in the Sandbox branch */
	
    COObject *sandboxRootObj = [[branch objectGraphContext] rootObject];
    
	[sandboxRootObj setValue: @"Todo" forProperty: @"label"];
	
    UKObjectsEqual(@"Todo", [[persistentRoot rootObject] valueForProperty: @"label"]);
    
	[persistentRoot commit];
	
    UKObjectsEqual([branch UUID],
                   [[store persistentRootInfoForUUID: [persistentRoot UUID]] currentBranchUUID]);
    
	[sandboxRootObj setValue: @"Tidi" forProperty: @"label"];
	
    [persistentRoot commit];
    
	//CORevision *rev3 = [branch currentRevision];
    
    UKObjectsEqual(@"Tidi", [[persistentRoot rootObject] valueForProperty: @"label"]);
	
	/* Switch back to the main branch */
	
	[persistentRoot setCurrentBranch: originalBranch];
    
    UKObjectsEqual(@"Untitled", [[persistentRoot rootObject] valueForProperty: @"label"]);
}

- (void) testBranchSwitchCommitted
{
	// photo1 <<persistent root, branchA>>
	//  |
	//  \--childA
	//
	// photo1 <<persistent root, branchB>>
	//  |
	//  \--childB
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COObject *photo1root = [photo1 rootObject];
    
    COObject *childA = [[photo1 objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childA setValue: @"childA" forKey: @"label"];
    [photo1root insertObject: childA atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    [photo1 commit];
    
    COBranch *branchB = [[photo1 currentBranch] makeBranchWithLabel: @"branchB"];
    COObject *photo1branchBroot = [[branchB objectGraphContext] rootObject];
    
    COObject *childB = [[photo1branchBroot valueForKey: @"contents"] firstObject];
    [childB setValue: @"childB" forProperty: @"label"];
    UKTrue([[branchB objectGraphContext] hasChanges]);
    
    [ctx commit];
    
    UKObjectsEqual(A(@"childA"), [[photo1 rootObject] valueForKeyPath: @"contents.label"]);
    [photo1 setCurrentBranch: branchB];
    
    UKObjectsEqual(A(@"childB"), [[photo1 rootObject] valueForKeyPath: @"contents.label"]);
    [ctx commit];
    
    // Test that the cross-persistent reference uses branchB when we reopen the store
        
	[self testPersistentRootWithExistingAndNewContext: photo1
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testPhoto1, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual([branchB UUID], [[testPhoto1 currentBranch] UUID]);
		 UKObjectsEqual(A(@"childB"), [[testPhoto1 rootObject] valueForKeyPath: @"contents.label"]);
	 }];
}

- (void) testBranchSwitchPersistent
{
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];
    [[[secondBranch objectGraphContext] rootObject] setValue: @"hello2" forProperty: kCOLabel];
    [ctx commit];
    
    [persistentRoot setCurrentBranch: secondBranch];
    [ctx commit];
    
	[self testBranchWithExistingAndNewContext: secondBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testSecondBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(testSecondBranch, [testProot currentBranch]);
		 UKObjectsEqual(@"hello2", [[testProot rootObject] label]);
		 UKObjectsEqual(@"hello", [[[testProot branchForUUID: [originalBranch UUID]] rootObject] label]);
	 }];
}

- (void) testSetCurrentBranchAndDeleteBranch
{
    UKObjectsEqual(originalBranch, [persistentRoot currentBranch]);
    [ctx commit];
    
    COBranch *branch = [originalBranch makeBranchWithLabel: @"branch"];
    [persistentRoot setCurrentBranch: branch];
    [ctx commit];
    
    [persistentRoot setCurrentBranch: originalBranch];
    branch.deleted = YES;
    [ctx commit];
    
    UKPass();
}


- (void)testCheapCopyCreation
{
    [rootObj setValue: @"Untitled" forProperty: @"label"];
    
    [persistentRoot commit];
    
	CORevision *rev1 = [originalBranch currentRevision];
    COPersistentRoot *copyRoot = [originalBranch makeCopyFromRevision: rev1];
    UKNil([store persistentRootInfoForUUID: [copyRoot UUID]]);
	UKTrue([[ctx persistentRootsPendingInsertion] containsObject: copyRoot]);
    
	COBranch *copyRootBranch = [copyRoot currentBranch];
	
    [ctx commit];
    
    UKObjectsEqual(rev1, [copyRoot currentRevision]);
    
    UKNotNil([store persistentRootInfoForUUID: [copyRoot UUID]]);
    
    UKObjectsNotEqual([copyRootBranch UUID], [originalBranch UUID]);
    UKObjectsNotEqual([copyRoot UUID], [persistentRoot UUID]);
    
    UKObjectsEqual(rev1, [copyRootBranch initialRevision]);
    UKObjectsEqual(rev1, [copyRootBranch currentRevision]);
    UKObjectsEqual(rev1, [originalBranch currentRevision]);
	
    /* Make a commit in the cheap copy */
    
   	[[copyRoot rootObject] setValue: @"Todo" forProperty: @"label"];
	
    [ctx commit];
    
	UKObjectsEqual(originalBranch, [copyRootBranch parentBranch]);
	
	/* Cheap copy creation doesn't touch the current persistent root revision */
	UKObjectsEqual([[persistentRoot rootObject] revision], rev1);
	
    /* Cheap copy creation doesn't switch the branch */
    UKObjectsSame(originalBranch, [persistentRoot currentBranch]);
}

- (void) testDeleteUncommittedBranch
{
    [ctx commit];
    
    COBranch *branch = [originalBranch makeBranchWithLabel: @"branch"];
    
    UKObjectsEqual(S(branch, originalBranch), [persistentRoot branches]);
    
    branch.deleted = YES;
    
    UKObjectsEqual(S(originalBranch), [persistentRoot branches]);
    
    [ctx commit];
    
    UKObjectsEqual(A([originalBranch UUID]), [[[store persistentRootInfoForUUID: [persistentRoot UUID]] branchForUUID] allKeys]);
}

- (void) testDeleteCommittedBranch
{
    [ctx commit];
    
    COBranch *branch = [originalBranch makeBranchWithLabel: @"branch"];
    
    UKObjectsEqual(S(branch, originalBranch), [persistentRoot branches]);
	
    [ctx commit];
    
    UKObjectsEqual(S([originalBranch UUID], [branch UUID]),
                   SA([[[store persistentRootInfoForUUID: [persistentRoot UUID]] branchForUUID] allKeys]));
    
    branch.deleted = YES;
    
    UKObjectsEqual(S(originalBranch), [persistentRoot branches]);
    UKObjectsEqual(S(branch), [persistentRoot branchesPendingDeletion]);
	UKTrue([[persistentRoot deletedBranches] isEmpty]);
    UKTrue([branch isDeleted]);
    
    [ctx commit];
    
	[self testBranchWithExistingAndNewContext: branch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 COBranch *testOriginalBranch = [testProot branchForUUID: [originalBranch UUID]];
		 
		 UKObjectsEqual(S(testOriginalBranch), [testProot branches]);
		 UKTrue([[testProot branchesPendingDeletion] isEmpty]);
		 UKObjectsEqual(S(testBranch), [testProot deletedBranches]);
		 UKTrue([testBranch isDeleted]);
	 }];
}

// Check that attempting to commit modifications to a deleted persistent root
// raises an exception

- (void) testExceptionOnDeletedPersistentRootSetRevision
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	[self testPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 testProot.currentRevision = r0;
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedPersistentRootModifyEmbeddedObject
{
	persistentRoot.deleted = YES;
	[ctx commit];

	[self testPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 [[testProot rootObject] setLabel: @"hi"];
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedPersistentRootCreateBranch
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	[self testPersistentRootWithExistingAndNewContext: persistentRoot
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 COBranch *shouldFailToCommit = [testBranch makeBranchWithLabel: @"shouldFailToCommit"];
		 UKNotNil(shouldFailToCommit);
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedPersistentRootDeleteBranch
{
	COBranch *altBranch = [originalBranch makeBranchWithLabel: @"altBranch"];
	[ctx commit];

	persistentRoot.deleted = YES;
	[ctx commit];
	
	[self testBranchWithExistingAndNewContext: altBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 testBranch.deleted = YES;
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedPersistentRootUndeleteBranch
{
	COBranch *deletedBranch = [originalBranch makeBranchWithLabel: @"deletedBranch"];
	[ctx commit];
	
	deletedBranch.deleted = YES;
	[ctx commit];
	
	persistentRoot.deleted = YES;
	[ctx commit];
	
	[self testBranchWithExistingAndNewContext: deletedBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 testBranch.deleted = NO;
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedPersistentRootSetBranchMetadata
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	[self testBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	{
		testBranch.metadata = @{@"hello" : @"world"};
		UKRaisesException([testCtx commit]);
	}];
}

// TODO: Test these behaviours during deleted->undeleted and undeleted->deleted
// transitions.

@end
