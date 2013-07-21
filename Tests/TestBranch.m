#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COBranch.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COPersistentRoot.h"

@interface TestBranch : TestCommon <UKTest>
{
    COPersistentRoot *persistentRoot;
    COContainer *rootObj;
    COBranch *originalBranch;
}
@end

@implementation TestBranch

- (id) init
{
    SUPERINIT;
    ASSIGN(persistentRoot, [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"]);
    ASSIGN(rootObj, [persistentRoot rootObject]);
    ASSIGN(originalBranch, [persistentRoot currentBranch]);
    return self;
}

- (void) dealloc
{
    DESTROY(rootObj);
    DESTROY(originalBranch);
    DESTROY(persistentRoot);
    [super dealloc];
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
                   [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] currentBranchInfo] currentRevisionID]);
    
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
    
	COContainer *para1 = [[originalBranch objectGraph] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[originalBranch objectGraph] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[rootObj addObject: para1];
	[rootObj addObject: para2];
	[ctx commit];
    CORevision *secondRevision = [originalBranch currentRevision];    

	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];
	[ctx commit];
    CORevision *thirdRevision = [originalBranch currentRevision];

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

	COContainer *para1 = [[originalBranch objectGraph] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[originalBranch objectGraph] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
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

	COContainer *para3 = [[originalBranch objectGraph] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para3 setValue: @"paragraph 3" forProperty: @"label"];
	[rootObj addObject: para3];
	[ctx commit];
    CORevision *divergentRevision = [originalBranch currentRevision];
    
	UKIntsEqual(1, [rootObj count]); // Revision 3 (base 1)

    // Undo
    [originalBranch setCurrentRevision: firstRevision];
	UKIntsEqual(0, [rootObj count]);

    
    // Redo
    [originalBranch setCurrentRevision: divergentRevision];
	UKIntsEqual(1, [rootObj count]);
	UKStringsEqual(@"paragraph 3", [[[rootObj contentArray] objectAtIndex: 0] valueForProperty: @"label"]);
}

- (void)testBranchCreation
{
    [persistentRoot commit];
    
	CORevision *rev1 = [[persistentRoot currentBranch] currentRevision];

	COBranch *branch = [originalBranch makeBranchWithLabel: @"Sandbox"];
	UKNotNil(branch);
	UKObjectsNotEqual([branch UUID], [originalBranch UUID]);
    
    /* Verify that the branch creation is not committed yet. */
    UKIntsEqual(1, [[[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] branchForUUID] allKeys] count]);
    
    [persistentRoot commit];

    UKIntsEqual(2, [[[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] branchForUUID] allKeys] count]);
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
                   [[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] currentBranchUUID]);    
    
	/* Commit some changes in the Sandbox branch */
	
    COObject *sandboxRootObj = [[branch objectGraph] rootObject];
    
	[sandboxRootObj setValue: @"Todo" forProperty: @"label"];

    UKObjectsEqual(@"Todo", [[persistentRoot rootObject] valueForProperty: @"label"]);
    
	[persistentRoot commit];

    UKObjectsEqual([branch UUID],
                   [[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] currentBranchUUID]);
    
	[sandboxRootObj setValue: @"Tidi" forProperty: @"label"];
	
    [persistentRoot commit];
    
	//CORevision *rev3 = [branch currentRevision];
    
    UKObjectsEqual(@"Tidi", [[persistentRoot rootObject] valueForProperty: @"label"]);
	
	/* Switch back to the main branch */
	
	[persistentRoot setCurrentBranch: originalBranch];
    
    UKObjectsEqual(@"Untitled", [[persistentRoot rootObject] valueForProperty: @"label"]);
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
    
	UKObjectsEqual([rev2 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]]
                                            branchInfoForUUID: [originalBranch UUID]] currentRevisionID]);
	UKObjectsEqual([rev6 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]]
                                         branchInfoForUUID: [branch1 UUID]] currentRevisionID]);
	UKObjectsEqual([rev5 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]]
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

- (void)testCheapCopyCreation
{
    [rootObj setValue: @"Untitled" forProperty: @"label"];
    
    [persistentRoot commit];
    
	CORevision *rev1 = [originalBranch currentRevision];
    COPersistentRoot *copyRoot = [originalBranch makeCopyFromRevision: rev1];
    
	COBranch *copyRootBranch = [copyRoot currentBranch];
    
    UKNil([store persistentRootInfoForUUID: [copyRoot persistentRootUUID]]);
    
    [ctx commit];
    
    UKNotNil([store persistentRootInfoForUUID: [copyRoot persistentRootUUID]]);
    
    UKObjectsNotEqual([copyRootBranch UUID], [originalBranch UUID]);
    UKObjectsNotEqual([copyRoot persistentRootUUID], [persistentRoot persistentRootUUID]);
    
    UKObjectsEqual(rev1, [copyRootBranch parentRevision]);
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

@end
