#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COCommitTrack.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COPersistentRoot.h"

@interface TestCommitTrack : TestCommon <UKTest>
- (void)testNoExistingCommitTrack;
- (void)testSimpleRootObjectPropertyUndoRedo;
- (void)testWithObjectPropertiesUndoRedo;
@end

@implementation TestCommitTrack

- (void)testNoExistingCommitTrack
{
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Groceries" forProperty: @"label"];
	
	COCommitTrack *commitTrack = [object commitTrack];
	UKNotNil(commitTrack);
	UKNil([commitTrack currentNode]);

	[ctx commit];

	UKNotNil([commitTrack currentNode]);
	UKObjectsEqual([[commitTrack currentNode] revision], [object revision]);
}

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

	//UKIntsEqual(0, [para3 retainCount]);
}

- (void)testBranchCreation
{
	COContainer *object = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];
	CORevision *rev1 = [[object persistentRoot] commit];

	COCommitTrack *commitTrack = [object commitTrack];
	COCommitTrack *branch = [commitTrack makeBranchWithLabel: @"Sandbox"];
	/* The branch creation has created a new revision */
	CORevision *rev2 = [[ctx store] revisionWithRevisionNumber: [ctx latestRevisionNumber]];
	
	UKNotNil(branch);
	UKObjectsNotEqual([branch UUID], [commitTrack UUID]);
	UKStringsEqual(@"Sandbox", [branch label]);
	UKObjectsEqual(commitTrack, [branch parentTrack]);
	UKObjectsEqual([object persistentRoot], [branch persistentRoot]);
	UKTrue([rev1 isEqual: [rev2 baseRevision]]);
	
	/* Branch creation revision doesn't belong to either the source commit track or new branch */
	UKObjectsEqual(rev1, [[commitTrack currentNode] revision]);
	UKObjectsEqual(rev1, [[branch currentNode] revision]);
	UKObjectsEqual(rev1, [branch parentRevision]);

	/* Branch creation doesn't touch the current persistent root revision */
	UKObjectsEqual([object revision], rev1);

	/* Branch creation doesn't switch the branch */
	UKObjectsSame(commitTrack, [[object persistentRoot] commitTrack]);
}

// TODO: Implement - (void)testBranchCreationFromBranch

- (void)testBranchSwitch
{
	COContainer *object = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];
	
	[object setValue: @"Untitled" forProperty: @"label"];
	
	CORevision *rev1 = [[object persistentRoot] commit];
	
	COCommitTrack *commitTrack = [[object commitTrack] retain];
	COCommitTrack *branch = [commitTrack makeBranchWithLabel: @"Sandbox"];
	/* The branch creation has created a new revision */
	CORevision *rev2 = [[ctx store] revisionWithRevisionNumber: [ctx latestRevisionNumber]];
	
	UKObjectKindOf(rev2, [store currentRevisionForTrackUUID: [store UUID]]);

	/* Switch to the Sandbox branch */

	[[object persistentRoot] setCommitTrack: branch];

	UKObjectsEqual([object commitTrack], branch);
	UKObjectsEqual([object persistentRoot], [branch persistentRoot]);
	UKObjectsEqual([object persistentRoot], [commitTrack persistentRoot]);

	UKObjectsEqual(rev1, [[commitTrack currentNode] revision]);
	UKObjectsEqual(rev1, [[branch currentNode] revision]);
	UKObjectsEqual(rev1, [object revision]);
	
	/* Commit some changes in the Sandbox branch */
	
	[object setValue: @"Todo" forProperty: @"label"];

	[[object persistentRoot] commit];

	[object setValue: @"Tidi" forProperty: @"label"];
	
	CORevision *rev4 = [[object persistentRoot] commit];
	
	UKObjectsEqual(rev1, [[commitTrack currentNode] revision]);
	UKObjectsEqual(rev4, [[branch currentNode] revision]);
	UKObjectsEqual(rev4, [object revision]);
	
	/* Switch back to the main branch */
	
	[[object persistentRoot] setCommitTrack: commitTrack];

	UKObjectsEqual([object commitTrack], commitTrack);
	UKObjectsEqual([object persistentRoot], [branch persistentRoot]);
	UKObjectsEqual([object persistentRoot], [commitTrack persistentRoot]);
	UKObjectsEqual(rev1, [[commitTrack currentNode] revision]);
	UKObjectsEqual(rev4, [[branch currentNode] revision]);
	UKObjectsEqual(rev1, [object revision]);

	UKObjectsEqual(@"Untitled", [object valueForProperty: @"label"]);

	[commitTrack release];
}

@end
