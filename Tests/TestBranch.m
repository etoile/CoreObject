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
    COUndoTrack *_testTrack;
}
@end

@implementation TestBranch

- (id) init
{
    SUPERINIT;
    persistentRoot =  [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    rootObj =  [persistentRoot rootObject];
    originalBranch =  [persistentRoot currentBranch];
    
    _testTrack = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    [_testTrack clear];
    
    return self;
}

- (void)testNoExistingCommitTrack
{
	[rootObj setValue: @"Groceries" forProperty: @"label"];
	
	UKNotNil(originalBranch);
	UKNil([originalBranch currentRevision]);

	[ctx commit];

	UKNotNil([originalBranch currentRevision]);
	UKObjectsEqual([originalBranch currentRevision], [rootObj revision]);
}

- (void)testSimpleRootObjectPropertyUndoRedo
{
	[rootObj setValue: @"Groceries" forProperty: @"label"];
	[ctx commit];
	
	CORevision *firstRevision = [originalBranch currentRevision];
	UKNotNil(originalBranch);
	UKNotNil(firstRevision);
	UKNil([firstRevision parentRevision]);

	[rootObj setValue: @"Shopping List" forProperty: @"label"];
	[ctx commit];
	CORevision *secondRevision = [originalBranch currentRevision];

    UKNotNil(secondRevision);
	UKObjectsNotEqual(firstRevision, secondRevision);

	[rootObj setValue: @"Todo" forProperty: @"label"];
	[ctx commit];
	CORevision *thirdRevision = [originalBranch currentRevision];
    
    UKNotNil(thirdRevision);
	UKObjectsNotEqual(thirdRevision, secondRevision);

	// First undo (Todo -> Shopping List)
    [originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"Shopping List", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, [originalBranch currentRevision]);

	// Second undo (Shopping List -> Groceries)
    [originalBranch setCurrentRevision: firstRevision];
	UKStringsEqual(@"Groceries", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(firstRevision, [originalBranch currentRevision]);

    // Verify that the revert to firstRevision is not committed
    UKObjectsEqual([thirdRevision revisionID],
                   [[[store persistentRootInfoForUUID: [persistentRoot UUID]] currentBranchInfo] currentRevisionID]);
    
	// First redo (Groceries -> Shopping List)
    [originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"Shopping List", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, [originalBranch currentRevision]);

    // Second redo (Shopping List -> Todo)
    [originalBranch setCurrentRevision: thirdRevision];
	UKStringsEqual(@"Todo", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(thirdRevision, [originalBranch currentRevision]);
}

/**
 * Test a root object with sub-object's connected as properties.
 */
- (void)testWithObjectPropertiesUndoRedo
{
	[rootObj setValue: @"Document" forProperty: @"label"];
	[ctx commit];
    CORevision *firstRevision = [originalBranch currentRevision];
    UKNotNil(firstRevision);
    
	COContainer *para1 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[rootObj addObject: para1];
	[rootObj addObject: para2];
	[ctx commit];
    CORevision *secondRevision = [originalBranch currentRevision];    
    UKNotNil(secondRevision);
    
	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];
	[ctx commit];
    CORevision *thirdRevision = [originalBranch currentRevision];
    UKNotNil(thirdRevision);
    
    // Undo
    [originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	
    // Redo
    [originalBranch setCurrentRevision: thirdRevision];
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);
}

- (void)testDivergentCommitTrack
{
	[rootObj setValue: @"Document" forProperty: @"label"];
	[ctx commit]; // Revision 1
    CORevision *firstRevision = [originalBranch currentRevision];
    UKNotNil(firstRevision);

	COContainer *para1 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[rootObj addObject: para1];
	[rootObj addObject: para2];
	UKIntsEqual(2, [rootObj count]);
	[ctx commit]; // Revision 2 (base 1)

    CORevision *secondRevision = [originalBranch currentRevision];    
    UKNotNil(secondRevision);
    
    // Undo
    [originalBranch setCurrentRevision: firstRevision];
	UKIntsEqual(0, [rootObj count]);

	COContainer *para3 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para3 setValue: @"paragraph 3" forProperty: @"label"];
	[rootObj addObject: para3];
	[ctx commit];
    CORevision *divergentRevision = [originalBranch currentRevision];
    UKNotNil(divergentRevision);
    
	UKIntsEqual(1, [rootObj count]); // Revision 3 (base 1)

    // Undo
    [originalBranch setCurrentRevision: firstRevision];
	UKIntsEqual(0, [rootObj count]);

    
    // Redo
    [originalBranch setCurrentRevision: divergentRevision];
	UKIntsEqual(1, [rootObj count]);
	UKStringsEqual(@"paragraph 3", [[[rootObj contentArray] objectAtIndex: 0] valueForProperty: @"label"]);
}

- (void)testBranchFromBranch
{
	UKNil([originalBranch currentRevision]);

	/* Commit some initial changes in the main branch */
	
	[rootObj setValue: @"Red" forProperty: @"label"];
	
    [persistentRoot commit];
    CORevision *rev1 = [originalBranch currentRevision];
	UKNotNil(rev1);
    
	[rootObj setValue: @"Blue" forProperty: @"label"];
	
    [persistentRoot commit];
	CORevision *rev2 = [originalBranch currentRevision];

	//UKObjectsEqual(A(rev1, rev2), [[[initialTrack loadedNodes] mappedCollection] revision]);

	/* Create branch 1 */
	
	COBranch *branch1 = [originalBranch makeBranchWithLabel: @"Branch 1"];
	CORevision *rev3 = [branch1 currentRevision];

    UKObjectsEqual(rev2, rev3);
    
	//UKObjectsEqual(A(rev1, rev2), [[[branch1 loadedNodes] mappedCollection] revision]);

	/* Switch to branch 1 */
	
	[persistentRoot setCurrentBranch: branch1];
	
	/* Commit some  changes in branch 1 */
	
	[[persistentRoot rootObject] setValue: @"Todo" forProperty: @"label"];
	
	[persistentRoot commit];
    CORevision *rev5 = [persistentRoot revision];
    
	[[persistentRoot rootObject] setValue: @"Tidi" forProperty: @"label"];
	
	[persistentRoot commit];
    CORevision *rev6 = [persistentRoot revision];

	//UKObjectsEqual(A(rev1, rev2, rev5, rev6), [[[branch1 loadedNodes] mappedCollection] revision]);
	
	/* Create branch2 */
	
	COBranch *branch2 = [branch1 makeBranchWithLabel: @"Branch 2" atRevision: rev5];
	CORevision *rev7 = [branch2 currentRevision];
	UKNotNil(rev7);
    
	/* Switch to branch 2 */
	
	[persistentRoot setCurrentBranch: branch2]; //rev8 (not yet the case)
	
    [persistentRoot commit];
    
	UKObjectsEqual([rev2 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot UUID]]
                                            branchInfoForUUID: [originalBranch UUID]] currentRevisionID]);
	UKObjectsEqual([rev6 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot UUID]]
                                         branchInfoForUUID: [branch1 UUID]] currentRevisionID]);
	UKObjectsEqual([rev5 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot UUID]]
                                         branchInfoForUUID: [branch2 UUID]] currentRevisionID]);
	
//	NSArray *parentTrackUUIDs = A([initialTrack UUID], [branch1 UUID]);
//	
//	UKObjectsEqual(parentTrackUUIDs, [store parentTrackUUIDsForCommitTrackUUID: [branch2 UUID]]);
//	UKObjectsEqual(A(rev1, rev2, rev5), [[[branch2 loadedNodes] mappedCollection] revision]);
//	
//	[object setValue: @"Boum" forProperty: @"label"];
//	
//	CORevision *rev9 = [[object persistentRoot] commit];
//	
//	[object setValue: @"Bam" forProperty: @"label"];
//	
//	CORevision *rev10 = [[object persistentRoot] commit];
//	
//	UKObjectsEqual(A(rev1, rev2, rev5, rev9, rev10), [[[branch2 loadedNodes] mappedCollection] revision]);
//	UKObjectsEqual(A(rev3, rev7), [self revisionsForStoreTrack]);
}

- (void) testBranchObjectGraphs
{
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1 commit];
    
    COBranch *branchA = [photo1 currentBranch];
    COBranch *branchB = [branchA makeBranchWithLabel: @"branchB"];
    
    UKObjectsNotSame([branchA objectGraphContext], [branchB objectGraphContext]);
    UKObjectsNotSame([[branchA objectGraphContext] rootObject], [[branchB objectGraphContext] rootObject]);
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKFalse([[branchB objectGraphContext] hasChanges]);
    
    COObject *branchBroot = [[branchB objectGraphContext] rootObject];
    [branchBroot setValue: @"photo1, branch B" forProperty: @"label"];
    
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKTrue([[branchB objectGraphContext] hasChanges]);
    UKObjectsEqual(S([branchBroot UUID]), SA([[branchA objectGraphContext] itemUUIDs]));
    UKObjectsEqual(S([branchBroot UUID]), SA([[branchB objectGraphContext] itemUUIDs]));
    
    COObject *childB = [[branchB objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childB setValue: @"childB" forProperty: @"label"];
    
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKTrue([[branchB objectGraphContext] hasChanges]);
    UKObjectsEqual(S([branchBroot UUID]),                SA([[branchA objectGraphContext] itemUUIDs]));
    UKObjectsEqual(S([branchBroot UUID], [childB UUID]), SA([[branchB objectGraphContext] itemUUIDs]));
    
    [branchBroot insertObject: childB atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKTrue([[branchB objectGraphContext] hasChanges]);
    UKObjectsEqual(S([branchBroot UUID]),                SA([[branchA objectGraphContext] itemUUIDs]));
    UKObjectsEqual(S([branchBroot UUID], [childB UUID]), SA([[branchB objectGraphContext] itemUUIDs]));
    
    [ctx commit];
    
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKFalse([[branchB objectGraphContext] hasChanges]);
}

- (void) testBranchLabel
{
    [ctx commit];
    
    UKNil([originalBranch label]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setLabel: @"Hello world"];
    
    UKObjectsEqual(@"Hello world", [originalBranch label]);
    UKTrue([ctx hasChanges]);
    UKTrue([persistentRoot hasChanges]);
    UKTrue([originalBranch hasChanges]);
    
    [originalBranch discardAllChanges];
    
    UKNil([originalBranch label]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setLabel: @"Hello world"];
        
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKNil([[[ctx2 persistentRootForUUID: [persistentRoot UUID]] currentBranch] label]);
    }
    
    [ctx commit];
    
    UKObjectsEqual(@"Hello world", [originalBranch label]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKObjectsEqual(@"Hello world", [[[ctx2 persistentRootForUUID: [persistentRoot UUID]] currentBranch] label]);
    }
    
    [originalBranch setLabel: @"Hello world 2"];
    UKObjectsEqual(@"Hello world 2", [originalBranch label]);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual(@"Hello world", [originalBranch label]);
}

// NOTE: All dictionaries are reported as mutable on 10.7.
- (BOOL) reportsImmutableDictionaryCorrectly
{
	return ([[NSDictionary dictionary] isKindOfClass: [NSMutableDictionary class]] == NO);
}

- (void) testBranchMetadata
{
    [ctx commit];

    UKObjectsEqual([NSDictionary dictionary], [originalBranch metadata]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setMetadata: D(@"value", @"key")];
    
    UKObjectsEqual(D(@"value", @"key"), [originalBranch metadata]);

	if ([self reportsImmutableDictionaryCorrectly])
	{
    	UKFalse([[originalBranch metadata] isKindOfClass: [NSMutableDictionary class]]);
	}
    UKTrue([ctx hasChanges]);
    UKTrue([persistentRoot hasChanges]);
    UKTrue([originalBranch hasChanges]);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual([NSDictionary dictionary], [originalBranch metadata]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setMetadata: D(@"value", @"key")];
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKObjectsEqual([NSDictionary dictionary], [[[ctx2 persistentRootForUUID: [persistentRoot UUID]] currentBranch] metadata]);
    }
    
    [ctx commit];
    
    UKObjectsEqual(D(@"value", @"key"), [originalBranch metadata]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKObjectsEqual(D(@"value", @"key"), [[[ctx2 persistentRootForUUID: [persistentRoot UUID]] currentBranch] metadata]);
    }
    
    [originalBranch setMetadata: D(@"value2", @"key")];
    UKObjectsEqual(D(@"value2", @"key"), [originalBranch metadata]);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual(D(@"value", @"key"), [originalBranch metadata]);
}

- (void) testBranchMetadataOnPersistentRootFirstCommit
{
    COPersistentRoot *persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot2 currentBranch] setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot2 = [ctx2 persistentRootForUUID: [persistentRoot2 UUID]];
        
        UKObjectsEqual(D(@"world", @"hello"), [[ctx2persistentRoot2 currentBranch] metadata]);
    }
}

- (void) testBranchMetadataOnBranchFirstCommit
{
    [ctx commit];
    
    COBranch *branch2 = [[persistentRoot currentBranch] makeBranchWithLabel: @"test"];
    [ctx commit];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        
        UKObjectsEqual(D(@"test", kCOBranchLabel), [[ctx2persistentRoot branchForUUID: [branch2 UUID]] metadata]);
    }
}

- (void) testBranchMetadataOnBranchSetOnFirstCommit
{
    [ctx commit];
    
    COBranch *branch2 = [[persistentRoot currentBranch] makeBranchWithLabel: @""];
    [branch2 setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        
        UKObjectsEqual(D(@"world", @"hello"), [[ctx2persistentRoot branchForUUID: [branch2 UUID]] metadata]);
    }
}

- (void) testRevisionWithID
{
}


- (void) testSimpleMerge
{
    OutlineItem *childObj = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [rootObj insertObject: childObj atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [rootObj setLabel: @"0"];
    [childObj setLabel: @"0"];
    [ctx commit];
    
    COBranch *initialBranch = [persistentRoot currentBranch];
    COBranch *secondBranch = [initialBranch makeBranchWithLabel: @"second branch"];
    
    // initialBranch will edit rootObj's label
    // secondBranch will edit childObj's label
    
    [rootObj setLabel: @"1"];
    [(OutlineItem *)[[secondBranch objectGraphContext] objectWithUUID: [childObj UUID]] setLabel: @"2"];
    [ctx commit];
    
    {
        // Quick check that the commits worked
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *persistentRootCtx2 = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        
        CORevision *initialBranchRev = [persistentRootCtx2 revision];
        CORevision *secondBranchRev = [[persistentRootCtx2 branchForUUID: [secondBranch UUID]] currentRevision];
        CORevision *initialRev = [initialBranchRev parentRevision];
        
        // Check for the proper relationship
        
        UKObjectsEqual(initialRev, [secondBranchRev parentRevision]);
        
        UKObjectsNotEqual(initialBranchRev, secondBranchRev);
        UKObjectsNotEqual(initialBranchRev, initialRev);
        UKObjectsNotEqual(initialRev, secondBranchRev);
        
        // Check for the proper contents
        
        UKObjectsEqual(@"1", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialBranchRev] rootObject] label]);
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialBranchRev] objectWithUUID: [childObj UUID]] label]);
        
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: secondBranchRev] rootObject] label]);
        UKObjectsEqual(@"2", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: secondBranchRev] objectWithUUID: [childObj UUID]] label]);
        
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialRev] rootObject] label]);
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialRev] objectWithUUID: [childObj UUID]] label]);
    }
    
    [initialBranch setMergingBranch: secondBranch];
    
    COMergeInfo *mergeInfo = [initialBranch mergeInfoForMergingBranch: secondBranch];
    UKFalse([mergeInfo.diff hasConflicts]);
    
    [mergeInfo.diff applyTo: [initialBranch objectGraphContext]];
    [persistentRoot commit];
}

- (void) testRevertToRevision
{
    
}

- (void) testDiscardAllChangesAndHasChanges
{
    // -discardAllChanges raises an exception on uncommitted branches
    UKRaisesException([originalBranch discardAllChanges]);
    UKTrue([originalBranch hasChanges]);
    
    [persistentRoot commit];
    UKDoesNotRaiseException([originalBranch discardAllChanges]);
    UKFalse([originalBranch hasChanges]);
}

- (void) testDiscardAllChangesAndHasChangesForSetCurrentRevision
{
    [persistentRoot commit];
    CORevision *firstRevision = [originalBranch currentRevision];
    
    [[originalBranch rootObject] setLabel: @"test"];
    [persistentRoot commit];
    CORevision *secondRevision = [originalBranch currentRevision];
    
    UKFalse([originalBranch hasChanges]);
    UKObjectsEqual(@"test", [[originalBranch rootObject] label]);
    
    [originalBranch setCurrentRevision: firstRevision];
    UKTrue([originalBranch hasChanges]);
    UKFalse([[originalBranch objectGraphContext] hasChanges]);
    UKNil([[originalBranch rootObject] label]);

    [originalBranch discardAllChanges];
    UKFalse([originalBranch hasChanges]);
    UKObjectsEqual(secondRevision, [originalBranch currentRevision]);
    UKObjectsEqual(@"test", [[originalBranch rootObject] label]);
}

- (void) testDiscardAllChangesAndHasChangesForDelete
{
    [persistentRoot commit];

    COBranch *branch = [originalBranch makeBranchWithLabel: @"test"];
    [persistentRoot commit];
    
    branch.deleted = YES;
    UKTrue([branch hasChanges]);
    [branch discardAllChanges];
    UKFalse(branch.deleted);
}

/**
 * Tests writing a "tag" revision - that is, a revision with no changes
 * to embededd objects, but revision metadata that mark the revision as being
 * a point where the user invoked a save command.
 */
- (void) testSaveTagRevision
{
    NSDictionary *expectedMetadata = @{ @"type" : @"save",
                                        @"shortDescription" : @"user pressed save" };
    
    [ctx commit];
    CORevision *r1 = [originalBranch currentRevision];
    
    // This should cause a new revision to be written, even though there
    // are no changes in the embedded objects.
    originalBranch.shouldMakeEmptyCommit = YES;
    [ctx commitWithType: @"save"  shortDescription: @"user pressed save"];
    
    CORevision *r2 = [originalBranch currentRevision];
    
    UKNotNil(r1);
    UKNotNil(r2);
    UKObjectsNotEqual(r1, r2);
    UKObjectsNotEqual(expectedMetadata, [r1 metadata]);
    UKObjectsEqual(expectedMetadata, [r2 metadata]);
}

@end
