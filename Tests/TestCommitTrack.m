#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COBranch.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COPersistentRoot.h"

@interface TestCommitTrack : TestCommon <UKTest>
{
    COPersistentRoot *persistentRoot;
    COObject *rootObj;
    COBranch *originalBranch;
}
@end

@implementation TestCommitTrack

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

// FIXME: Port the rest of the tests

#if 0
- (void)testSimpleRootObjectPropertyUndoRedo
{
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Groceries" forProperty: @"label"];
	[ctx commit];
	
	COCommitTrack *commitTrack = [object commitTrack];
	COTrackNode *firstNode = [commitTrack currentNode];
	UKNotNil(commitTrack);
	UKNotNil(firstNode);
	UKFalse([commitTrack canUndo]);

	[object setValue: @"Shopping List" forProperty: @"label"];
	[ctx commit];
	COTrackNode *secondNode = [commitTrack currentNode];

	UKObjectsNotEqual(firstNode, secondNode);
	UKObjectsEqual([firstNode revision], [[secondNode revision] baseRevision]);

	[object setValue: @"Todo" forProperty: @"label"];
	[ctx commit];
	COTrackNode *thirdNode = [commitTrack currentNode];
	UKObjectsNotEqual(thirdNode, secondNode);
	UKObjectsEqual([[thirdNode revision] baseRevision], [secondNode revision]);

	// First undo (Todo -> Shopping List)
	[commitTrack undo];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondNode, [commitTrack currentNode]);

	// Second undo (Shopping List -> Groceries)
	[commitTrack undo];
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);
	UKObjectsEqual(firstNode, [commitTrack currentNode]);

	UKFalse([commitTrack canUndo]);

	// First redo (Groceries -> Shopping List)
	[commitTrack redo];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondNode, [commitTrack currentNode]);

	[commitTrack redo];
	UKStringsEqual(@"Todo", [object valueForProperty: @"label"]);
	UKObjectsEqual(thirdNode, [commitTrack currentNode]);

	UKFalse([commitTrack canRedo]);
}

/**
 * Test a root object with sub-object's connected as properties.
 */
- (void)testWithObjectPropertiesUndoRedo
{
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Document" forProperty: @"label"];
	[ctx commit];

	COContainer *para1 = [[object persistentRoot] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[object persistentRoot] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[object addObject: para1];
	[object addObject: para2];
	[ctx commit];

	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];
	[ctx commit];

	[[object commitTrack] undo];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	
	[[object commitTrack] redo];
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);
}

- (void)testDivergentCommitTrack
{
    CREATE_AUTORELEASE_POOL(pool);
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Document" forProperty: @"label"];
	[ctx commit]; // Revision 1

	COContainer *para1 = [[object persistentRoot] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[object persistentRoot] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[object addObject: para1];
	[object addObject: para2];
	UKIntsEqual(2, [object count]);
	[ctx commit]; // Revision 2 (base 1)

	[[object commitTrack] undo]; // back to Revision 1
	UKIntsEqual(0, [object count]);

	COContainer *para3 = [[object persistentRoot] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para3 setValue: @"paragraph 3" forProperty: @"label"];
	[object addObject: para3];
	[ctx commit];
	UKIntsEqual(1, [object count]); // Revision 3 (base 1)

	[[object commitTrack] undo];
	UKIntsEqual(0, [object count]);

	[[object commitTrack] redo];
	UKIntsEqual(1, [object count]);
	UKStringsEqual(@"paragraph 3", [[[object contentArray] objectAtIndex: 0] valueForProperty: @"label"]);
    DESTROY(pool);
    
	//UKIntsEqual(0, [para3 retainCount]);
}
#endif

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

#if 0

- (NSArray *)revisionsForStoreTrack
{
	return [store nodesForTrackUUID: [store UUID] nodeBuilder: (id <COTrackNodeBuilder>)store
		currentNodeIndex: NULL backwardLimit: NSUIntegerMax forwardLimit: NSUIntegerMax];
}

- (void)testBranchFromBranch
{
	COContainer *object = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];
	COCommitTrack *initialTrack = [[object commitTrack] retain];
	
	UKTrue([[initialTrack loadedNodes] isEmpty]);

	/* Commit some initial changes in the main branch */
	
	[object setValue: @"Red" forProperty: @"label"];
	
	CORevision *rev1 = [[object persistentRoot] commit];
	
	[object setValue: @"Blue" forProperty: @"label"];
	
	CORevision *rev2 = [[object persistentRoot] commit];

	UKObjectsEqual(A(rev1, rev2), [[[initialTrack loadedNodes] mappedCollection] revision]);

	/* Create branch 1 */
	
	COCommitTrack *branch1 = [initialTrack makeBranchWithLabel: @"Branch 1"];
	CORevision *rev3 = [store revisionWithRevisionNumber: [ctx latestRevisionNumber]];

	UKObjectsEqual(A(rev1, rev2), [[[branch1 loadedNodes] mappedCollection] revision]);

	/* Switch to branch 1 */
	
	[[object persistentRoot] setCommitTrack: branch1]; //rev4 (not yet the case)
	
	/* Commit some  changes in branch 1 */
	
	[object setValue: @"Todo" forProperty: @"label"];
	
	CORevision *rev5 = [[object persistentRoot] commit];
	
	[object setValue: @"Tidi" forProperty: @"label"];
	
	CORevision *rev6 = [[object persistentRoot] commit];

	UKObjectsEqual(A(rev1, rev2, rev5, rev6), [[[branch1 loadedNodes] mappedCollection] revision]);
	
	/* Create branch2 */
	
	COCommitTrack *branch2 = [branch1 makeBranchWithLabel: @"Branch 2" atRevision: rev5];
	CORevision *rev7 = [store revisionWithRevisionNumber: [ctx latestRevisionNumber]];
	
	/* Switch to branch 2 */
	
	[[object persistentRoot] setCommitTrack: branch2]; //rev8 (not yet the case)
	
	UKObjectsEqual(rev2, [store currentRevisionForTrackUUID: [initialTrack UUID]]);
	UKObjectsEqual(rev6, [store currentRevisionForTrackUUID: [branch1 UUID]]);
	UKObjectsEqual(rev5, [store currentRevisionForTrackUUID: [branch2 UUID]]);
	
	NSArray *parentTrackUUIDs = A([initialTrack UUID], [branch1 UUID]);
	
	UKObjectsEqual(parentTrackUUIDs, [store parentTrackUUIDsForCommitTrackUUID: [branch2 UUID]]);
	UKObjectsEqual(A(rev1, rev2, rev5), [[[branch2 loadedNodes] mappedCollection] revision]);
	
	[object setValue: @"Boum" forProperty: @"label"];
	
	CORevision *rev9 = [[object persistentRoot] commit];
	
	[object setValue: @"Bam" forProperty: @"label"];
	
	CORevision *rev10 = [[object persistentRoot] commit];
	
	UKObjectsEqual(A(rev1, rev2, rev5, rev9, rev10), [[[branch2 loadedNodes] mappedCollection] revision]);
	UKObjectsEqual(A(rev3, rev7), [self revisionsForStoreTrack]);
}
#endif

- (void)testCheapCopyCreation
{
    [persistentRoot commit];
    
	CORevision *rev1 = [originalBranch currentRevision];
    COPersistentRoot *copyRoot = [originalBranch makeCopyFromRevision: rev1];
    
	COBranch *copyRootBranch = [copyRoot currentBranch];
    
    UKNil([store persistentRootInfoForUUID: [copyRoot persistentRootUUID]]);
    
    [ctx commit];
    
    UKNotNil([store persistentRootInfoForUUID: [copyRoot persistentRootUUID]]);
    
    UKObjectsNotEqual([copyRootBranch UUID], [originalBranch UUID]);
    UKObjectsNotEqual([copyRoot persistentRootUUID], [persistentRoot persistentRootUUID]);

    //UKObjectsEqual(commitTrack, [branch parentTrack]);
	//UKTrue([rev1 isEqual: [rev2 baseRevision]]);
	
	/* Branch creation revision doesn't belong to either the source commit track or new branch */
//	UKObjectsEqual(rev1, [[commitTrack currentNode] revision]);
//	UKObjectsEqual(rev1, [[branch currentNode] revision]);
//	UKObjectsEqual(rev1, [branch parentRevision]);
//	
//	/* Branch creation doesn't touch the current persistent root revision */
//	UKObjectsEqual([object revision], rev1);
//	
//	/* Branch creation doesn't switch the branch */
//	UKObjectsSame(commitTrack, [[object persistentRoot] commitTrack]);
}

@end
