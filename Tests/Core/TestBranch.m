/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  December 2013
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

@interface TestBranch : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
    OutlineItem *rootObj;
    COBranch *originalBranch;
	COBranch *altBranch;
    COUndoTrack *_testTrack;
}
@end

@implementation TestBranch

- (id) init
{
    SUPERINIT;
    persistentRoot =  [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    rootObj =  persistentRoot.rootObject;
    originalBranch =  persistentRoot.currentBranch;
    
	[ctx commit];
	
	UKFalse(persistentRoot.objectGraphContext.hasChanges);
	UKFalse(originalBranch.objectGraphContext.hasChanges);
	
	UKNotNil(originalBranch.currentRevision);
	UKNotNil(originalBranch.headRevision);
	
	altBranch = [originalBranch makeBranchWithLabel: @"altBranch"];
	[ctx commit];

	UKFalse(altBranch.objectGraphContext.hasChanges);
	
    _testTrack = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    [_testTrack clear];
    
    return self;
}

- (void)testExceptionOnInit
{
	UKRaisesException([[COBranch alloc] init]);
}

- (void)testNoExistingCommitTrack
{
	[rootObj setValue: @"Groceries" forProperty: @"label"];
	
	UKNotNil(originalBranch);

	[ctx commit];

	[self checkBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKNotNil(testBranch.currentRevision);
		 UKObjectsEqual(testBranch.currentRevision, [testProot.rootObject revision]);
	 }];
}

- (void)testSimpleRootObjectPropertyUndoRedo
{
	CORevision *zerothRevision = originalBranch.currentRevision;
	UKNotNil(originalBranch);
	UKNotNil(zerothRevision);
	UKNil(zerothRevision.parentRevision);
	
	[rootObj setValue: @"Groceries" forProperty: @"label"];
	[ctx commit];
	
	CORevision *firstRevision = originalBranch.currentRevision;
	UKNotNil(originalBranch);
	UKNotNil(firstRevision);
	UKNotNil(firstRevision.parentRevision);

	[rootObj setValue: @"Shopping List" forProperty: @"label"];
	[ctx commit];
	CORevision *secondRevision = originalBranch.currentRevision;

    UKNotNil(secondRevision);
	UKObjectsNotEqual(firstRevision, secondRevision);

	[rootObj setValue: @"Todo" forProperty: @"label"];
	[ctx commit];
	CORevision *thirdRevision = originalBranch.currentRevision;
    
    UKNotNil(thirdRevision);
	UKObjectsNotEqual(thirdRevision, secondRevision);
	UKObjectsEqual(thirdRevision, originalBranch.headRevision);

	// First undo (Todo -> Shopping List)
	[originalBranch undo]; //[originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"Shopping List", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, originalBranch.currentRevision);
	UKObjectsEqual(thirdRevision, originalBranch.headRevision);
	
	// Second undo (Shopping List -> Groceries)
	[originalBranch undo]; //[originalBranch setCurrentRevision: firstRevision];
	UKStringsEqual(@"Groceries", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(firstRevision, originalBranch.currentRevision);
	UKObjectsEqual(thirdRevision, originalBranch.headRevision);
	
    // Verify that the revert to firstRevision is not committed
    UKObjectsEqual(thirdRevision.UUID,
                   [store persistentRootInfoForUUID: persistentRoot.UUID].currentRevisionUUID);
    
	// First redo (Groceries -> Shopping List)
	[originalBranch redo]; //[originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"Shopping List", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, originalBranch.currentRevision);
	UKObjectsEqual(thirdRevision, originalBranch.headRevision);
	
    // Second redo (Shopping List -> Todo)
	[originalBranch redo]; //[originalBranch setCurrentRevision: thirdRevision];
	UKStringsEqual(@"Todo", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(thirdRevision, originalBranch.currentRevision);
	UKObjectsEqual(thirdRevision, originalBranch.headRevision);
}

/**
 * Test a root object with sub-object's connected as properties.
 */
- (void)testWithObjectPropertiesUndoRedo
{
	[rootObj setValue: @"Document" forProperty: @"label"];
	[ctx commit];
    CORevision *firstRevision = originalBranch.currentRevision;
    UKNotNil(firstRevision);
    
	COContainer *para1 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[rootObj addObject: para1];
	[rootObj addObject: para2];
	[ctx commit];
    CORevision *secondRevision = originalBranch.currentRevision;    
    UKNotNil(secondRevision);
    
	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];
	[ctx commit];
    CORevision *thirdRevision = originalBranch.currentRevision;
    UKNotNil(thirdRevision);
    
    // Undo
    [originalBranch undo]; //[originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	
    // Redo
    [originalBranch redo]; //[originalBranch setCurrentRevision: thirdRevision];
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);
}

- (void)testDivergentCommitTrack
{
	[rootObj setValue: @"Document" forProperty: @"label"];
	[ctx commit]; // Revision 1
    CORevision *firstRevision = originalBranch.currentRevision;
    UKNotNil(firstRevision);

	COContainer *para1 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[rootObj addObject: para1];
	[rootObj addObject: para2];
	UKIntsEqual(2, rootObj.count);
	[ctx commit]; // Revision 2 (base 1)

    CORevision *secondRevision = originalBranch.currentRevision;    
    UKNotNil(secondRevision);
    
    // Undo
    [originalBranch undo]; //[originalBranch setCurrentRevision: firstRevision];
	UKIntsEqual(0, rootObj.count);

	COContainer *para3 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para3 setValue: @"paragraph 3" forProperty: @"label"];
	[rootObj addObject: para3];
	[ctx commit];
    CORevision *divergentRevision = originalBranch.currentRevision;
    UKNotNil(divergentRevision);
    
	UKIntsEqual(1, rootObj.count); // Revision 3 (base 1)

    // Undo
    [originalBranch undo]; //[originalBranch setCurrentRevision: firstRevision];
	UKIntsEqual(0, rootObj.count);

    
    // Redo
    [originalBranch redo]; //[originalBranch setCurrentRevision: divergentRevision];
	UKIntsEqual(1, rootObj.count);
	UKStringsEqual(@"paragraph 3", [[rootObj contentArray][0] valueForProperty: @"label"]);
}

- (void)testBranchFromBranch
{
	/* Commit some initial changes in the main branch */
	
	[rootObj setValue: @"Red" forProperty: @"label"];
	
    [persistentRoot commit];
    CORevision *rev1 = originalBranch.currentRevision;
	UKNotNil(rev1);
    
	[rootObj setValue: @"Blue" forProperty: @"label"];
	
    [persistentRoot commit];
	CORevision *rev2 = originalBranch.currentRevision;

	//UKObjectsEqual(A(rev1, rev2), [[[initialTrack loadedNodes] mappedCollection] revision]);

	/* Create branch 1 */
	
	COBranch *branch1 = [originalBranch makeBranchWithLabel: @"Branch 1"];
	CORevision *rev3 = branch1.currentRevision;

    UKObjectsEqual(rev2, rev3);
    
	//UKObjectsEqual(A(rev1, rev2), [[[branch1 loadedNodes] mappedCollection] revision]);

	/* Switch to branch 1 */
	
	persistentRoot.currentBranch = branch1;
	
	/* Commit some  changes in branch 1 */
	
	[persistentRoot.rootObject setValue: @"Todo" forProperty: @"label"];
	
	[persistentRoot commit];
    CORevision *rev5 = persistentRoot.currentRevision;
    
	[persistentRoot.rootObject setValue: @"Tidi" forProperty: @"label"];
	
	[persistentRoot commit];
    CORevision *rev6 = persistentRoot.currentRevision;

	//UKObjectsEqual(A(rev1, rev2, rev5, rev6), [[[branch1 loadedNodes] mappedCollection] revision]);
	
	/* Create branch2 */
	
	COBranch *branch2 = [branch1 makeBranchWithLabel: @"Branch 2" atRevision: rev5];
	CORevision *rev7 = branch2.currentRevision;
	UKNotNil(rev7);
    
	/* Switch to branch 2 */
	
	persistentRoot.currentBranch = branch2; //rev8 (not yet the case)
	
    [persistentRoot commit];
    
	UKObjectsEqual(rev2.UUID, [[[store persistentRootInfoForUUID: persistentRoot.UUID]
                                            branchInfoForUUID: originalBranch.UUID] currentRevisionUUID]);
	UKObjectsEqual(rev6.UUID, [[[store persistentRootInfoForUUID: persistentRoot.UUID]
                                         branchInfoForUUID: branch1.UUID] currentRevisionUUID]);
	UKObjectsEqual(rev5.UUID, [[[store persistentRootInfoForUUID: persistentRoot.UUID]
                                         branchInfoForUUID: branch2.UUID] currentRevisionUUID]);
	
//	NSArray *parentTrackUUIDs = A(initialTrack.UUID, branch1.UUID);
//	
//	UKObjectsEqual(parentTrackUUIDs, [store parentTrackUUIDsForCommitTrackUUID: branch2.UUID]);
//	UKObjectsEqual(A(rev1, rev2, rev5), [[[branch2 loadedNodes] mappedCollection] revision]);
//	
//	[object setValue: @"Boum" forProperty: @"label"];
//	
//	CORevision *rev9 = [object.persistentRoot commit];
//	
//	[object setValue: @"Bam" forProperty: @"label"];
//	
//	CORevision *rev10 = [object.persistentRoot commit];
//	
//	UKObjectsEqual(A(rev1, rev2, rev5, rev9, rev10), [[[branch2 loadedNodes] mappedCollection] revision]);
//	UKObjectsEqual(A(rev3, rev7), [self revisionsForStoreTrack]);
}

- (void) testBranchObjectGraphs
{
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1 commit];
    
    COBranch *branchA = photo1.currentBranch;
    COBranch *branchB = [branchA makeBranchWithLabel: @"branchB"];
    
    UKObjectsNotSame(branchA.objectGraphContext, branchB.objectGraphContext);
    UKObjectsNotSame([branchA.objectGraphContext rootObject], [branchB.objectGraphContext rootObject]);
    UKFalse(branchA.objectGraphContext.hasChanges);
    UKFalse(branchB.objectGraphContext.hasChanges);
    
    COObject *branchBroot = branchB.objectGraphContext.rootObject;
    [branchBroot setValue: @"photo1, branch B" forProperty: @"label"];
    
    UKFalse(branchA.objectGraphContext.hasChanges);
    UKTrue(branchB.objectGraphContext.hasChanges);
    UKObjectsEqual(S(branchBroot.UUID), SA(branchA.objectGraphContext.itemUUIDs));
    UKObjectsEqual(S(branchBroot.UUID), SA(branchB.objectGraphContext.itemUUIDs));
    
    COObject *childB = [branchB.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childB setValue: @"childB" forProperty: @"label"];
    
    UKFalse(branchA.objectGraphContext.hasChanges);
    UKTrue(branchB.objectGraphContext.hasChanges);
    UKObjectsEqual(S(branchBroot.UUID),                SA(branchA.objectGraphContext.itemUUIDs));
    UKObjectsEqual(S(branchBroot.UUID, childB.UUID), SA(branchB.objectGraphContext.itemUUIDs));
    
    [branchBroot insertObject: childB atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

    UKFalse(branchA.objectGraphContext.hasChanges);
    UKTrue(branchB.objectGraphContext.hasChanges);
    UKObjectsEqual(S(branchBroot.UUID),                SA(branchA.objectGraphContext.itemUUIDs));
    UKObjectsEqual(S(branchBroot.UUID, childB.UUID), SA(branchB.objectGraphContext.itemUUIDs));
    
    [ctx commit];
    
    UKFalse(branchA.objectGraphContext.hasChanges);
    UKFalse(branchB.objectGraphContext.hasChanges);
}

- (void) testBranchLabel
{
    [ctx commit];
    
    UKNil(originalBranch.label);
    UKFalse(ctx.hasChanges);
    UKFalse(persistentRoot.hasChanges);
    UKFalse(originalBranch.hasChanges);
    
    originalBranch.label = @"Hello world";
    
    UKObjectsEqual(@"Hello world", originalBranch.label);
    UKTrue(ctx.hasChanges);
    UKTrue(persistentRoot.hasChanges);
    UKTrue(originalBranch.hasChanges);
    
    [originalBranch discardAllChanges];
    
    UKNil(originalBranch.label);
    UKFalse(originalBranch.hasChanges);
    
    originalBranch.label = @"Hello world";
        
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: store.URL];
        UKNil([ctx2 persistentRootForUUID: persistentRoot.UUID].currentBranch.label);
    }
    
    [ctx commit];
	
	[self checkBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@"Hello world", testBranch.label);
		 UKFalse(testCtx.hasChanges);
		 UKFalse(testProot.hasChanges);
		 UKFalse(testBranch.hasChanges);
	 }];
    
    originalBranch.label = @"Hello world 2";
    UKObjectsEqual(@"Hello world 2", originalBranch.label);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual(@"Hello world", originalBranch.label);
}

- (void) testBranchMetadata
{
    [ctx commit];

	[self checkBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@{}, testBranch.metadata);
		 UKFalse(testCtx.hasChanges);
		 UKFalse(testProot.hasChanges);
		 UKFalse(testBranch.hasChanges);
	 }];
    
    [originalBranch setMetadata: D(@"value", @"key")];
    
    UKObjectsEqual(D(@"value", @"key"), originalBranch.metadata);

	UKRaisesException(((NSMutableDictionary *)originalBranch.metadata)[@"bar"] = @"foo");
	UKTrue(ctx.hasChanges);
    UKTrue(persistentRoot.hasChanges);
    UKTrue(originalBranch.hasChanges);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual(@{}, originalBranch.metadata);
    UKFalse(originalBranch.hasChanges);
    
    [originalBranch setMetadata: D(@"value", @"key")];
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: store.URL];
        UKObjectsEqual(@{}, [ctx2 persistentRootForUUID: persistentRoot.UUID].currentBranch.metadata);
    }
    
    [ctx commit];
    
	[self checkBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual((@{@"key" : @"value"}), testBranch.metadata);
		 UKFalse(testCtx.hasChanges);
		 UKFalse(testProot.hasChanges);
		 UKFalse(testBranch.hasChanges);
	 }];
    
    [originalBranch setMetadata: D(@"value2", @"key")];
    UKObjectsEqual(D(@"value2", @"key"), originalBranch.metadata);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual(D(@"value", @"key"), originalBranch.metadata);
}

- (void) testBranchMetadataOnPersistentRootFirstCommit
{
    COPersistentRoot *persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [persistentRoot2.currentBranch setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot2
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
        UKObjectsEqual(D(@"world", @"hello"), testBranch.metadata);
	 }];
}

- (void) testBranchMetadataOnBranchFirstCommit
{
    [ctx commit];
    
    COBranch *branch2 = [persistentRoot.currentBranch makeBranchWithLabel: @"test"];
    [ctx commit];
    
	[self checkBranchWithExistingAndNewContext: branch2
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(D(@"test", kCOBranchLabel), testBranch.metadata);
	 }];
}

- (void) testBranchMetadataOnBranchSetOnFirstCommit
{
    [ctx commit];
    
    COBranch *branch2 = [persistentRoot.currentBranch makeBranchWithLabel: @""];
    [branch2 setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
	[self checkBranchWithExistingAndNewContext: branch2
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
        UKObjectsEqual(D(@"world", @"hello"), testBranch.metadata);
	 }];
}

- (void) testRevisionWithID
{
}


- (void) testSimpleMerge
{
    OutlineItem *childObj = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [rootObj insertObject: childObj atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    rootObj.label = @"0";
    childObj.label = @"0";
    [ctx commit];
    
    COBranch *initialBranch = persistentRoot.currentBranch;
    COBranch *secondBranch = [initialBranch makeBranchWithLabel: @"second branch"];
    
    // initialBranch will edit rootObj's label
    // secondBranch will edit childObj's label
    
    rootObj.label = @"1";
    ((OutlineItem *)[secondBranch.objectGraphContext loadedObjectForUUID: childObj.UUID]).label = @"2";
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 // Quick check that the commits worked
		 
		 CORevision *initialBranchRev = testProot.currentRevision;
		 CORevision *secondBranchRev = [testProot branchForUUID: secondBranch.UUID].currentRevision;
		 CORevision *initialRev = initialBranchRev.parentRevision;
		 
		 // Check for the proper relationship
		 
		 UKObjectsEqual(initialRev, secondBranchRev.parentRevision);
		 
		 UKObjectsNotEqual(initialBranchRev, secondBranchRev);
		 UKObjectsNotEqual(initialBranchRev, initialRev);
		 UKObjectsNotEqual(initialRev, secondBranchRev);
		 
		 // Check for the proper contents
		 
		 UKObjectsEqual(@"1", [(OutlineItem *)[[testProot objectGraphContextForPreviewingRevision: initialBranchRev] rootObject] label]);
		 UKObjectsEqual(@"0", [(OutlineItem *)[[testProot objectGraphContextForPreviewingRevision: initialBranchRev] loadedObjectForUUID: childObj.UUID] label]);
		 
		 UKObjectsEqual(@"0", [(OutlineItem *)[[testProot objectGraphContextForPreviewingRevision: secondBranchRev] rootObject] label]);
		 UKObjectsEqual(@"2", [(OutlineItem *)[[testProot objectGraphContextForPreviewingRevision: secondBranchRev] loadedObjectForUUID: childObj.UUID] label]);
		 
		 UKObjectsEqual(@"0", [(OutlineItem *)[[testProot objectGraphContextForPreviewingRevision: initialRev] rootObject] label]);
		 UKObjectsEqual(@"0", [(OutlineItem *)[[testProot objectGraphContextForPreviewingRevision: initialRev] loadedObjectForUUID: childObj.UUID] label]);
	 }];
    
    initialBranch.mergingBranch = secondBranch;
    
	CORevision *headRevBeforeMerge = initialBranch.currentRevision;
	CORevision *mergingBranchRevision = secondBranch.currentRevision;
	
    COMergeInfo *mergeInfo = [initialBranch mergeInfoForMergingBranch: secondBranch];
    UKFalse([mergeInfo.diff hasConflicts]);
    
    [mergeInfo.diff applyTo: initialBranch.objectGraphContext];
    [persistentRoot commit];
	
	CORevision *mergedRevision = persistentRoot.currentRevision;
	UKObjectsEqual(headRevBeforeMerge, mergedRevision.parentRevision);
	UKObjectsEqual(mergingBranchRevision, mergedRevision.mergeParentRevision);
}

- (void) testRevertToRevision
{
    
}

- (void) testSetCurrentRevisionWhenSupportsRevertFalseDisallowed
{
    [persistentRoot commit];
    CORevision *firstRevision = originalBranch.currentRevision;
    
    [originalBranch.rootObject setLabel: @"test"];
    [persistentRoot commit];
    CORevision *secondRevision = originalBranch.currentRevision;

	UKDoesNotRaiseException([originalBranch setCurrentRevision: firstRevision]);
	UKDoesNotRaiseException([originalBranch setCurrentRevision: secondRevision]);
	UKObjectsEqual(secondRevision, originalBranch.currentRevision);
	
	originalBranch.supportsRevert = NO;
	
	UKRaisesException([originalBranch setCurrentRevision: firstRevision]);
	UKObjectsEqual(secondRevision, originalBranch.currentRevision);
}

- (void) testDiscardAllChangesAndHasChanges
{
	COBranch *uncommittedBranch = [originalBranch makeBranchWithLabel: @"uncommitted"];

    // -discardAllChanges raises an exception on uncommitted branches
    UKRaisesException([uncommittedBranch discardAllChanges]);
    UKTrue(uncommittedBranch.hasChanges);
    
    [persistentRoot commit];
	
	[self checkBranchWithExistingAndNewContext: uncommittedBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKDoesNotRaiseException([testBranch discardAllChanges]);
		 UKFalse(testBranch.hasChanges);
	 }];
}

- (void) testDiscardAllChangesAndHasChangesForSetCurrentRevision
{
    [persistentRoot commit];
    CORevision *firstRevision = originalBranch.currentRevision;
    
	UKTrue(originalBranch.rootObject != nil);
    [originalBranch.rootObject setLabel: @"test"];
    [persistentRoot commit];
    CORevision *secondRevision = originalBranch.currentRevision;
    
	[self checkBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKFalse(testBranch.hasChanges);
		 UKObjectsEqual(@"test", [testBranch.rootObject label]);
		
		 testBranch.currentRevision = firstRevision;
		 UKTrue(testBranch.hasChanges);
		 UKFalse(testBranch.objectGraphContext.hasChanges);
		 UKNil([testBranch.rootObject label]);

		 [testBranch discardAllChanges];
		 UKFalse(testBranch.hasChanges);
		 UKObjectsEqual(secondRevision, testBranch.currentRevision);
		 UKObjectsEqual(@"test", [testBranch.rootObject label]);
	 }];
}

- (void) testDiscardAllChangesAndHasChangesForDelete
{
    [persistentRoot commit];

    COBranch *branch = [originalBranch makeBranchWithLabel: @"test"];
    [persistentRoot commit];
    
	[self checkBranchWithExistingAndNewContext: branch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 testBranch.deleted = YES;
		 UKTrue(testBranch.hasChanges);
		 [testBranch discardAllChanges];
		 UKFalse(testBranch.deleted);
	 }];
}

/**
 * Tests writing a "checkpoint" revision - that is, a revision with no changes
 * to embededd objects, but revision metadata that mark the revision as being
 * a point where the user invoked a save command.
 */
- (void) testSaveCheckpointRevision
{
    NSDictionary *expectedMetadata = @{ @"type" : @"save",
                                        @"shortDescription" : @"user pressed save" };
    
    [ctx commit];
    CORevision *r1 = originalBranch.currentRevision;
    
    // This should cause a new revision to be written, even though there
    // are no changes in the inner objects.
    originalBranch.shouldMakeEmptyCommit = YES;
    [ctx commitWithMetadata: expectedMetadata
				  undoTrack: nil
					  error: NULL];
    
	[self checkBranchWithExistingAndNewContext: originalBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 CORevision *r2 = testBranch.currentRevision;
    
		 UKNotNil(r1);
		 UKNotNil(r2);
		 UKObjectsNotEqual(r1, r2);
		 UKObjectsNotEqual(expectedMetadata, r1.metadata);
		 UKObjectsEqual(expectedMetadata, r2.metadata);
	 }];
}

// Check that attempting to commit modifications to a deleted branch
// raises an exception

- (void) testExceptionOnDeletedBranchSetRevision
{
	CORevision *r0 = altBranch.currentRevision;
	[altBranch.rootObject setLabel: @"hi"];
	[ctx commit];
	
	altBranch.deleted = YES;
	[ctx commit];
	
	[self checkBranchWithExistingAndNewContext: altBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 testBranch.currentRevision = r0;
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedBranchModifyInnerObject
{
	altBranch.deleted = YES;
	[ctx commit];
	
	[self checkBranchWithExistingAndNewContext: altBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKTrue(testBranch.deleted);
		 
		 [testBranch.rootObject setLabel: @"hi"];
		 UKTrue(testBranch.hasChanges);
		 UKRaisesException([testCtx commit]);
	 }];
}

- (void) testExceptionOnDeletedBranchSetBranchMetadata
{
	altBranch.deleted = YES;
	[ctx commit];
	
	[self checkBranchWithExistingAndNewContext: altBranch
									  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 testBranch.metadata = @{@"hello" : @"world"};
		 UKRaisesException([testCtx commit]);
	 }];
}

// TODO: Test these behaviours during deleted->undeleted and undeleted->deleted
// transitions.

- (void) testSelectiveUndoRedo
{
	OutlineItem *root = persistentRoot.rootObject;
	OutlineItem *child1 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[root addObject: child1];
	
    [ctx commit];
	
    // make some commits...
    
    root.label = @"doc1";
    [ctx commitWithUndoTrack: _testTrack];
    
	child1.label = @"child1";
    [ctx commitWithUndoTrack: _testTrack];
    
	root.label = @"doc1a";
    [ctx commitWithUndoTrack: _testTrack];
	CORevision *doc1Todoc1aRevision = persistentRoot.currentRevision;
	
    child1.label = @"child1a";
    [ctx commitWithUndoTrack: _testTrack];
	CORevision *child1Tochild1aRevision = persistentRoot.currentRevision;
	
    // undo doc1 -> doc1a
	
	UKObjectsEqual(@"doc1a", root.label);
	UKObjectsEqual(@"child1a", child1.label);
	
	[originalBranch undoNode: doc1Todoc1aRevision];
	[ctx commit];
	
	UKObjectsEqual(@"doc1", root.label);
	UKObjectsEqual(@"child1a", child1.label);
	
	[originalBranch undo];
	[ctx commit];
	
	UKObjectsEqual(@"doc1a", root.label);
	UKObjectsEqual(@"child1a", child1.label);
	
	[originalBranch redo];
	[ctx commit];

	UKObjectsEqual(@"doc1", root.label);
	UKObjectsEqual(@"child1a", child1.label);

	[originalBranch undoNode: child1Tochild1aRevision];
	[ctx commit];
	
	UKObjectsEqual(@"doc1", root.label);
	UKObjectsEqual(@"child1", child1.label);
	
	[originalBranch redoNode: doc1Todoc1aRevision];
	[ctx commit];
	
	UKObjectsEqual(@"doc1a", root.label);
	UKObjectsEqual(@"child1", child1.label);
}

/**
 * This test checked that CoreObject doesn't internally keep track of COObjects
 * in NSSets. This would be dangerous, if a subclass changed the semantics of
 * isEqual:
 *
 * However we decided we can't allow overriding isEquals:.
 */
- (void) testOverriddenIsEqualsObject
{
	COPersistentRoot *proot2 = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupNoOpposite"];
	OverriddenIsEqualObject *obj1 = [[OverriddenIsEqualObject alloc] initWithObjectGraphContext: proot2.objectGraphContext];
	obj1.label = @"test";
	OverriddenIsEqualObject *obj2 = [[OverriddenIsEqualObject alloc] initWithObjectGraphContext: proot2.objectGraphContext];
	obj2.label = @"test";
	((OrderedGroupNoOpposite *)proot2.rootObject).contents = @[obj1, obj2];
	
	// The -isEqual: method on OverriddenIsEqualObject is overridden to do a
	// deep comparison of the label attribute, and ignore the objects' UUIDs.
	UKObjectsEqual(obj1, obj2);
	
	// The following fails, but we're not supporting overriding -isEquals:
	// Might be worth investigation why the next line fails though, not sure why
	// it would.
#if 0
	UKObjectsEqual(A(obj1, obj2), [proot2.rootObject contents]);
	
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: proot2
										inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OverriddenIsEqualObject *testObj1 = [testProot.objectGraphContext loadedObjectForUUID: obj1.UUID];
		 OverriddenIsEqualObject *testObj2 = [testProot.objectGraphContext loadedObjectForUUID: obj2.UUID];

		 UKNotNil(testObj1);
		 UKNotNil(testObj2);
		 UKObjectsNotSame(testObj1, testObj2);
		 UKObjectsEqual(A(testObj1, testObj2), [testProot.rootObject contents]);
	 }];
#endif
}

// See comment in -[COBranch modifiedItemsSnapshot] for why this is disabled
#if 0
- (void) testGarbageObjectsNotCommitted
{
	OutlineItem *garbage = [[OutlineItem alloc] initWithObjectGraphContext: persistentRoot.objectGraphContext];
	OutlineItem *notGarbage = [[OutlineItem alloc] initWithObjectGraphContext: persistentRoot.objectGraphContext];

	rootObj.contents = @[notGarbage];
		
	/* No references to 'garbage', so it should be garbage-collected at this point
	   and not committed. */
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKNil([testProot.objectGraphContext loadedObjectForUUID: garbage.UUID]);
	 }];
	
	// Implementation test: pull out the actual store revision and make sure it doesn't contain garbage
	
	COItemGraph *lastCommitDelta = [store partialItemGraphFromRevisionUUID: persistentRoot.currentRevision.parentRevision.UUID
															toRevisionUUID: persistentRoot.currentRevision.UUID
															persistentRoot: persistentRoot.UUID];
	/* The last commit changed exactly 2 objects: rootObj (modified) and notGarbage (inserted */
	UKObjectsEqual(S(rootObj.UUID, notGarbage.UUID), SA(lastCommitDelta.itemUUIDs));
}
#endif

- (void) testCommittedGarbageObjectsNotReloaded
{
	OutlineItem *garbage = [[OutlineItem alloc] initWithObjectGraphContext: persistentRoot.objectGraphContext];
	garbage.name = @"Garbage";
	rootObj.contents = @[garbage];
	[ctx commit];
	
	/* Sanity check - at this point, the 'garbage' object is still reachable (i.e., not yet garbage) */
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKNotNil([testProot.objectGraphContext loadedObjectForUUID: garbage.UUID]);
	 }];
	
	/* Now delete 'garbage' from its parent, making it actually garbage */
	
	rootObj.contents = @[];
	[ctx commit];
	
	/* When we reload the current revision in another editing context, we should
	   not load the garbage object as a COObject.
	 
	   Rationale: while it IS still present in the item graph returned returned
	   from the store (at least until another full snapshot happens in the store),
	   there's no point loading it as a COObject since it's not reachable in the graph.
	 */
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 if (isNewContext)
		 {
			 UKNil([testProot.objectGraphContext loadedObjectForUUID: garbage.UUID]);
		 }
	 }];
}

- (void) testCommitOnMultipleBranchesSimultaneously
{
	[altBranch.rootObject setLabel: @"change1"];
	[originalBranch.rootObject setLabel: @"change2"];
	[ctx commit];
	
	[self checkBranchWithExistingAndNewContext: altBranch
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@"change1", [testBranch.rootObject label]);
	 }];

	[self checkBranchWithExistingAndNewContext: originalBranch
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@"change2", [testBranch.rootObject label]);
	 }];
}

@end
