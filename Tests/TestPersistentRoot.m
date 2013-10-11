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
	r0 = persistentRoot.revision;
	
	[[persistentRoot rootObject] setLabel: @"hello"];
	[ctx commit];
	r1 = persistentRoot.revision;
	
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
	
    UKIntsEqual(2, [[[[store persistentRootInfoForUUID: [persistentRoot UUID]] branchForUUID] allKeys] count]);
	UKStringsEqual(@"Sandbox", [branch label]);
    
	//UKObjectsEqual(commitTrack, [branch parentTrack]);
	UKObjectsEqual([rootObj persistentRoot], [branch persistentRoot]);
	//UKTrue([rev1 isEqual: [rev2 baseRevision]]);
	
	UKObjectsEqual(rev1, [originalBranch currentRevision]);
	UKObjectsEqual(rev1, [branch currentRevision]);
	//UKObjectsEqual(rev1, [branch parentRevision]);
	
	/* Branch creation doesn't touch the current persistent root revision */
	UKObjectsEqual([rootObj revision], rev1);
	
	/* Branch creation doesn't switch the branch */
	UKObjectsSame(originalBranch, [[rootObj persistentRoot] currentBranch]);
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
    
    {
        // Test that the cross-persistent reference uses branchB when we reopen the store
        
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *photo1ctx2 = [ctx2 persistentRootForUUID: [photo1 UUID]];
        
        // Sanity check
        
        UKObjectsEqual([branchB UUID], [[photo1ctx2 currentBranch] UUID]);
        UKObjectsEqual(A(@"childB"), [[photo1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
    }
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
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];
        
        UKObjectsEqual(ctx2secondBranch, [ctx2persistentRoot currentBranch]);
        UKObjectsEqual(@"hello2", [[ctx2persistentRoot rootObject] valueForProperty: kCOLabel]);
    }
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
    
    UKObjectsEqual(rev1, [copyRoot revision]);
    
    UKNotNil([store persistentRootInfoForUUID: [copyRoot UUID]]);
    
    UKObjectsNotEqual([copyRootBranch UUID], [originalBranch UUID]);
    UKObjectsNotEqual([copyRoot UUID], [persistentRoot UUID]);
    
    UKObjectsEqual(rev1, [copyRootBranch initialRevision]);
    UKObjectsEqual(rev1, [copyRootBranch currentRevision]);
    UKObjectsEqual(rev1, [originalBranch currentRevision]);
	
    /* Make a commit in the cheap copy */
    
   	[[copyRoot rootObject] setValue: @"Todo" forProperty: @"label"];
	
    [ctx commit];
    
    // FIXME: Not yet supported by COBranch:
    //UKObjectsEqual(commitTrack, [branch parentTrack]);
	
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
    
	UKObjectsEqual(S(originalBranch), [persistentRoot branches]);
	UKTrue([[persistentRoot branchesPendingDeletion] isEmpty]);
	UKObjectsEqual(S(branch), [persistentRoot deletedBranches]);
	UKTrue([branch isDeleted]);
	
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        COBranch *ctx2originalBranch = [ctx2persistentRoot branchForUUID: [originalBranch UUID]];
        COBranch *ctx2branch = [ctx2persistentRoot branchForUUID: [branch UUID]];
        
        UKObjectsEqual(S(ctx2originalBranch), [ctx2persistentRoot branches]);
		UKTrue([[ctx2persistentRoot branchesPendingDeletion] isEmpty]);
		UKObjectsEqual(S(ctx2branch), [ctx2persistentRoot deletedBranches]);
        UKTrue([ctx2branch isDeleted]);
    }
}

// Check that attempting to commit modifications to a deleted persistent root
// raises an exception

// FIXME: Refactor the tests so each test is only expressed once (in a block?)
// which is then run on both ctx and a fresh context. At present, each test
// is copied & pasted.

- (void) testExceptionOnDeletedPersistentRootSetRevision
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	persistentRoot.revision = r0;
	UKRaisesException([ctx commit]);
}

- (void) testExceptionOnDeletedPersistentRootSetRevisionInSecondContext
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	// Load in another context
	{
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		ctx2persistentRoot.revision = r0;
		UKRaisesException([ctx2 commit]);
	}
}

- (void) testExceptionOnDeletedPersistentRootModifyEmbeddedObject
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	[[persistentRoot rootObject] setLabel: @"hi"];
	UKRaisesException([ctx commit]);
}

- (void) testExceptionOnDeletedPersistentRootModifyEmbeddedObjectInSecondContext
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	// Load in another context
	{
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		[[ctx2persistentRoot rootObject] setLabel: @"hi"];
		UKRaisesException([ctx2 commit]);
	}
}

- (void) testExceptionOnDeletedPersistentRootCreateBranch
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	COBranch *shouldFailToCommit = [originalBranch makeBranchWithLabel: @"shouldFailToCommit"];
	UKNotNil(shouldFailToCommit);
	UKRaisesException([ctx commit]);
}

- (void) testExceptionOnDeletedPersistentRootCreateBranchInSecondContext
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	// Load in another context
	{
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		COBranch *shouldFailToCommit = [[ctx2persistentRoot currentBranch] makeBranchWithLabel: @"shouldFailToCommit"];
		UKNotNil(shouldFailToCommit);
		UKRaisesException([ctx2 commit]);
	}
}

- (void) testExceptionOnDeletedPersistentRootDeleteBranch
{
	COBranch *altBranch = [originalBranch makeBranchWithLabel: @"altBranch"];
	[ctx commit];
	
	persistentRoot.deleted = YES;
	[ctx commit];
	
	altBranch.deleted = YES;
	UKRaisesException([ctx commit]);
}

- (void) testExceptionOnDeletedPersistentRootDeleteBranchInSecondContext
{
	COBranch *altBranch = [originalBranch makeBranchWithLabel: @"altBranch"];
	[ctx commit];

	persistentRoot.deleted = YES;
	[ctx commit];
	
	// Load in another context
	{
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		[ctx2persistentRoot branchForUUID: [altBranch UUID]].deleted = YES;
		UKRaisesException([ctx2 commit]);
	}
}

- (void) testExceptionOnDeletedPersistentRootUndeleteBranch
{
	COBranch *deletedBranch = [originalBranch makeBranchWithLabel: @"deletedBranch"];
	[ctx commit];
	
	deletedBranch.deleted = YES;
	[ctx commit];
	
	persistentRoot.deleted = YES;
	[ctx commit];
	
	deletedBranch.deleted = NO;
	UKRaisesException([ctx commit]);
}

- (void) testExceptionOnDeletedPersistentRootUndeleteBranchInSecondContext
{
	COBranch *deletedBranch = [originalBranch makeBranchWithLabel: @"deletedBranch"];
	[ctx commit];
	
	deletedBranch.deleted = YES;
	[ctx commit];
	
	persistentRoot.deleted = YES;
	[ctx commit];
	
	// Load in another context
	{
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		[ctx2persistentRoot branchForUUID: [deletedBranch UUID]].deleted = NO;
		UKRaisesException([ctx2 commit]);
	}
}

- (void) testExceptionOnDeletedPersistentRootSetBranchMetadata
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	originalBranch.metadata = @{@"hello" : @"world"};
	UKRaisesException([ctx commit]);
}

- (void) testExceptionOnDeletedPersistentRootSetBranchMetadataInSecondContext
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	// Load in another context
	{
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		[ctx2persistentRoot branchForUUID: [originalBranch UUID]].metadata = @{@"hello" : @"world"};
		UKRaisesException([ctx2 commit]);
	}
}

// TODO: Test these behaviours during deleted->undeleted and undeleted->deleted
// transitions.

@end
