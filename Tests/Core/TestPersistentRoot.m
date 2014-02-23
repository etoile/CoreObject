/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

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

- (void)testExceptionOnInit
{
	UKRaisesException([[COPersistentRoot alloc] init]);
}

- (void)testUncommittedPersistentRootCurrentRevision
{
	COPersistentRoot *newPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	UKNil(newPersistentRoot.currentRevision);
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
	
	[self checkBranchWithExistingAndNewContext: branch
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
    
	[persistentRoot commit];

	UKObjectsEqual(@"Todo", [[persistentRoot rootObject] valueForProperty: @"label"]);
	
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
        
	[self checkPersistentRootWithExistingAndNewContext: photo1
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
    
	[self checkBranchWithExistingAndNewContext: secondBranch
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
    COPersistentRoot *copyRoot = [originalBranch makePersistentRootCopyFromRevision: rev1];
    UKNil([store persistentRootInfoForUUID: [copyRoot UUID]]);
	UKTrue([[ctx persistentRootsPendingInsertion] containsObject: copyRoot]);
    
	COBranch *copyRootBranch = [copyRoot currentBranch];
	UKObjectsEqual(originalBranch, [copyRootBranch parentBranch]);
	UKObjectsEqual(persistentRoot, [copyRoot parentPersistentRoot]);
	UKFalse([persistentRoot isCopy]);
	UKTrue([copyRoot isCopy]);

	UKObjectsEqual([rootObj UUID], [[copyRoot rootObject] UUID]);
	UKObjectsNotEqual(rootObj, [copyRoot rootObject]);

    [ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: copyRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(rev1, [testProot currentRevision]);
		 
		 // FIXME: It might be cleaner if we could get rid of these -UUID calls
		 // and have -[COBranch isEqual:]/-[COPersistentRoot isEqual:] work
		 
		 UKObjectsNotEqual([originalBranch UUID], [testBranch UUID]);
		 UKObjectsNotEqual([persistentRoot UUID], [testProot UUID]);
		 
		 UKObjectsEqual([originalBranch UUID], [[testBranch parentBranch] UUID]);
		 UKObjectsEqual([persistentRoot UUID], [[testProot parentPersistentRoot] UUID]);
		 
		 UKObjectsEqual(rev1, [testBranch initialRevision]);
		 UKObjectsEqual(rev1, [testBranch currentRevision]);
		 UKObjectsEqual(rev1, [testBranch headRevision]);
		 
		 UKTrue([testProot isCopy]);
	 }];

    /* Make a commit in the cheap copy */
    
   	[[copyRoot rootObject] setValue: @"Todo" forProperty: @"label"];
	
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: copyRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@"Todo", [[testProot rootObject] label]);
	 }];
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 /* Cheap copy creation doesn't touch the current persistent root revision */
		 UKObjectsEqual(rev1, [testProot currentRevision]);
		 /* Cheap copy creation doesn't switch the branch */
		 UKObjectsEqual([originalBranch UUID], [testBranch UUID]);
	 }];
}

- (void)testCheapCopyCreationWithEdit
{
	ETAssert(![persistentRoot hasChanges]);
	
    COPersistentRoot *copyRoot = [originalBranch makePersistentRootCopyFromRevision: r1];
	UKObjectsEqual(r1, [copyRoot currentRevision]);
	[[copyRoot rootObject] setLabel: @"a change"];
    [ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: copyRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsNotEqual(r1, [testBranch initialRevision]);
		 UKObjectsNotEqual(r1, [testProot currentRevision]);
		 UKObjectsEqual(@"a change", [[testProot rootObject] label]);
	 }];
}

- (void)testCheapCopyCreationWithEditInBranchObjectGraphContext
{
	ETAssert(![persistentRoot hasChanges]);
	
    COPersistentRoot *copyRoot = [originalBranch makePersistentRootCopyFromRevision: r1];
	UKObjectsEqual(r1, [copyRoot currentRevision]);
	[[[copyRoot currentBranch] rootObject] setLabel: @"a change"];
    [ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: copyRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsNotEqual(r1, [testBranch initialRevision]);
		 UKObjectsNotEqual(r1, [testProot currentRevision]);
		 UKObjectsEqual(@"a change", [[testProot rootObject] label]);
	 }];
}


- (void)testCheapCopyOfCheapCopy
{
	ETAssert(![persistentRoot hasChanges]);
	
    COPersistentRoot *copy1 = [originalBranch makePersistentRootCopyFromRevision: r1];
    [ctx commit];
	
	COPersistentRoot *copy2 = [[copy1 currentBranch] makePersistentRootCopyFromRevision: r1];
    [ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: copy2
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(r1, [testProot currentRevision]);
	 }];
}

- (void) testCreateBranchInUncommittedCheapCopyDisallowed
{
	ETAssert(![persistentRoot hasChanges]);
	
    COPersistentRoot *copy1 = [originalBranch makePersistentRootCopyFromRevision: r1];
	UKRaisesException([[copy1 currentBranch] makeBranchWithLabel: @"hello"]);
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
    UKObjectsEqual(S(branch), [persistentRoot deletedBranches]);
    UKTrue([branch isDeleted]);
    
    [ctx commit];
    
	[self checkBranchWithExistingAndNewContext: branch
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
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 testProot.currentRevision = r0;
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedPersistentRootModifyInnerObject
{
	persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
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
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
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
	
	[self checkBranchWithExistingAndNewContext: altBranch
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
	
	[self checkBranchWithExistingAndNewContext: deletedBranch
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
	
	[self checkBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	{
		testBranch.metadata = @{@"hello" : @"world"};
		UKRaisesException([testCtx commit]);
	}];
}

// TODO: Test these behaviours during deleted->undeleted and undeleted->deleted
// transitions.

- (void) testPersistentRootMetadata
{
    [ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@{}, [testProot metadata]);
	 }];
    
    [persistentRoot setMetadata: @{@"key" : @"value"}];
    
    UKObjectsEqual((@{@"key" : @"value"}), [persistentRoot metadata]);

	UKRaisesException([[persistentRoot metadata] setValue: @"foo" forKey: @"bar"]);
	
    UKTrue([ctx hasChanges]);
    UKTrue([persistentRoot hasChanges]);
    
    [persistentRoot discardAllChanges];
    
    UKObjectsEqual(@{}, [persistentRoot metadata]);
    UKFalse([persistentRoot hasChanges]);
    
    [persistentRoot setMetadata: @{@"key" : @"value"}];
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKObjectsEqual(@{}, [[ctx2 persistentRootForUUID: [persistentRoot UUID]] metadata]);
    }
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual((@{@"key" : @"value"}), [testProot metadata]);
		 UKFalse([testCtx hasChanges]);
	 }];
    
    [persistentRoot setMetadata: @{@"key" : @"value2"}];
    UKObjectsEqual((@{@"key" : @"value2"}), [persistentRoot metadata]);
    
    [persistentRoot discardAllChanges];
    
    UKObjectsEqual((@{@"key" : @"value"}), [persistentRoot metadata]);
}

- (void) testPersistentRootMetadataOnPersistentRootFirstCommit
{
    COPersistentRoot *persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [persistentRoot2 setMetadata: @{@"hello" : @"world"}];
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot2
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual((@{@"hello" : @"world"}), [testProot metadata]);
	 }];
}

- (void) testAttributesOnUncommittedPersistentRoot
{
    COPersistentRoot *persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	UKNil([persistentRoot2 attributes]);
}

- (void) testAttributes
{
	NSDictionary *attrs = [persistentRoot attributes];
	UKIntsNotEqual(0, [attrs[COPersistentRootAttributeExportSize] longLongValue]);
}

- (void) testMixingObjectsAmongObjectGraphsBelongingToSinglePersistentRoot
{
	COBranch *altBranch = [originalBranch makeBranchWithLabel: @"altBranch"];
	[ctx commit];
	
	OutlineItem *child = [[altBranch objectGraphContext] insertObjectWithEntityName: @"OutlineItem"];
	[[altBranch rootObject] insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	UKRaisesException([[originalBranch rootObject] insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"]);
}

/**
 * Try to test all of the requirements of -branches and the other accessors
 */
- (void) testBranchesAccessors
{
	COBranch *current = [persistentRoot currentBranch];
    COBranch *regular;
    COBranch *deletedOnDisk;
    COBranch *pendingInsertion;
    COBranch *pendingDeletion;
    COBranch *pendingUndeletion;
    
    // 1. Setup the branches
    {
        regular = [[persistentRoot currentBranch] makeBranchWithLabel: @"regular"];
		[persistentRoot commit];

        deletedOnDisk = [[persistentRoot currentBranch] makeBranchWithLabel: @"deletedOnDisk"];
        [persistentRoot commit];
        deletedOnDisk.deleted = YES;
        [persistentRoot commit];

        pendingDeletion = [[persistentRoot currentBranch] makeBranchWithLabel: @"pendingDeletion"];
        [persistentRoot commit];

        pendingUndeletion = [[persistentRoot currentBranch] makeBranchWithLabel: @"pendingUndeletion"];
        [persistentRoot commit];
        pendingUndeletion.deleted = YES;
        [persistentRoot commit];

		pendingInsertion = [[persistentRoot currentBranch] makeBranchWithLabel: @"pendingInsertion"];
		pendingDeletion.deleted = YES;
        pendingUndeletion.deleted = NO;

		COPersistentRootInfo *persistentRootInfo = [store persistentRootInfoForUUID: [persistentRoot UUID]];

        // Check that the constraints we wanted to set up hold
		
        UKTrue([[persistentRootInfo branchUUIDs] containsObject: [regular UUID]]);
        UKTrue([[persistentRootInfo branchUUIDs] containsObject: [deletedOnDisk UUID]]);
		UKNil([persistentRootInfo branchInfoForUUID: [pendingInsertion UUID]]);
		UKTrue([[persistentRootInfo branchUUIDs] containsObject: [pendingDeletion UUID]]);
        UKTrue([[persistentRootInfo branchUUIDs] containsObject: [pendingUndeletion UUID]]);
		UKTrue(deletedOnDisk.deleted);
		UKTrue(pendingDeletion.deleted);
		UKFalse(pendingUndeletion.deleted);
    }
    
    // 2. Test the accessors
    
    UKObjectsEqual(S(current, regular, pendingInsertion, pendingUndeletion), [persistentRoot branches]);
    UKObjectsEqual(S(deletedOnDisk, pendingDeletion), [persistentRoot deletedBranches]);
    UKObjectsEqual(S(pendingInsertion), [persistentRoot branchesPendingInsertion]);
    UKObjectsEqual(S(pendingDeletion), [persistentRoot branchesPendingDeletion]);
    UKObjectsEqual(S(pendingUndeletion), [persistentRoot branchesPendingUndeletion]);

	UKObjectsEqual(regular, [persistentRoot branchForUUID: [regular UUID]]);
	UKObjectsEqual(deletedOnDisk, [persistentRoot branchForUUID: [deletedOnDisk UUID]]);
   	UKObjectsEqual(pendingInsertion, [persistentRoot branchForUUID: [pendingInsertion UUID]]);
	UKObjectsEqual(pendingDeletion, [persistentRoot branchForUUID: [pendingDeletion UUID]]);
   	UKObjectsEqual(pendingUndeletion, [persistentRoot branchForUUID: [pendingUndeletion UUID]]);

    // 3. Test what happens when we commit (all pending changes are made and no longer pending)
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	 {
		 COBranch *testCurrent = [testPersistentRoot branchForUUID: [current UUID]];
		 COBranch *testRegular = [testPersistentRoot branchForUUID: [regular UUID]];
		 COBranch *testDeletedOnDisk = [testPersistentRoot branchForUUID: [deletedOnDisk UUID]];
		 COBranch *testPendingInsertion = [testPersistentRoot branchForUUID: [pendingInsertion UUID]];
		 COBranch *testPendingDeletion = [testPersistentRoot branchForUUID: [pendingDeletion UUID]];
		 COBranch *testPendingUndeletion = [testPersistentRoot branchForUUID: [pendingUndeletion UUID]];
		 
		 UKObjectsEqual(S(testCurrent, testRegular, testPendingInsertion, testPendingUndeletion), [testPersistentRoot branches]);
		 UKObjectsEqual(S(testDeletedOnDisk, testPendingDeletion), [testPersistentRoot deletedBranches]);
		 UKObjectsEqual([NSSet set], [testPersistentRoot branchesPendingInsertion]);
		 UKObjectsEqual([NSSet set], [testPersistentRoot branchesPendingDeletion]);
		 UKObjectsEqual([NSSet set], [testPersistentRoot branchesPendingUndeletion]);
	 }];
}

- (void) testNormalPersistentRootUsageDoesNotCreateBranchObjectGraphContext
{
    COPersistentRoot *proot2 =  [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COBranch *branch = proot2.currentBranch;
	[ctx commit];
	
	[[proot2 rootObject] setLabel: @"Hello"];
	[ctx commit];
	
	UKNil([branch objectGraphContextWithoutUnfaulting]);
}

@end
