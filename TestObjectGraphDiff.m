#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COStore.h"
#import "COHistoryTrack.h"
#import "COContainer.h"
#import "COGroup.h"
#import "COObjectGraphDiff.h"
#import "TestCommon.h"

@interface TestObjectGraphDiff : NSObject <UKTest>
{
}
@end

@implementation TestObjectGraphDiff

- (void)testBasic
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild1 setValue: @"Pizza" forProperty: @"label"];
	[subchild2 setValue: @"Salad" forProperty: @"label"];
	[subchild3 setValue: @"Chips" forProperty: @"label"];
	[child addObject: subchild1];
	[child addObject: subchild2];
	[child addObject: subchild3];
	[parent addObject: child];
	
	COContainer *parentCtx2 = [ctx2 insertObject: parent];
	COContainer *childCtx2 = [ctx2 insertObject: child];
	COContainer *subchild1Ctx2 = [ctx2 insertObject: subchild1];
	COContainer *subchild2Ctx2 = [ctx2 insertObject: subchild2];
	COContainer *subchild3Ctx2 = [ctx2 insertObject: subchild3];	

	UKObjectsEqual([parent UUID], [parentCtx2 UUID]);
	UKObjectsEqual([child UUID], [childCtx2 UUID]);
	UKObjectsEqual([subchild1 UUID], [subchild1Ctx2 UUID]);
	UKObjectsEqual([subchild2 UUID], [subchild2Ctx2 UUID]);
	UKObjectsEqual([subchild3 UUID], [subchild3Ctx2 UUID]);
	
	// Now make some modifications to ctx2: 
	
	[childCtx2 removeObject: subchild2Ctx2]; // Remove "Salad"
	COContainer *subchild4Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	ETUUID *subchild4UUID = [subchild4Ctx2 UUID];
	[subchild4Ctx2 setValue: @"Salsa" forProperty: @"label"];
	[childCtx2 addObject: subchild4Ctx2]; // Add "Salsa"
	[childCtx2 setValue: @"Snacks" forProperty: @"label"];
	
	// Now create a diff
	COObjectGraphDiff *diff = [COObjectGraphDiff diffContainer: parent withContainer: parentCtx2];
	UKNotNil(diff);
	
	// Apply it to ctx1.
	
	[diff applyToContext: ctx1];
	
	// Now check that all of the changes were properly made.
	
	UKStringsEqual(@"Snacks", [child valueForProperty: @"label"]);
	UKObjectsSame(subchild1, [[child contentArray] objectAtIndex: 0]);
	UKObjectsSame(subchild3, [[child contentArray] objectAtIndex: 1]);
	COContainer *subchild4 = [[child contentArray] objectAtIndex: 2];
	UKStringsEqual(@"Salsa", [subchild4	valueForProperty: @"label"]);
	UKObjectsEqual(subchild4UUID, [subchild4 UUID]);
	UKObjectsSame(ctx1, [subchild4 editingContext]);
	
	[ctx2 release];
	[ctx1 release];
}

- (void)testMove
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child1 setValue: @"Groceries" forProperty: @"label"];
	[child2 setValue: @"Todo" forProperty: @"label"];
	[subchild1 setValue: @"Salad" forProperty: @"label"];
	[child1 addObject: subchild1];
	[parent addObject: child1];
	[parent addObject: child2];
	
	COContainer *parentCtx2 = [ctx2 insertObject: parent];
	COContainer *child1Ctx2 = [ctx2 insertObject: child1];
	COContainer *child2Ctx2 = [ctx2 insertObject: child2];
	COContainer *subchild1Ctx2 = [ctx2 insertObject: subchild1];
	
	// Now make some modifications to ctx2: (move "Salad" from "Groceries" to "Todo")
	
	[child1Ctx2 removeObject: subchild1Ctx2];	
	[child2Ctx2 addObject: subchild1Ctx2];
	
	// Now create a diff
	COObjectGraphDiff *diff = [COObjectGraphDiff diffContainer: parent withContainer: parentCtx2];
	UKNotNil(diff);
	
	// Apply it to ctx1.
	
	[diff applyToContext: ctx1];
	
	// Now check that all of the changes were properly made.
	
	UKIntsEqual(0, [[child1 contentArray] count]);
	UKIntsEqual(1, [[child2 contentArray] count]);
	UKObjectsSame(subchild1, [[child2 contentArray] objectAtIndex: 0]);
	UKObjectsSame(ctx1, [[[child2 contentArray] objectAtIndex: 0] editingContext]);
	
	[ctx2 release];
	[ctx1 release];	
}

- (void)testSimpleNonconflictingMerge
{
	OPEN_STORE(store);
	COEditingContext *ctx1 = NewContext(store);
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[child1 addObject: subchild1];
	[parent addObject: child1];
	[parent addObject: child2];
	[parent addObject: child3];
	
	[ctx1 commit];
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];
	
	// ctx2: remove child2, set a label for subchild1
	assert([[(id)[ctx2 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	[[ctx2 objectWithUUID: [child2 UUID]] setValue: nil forProperty: @"parentContainer"];
	assert([[(id)[ctx2 objectWithUUID: [parent UUID]] contentArray] count] == 2);
	assert([[(id)[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	
	[[ctx2 objectWithUUID: [subchild1 UUID]] setValue: @"Groceries" forProperty: @"label"];
	 
	// ctx3: move subchild1 to child3, insert child4
	[(id)[ctx3 objectWithUUID: [child3 UUID]] addObject: [ctx3 objectWithUUID: [subchild1 UUID]]];
	COContainer *child4Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	[(id)[ctx3 objectWithUUID: [parent UUID]] insertObject: child4Ctx3 atIndex: 0];
	assert([[(id)[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	
	// Now do the merge
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts

	// Apply the resulting diff to ctx1
	UKFalse([ctx1 hasChanges]);
	assert([[(id)[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	[merged applyToContext: ctx1];
	UKStringsEqual(@"Groceries", [subchild1 valueForProperty: @"label"]);
	UKObjectsSame(child3, [subchild1 valueForProperty: @"parentContainer"]);
	UKIntsEqual(3, [[parent contentArray] count]);
	COContainer *child4 = (id)[ctx1 objectWithUUID: [child4Ctx3 UUID]];
	if (3 == [[parent contentArray] count])
	{
		UKObjectsSame(child4, [[parent contentArray] objectAtIndex: 0]);
		UKObjectsSame(child1, [[parent contentArray] objectAtIndex: 1]);
		UKObjectsSame(child3, [[parent contentArray] objectAtIndex: 2]);
	}
	
	[ctx3 release];
	[ctx2 release];
	TearDownContext(ctx1);
	CLOSE_STORE(store);
}

//
// Move/Delete tests: (merging two diffs, where one diff moves an object and the other deletes it)
//

- (void)testMoveAndDeleteOnOneToManyRelationship
{
	// Expected result: the delete wins, with no conflicts
	OPEN_STORE(store);
	COEditingContext *ctx1 = NewContext(store);
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent addObject: child1];
	[parent addObject: child2];
	
	[ctx1 commit];
	
	// ctx1:
	//
	// parent
	//  |
	//  |--child1
	//  |
	//   \-child2
		
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];
	
	// ctx2: remove child1
	[(id)[ctx2 objectWithUUID: [parent UUID]] removeObject: [ctx2 objectWithUUID: [child1 UUID]]];
	
	// ctx2:
	//
	// parent
	//  |
	//   \-child2
		
	// ctx3: put child1 inside  child2, and add a new child3 inside child2
	COContainer *child3Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] addObject: [ctx3 objectWithUUID: [child1 UUID]]];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] addObject: child3Ctx3];
	
	// ctx3:
	//
	// parent
	//  |
	//   \-child2
	//       |
	//       |-child1
	//       |
	//       \-child3
	
	
	// Now do the merge
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts
	
	// Apply the resulting diff to ctx1
	UKFalse([ctx1 hasChanges]);
	[merged applyToContext: ctx1];

	// FIXME: Check that there were no conflicts
	
	// Expected result:
	//
	// parent
	//  |
	//   \-child2
	//       |
	//       \-child3
	
	COContainer *child3 = (id)[ctx1 objectWithUUID: [child3Ctx3 UUID]];

	UKIntsEqual(1, [[parent contentArray] count]);
	if ([[parent contentArray] count] == 1)
	{
		UKObjectsSame(child2, [[parent contentArray] firstObject]);
		UKObjectsSame(parent, [child2 valueForProperty: @"parentContainer"]);
	}
	// FIXME: UKIntsEqual(1, [[child2 contentArray] count]);
	if ([[child2 contentArray] count] == 1)
	{
		UKObjectsSame(child3, [[child2 contentArray] firstObject]);
		UKObjectsSame(child2, [child3 valueForProperty: @"parentContainer"]);
	}
	
	[ctx3 release];
	[ctx2 release];
	TearDownContext(ctx1);
	CLOSE_STORE(store);
}

- (void)testMoveAndDeleteOnManyToManyRelationship
{
	// Expected: both succeed
	OPEN_STORE(store);
	COEditingContext *ctx1 = NewContext(store);
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COGroup *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COGroup *tag2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COContainer *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[tag1 addObject: child];
	
	[ctx1 commit];
	
	// ctx1:
	//
	// tag1         tag2
	//  |
	//   \--child
	
	COGroup *tag1Ctx2 = [ctx2 insertObject: tag1];
	COGroup *tag2Ctx2 = [ctx2 insertObject: tag2];
	COGroup *childCtx2 = [ctx2 insertObject: child];
	
	COGroup *tag1Ctx3 = [ctx3 insertObject: tag1];
	COGroup *tag2Ctx3 = [ctx3 insertObject: tag2];
	COGroup *childCtx3 = [ctx3 insertObject: child];	
	
	// ctx2: move child to tag2
	UKTrue([[tag1Ctx2 contentArray] containsObject: childCtx2]);
	[tag1Ctx2 removeObject: childCtx2];
	[tag2Ctx2 addObject: childCtx2];
	
	// ctx2:
	//
	// tag1         tag2
	//               |
	//                \--child
	
	// ctx3: delete child from tag1
	UKTrue([[tag1Ctx3 contentArray] containsObject: childCtx3]);
	[tag1Ctx3 removeObject: childCtx3];
	
	// ctx3:
	//
	// tag1         tag2
	//               
	// child
	
	
	// Now do the merge
	NSArray *uuids = (id)[[A(tag1, tag2, child) mappedCollection] UUID];
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx2];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx3];
	UKNotNil(diff1vs3);
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts
	
	// Apply the resulting diff to ctx1
	[merged applyToContext: ctx1];
	
	// Expected result:
	//
	// tag1         tag2
	//               |
	//                \--child
	
	// FIXME: UKIntsEqual(0, [[tag1 contentArray] count]);
	UKIntsEqual(1, [[tag2 contentArray] count]);
	// FIXME: UKObjectsEqual(S(tag2), [child valueForProperty: @"parentCollections"]);
	
	[ctx3 release];
	[ctx2 release];
	TearDownContext(ctx1);
	CLOSE_STORE(store);
}

//
// Insert/Insert tests: (merging two diffs, where both diffs insert the same object, possibly in different places)
//


- (void)testConflictingInsertInsertOnOneToManyRelationship
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent addObject: child1];
	[parent addObject: child2];
	
	// ctx1:
	//
	// parent
	//  |
	//  |\-child1
	//  | 
	//   \-child2
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];
	
	// ctx2: insert subchild1 in child1
	COContainer *subchild1Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx2 objectWithUUID: [child1 UUID]] addObject: subchild1Ctx2];
	UKObjectsSame([ctx2 objectWithUUID: [child1 UUID]], [subchild1Ctx2 valueForProperty: @"parentContainer"]);
	UKIntsEqual(1, [[(id)[ctx2 objectWithUUID: [child1 UUID]] contentArray] count]);
	UKIntsEqual(0, [[(id)[ctx2 objectWithUUID: [child2 UUID]] contentArray] count]);				
	
	// ctx2:
	//
	// parent
	//  | 
	//  |\-child1
	//  |   |
	//  |   \-subchild1	
	//  | 
	//   \-child2
	
	
	// ctx3: insert subchild1 in child2
	[ctx3 insertObject: subchild1Ctx2];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] addObject: [ctx3 objectWithUUID: [subchild1Ctx2 UUID]]];
	UKObjectsSame([ctx3 objectWithUUID: [child2 UUID]], [[ctx3 objectWithUUID: [subchild1Ctx2 UUID]] valueForProperty: @"parentContainer"]);
	UKIntsEqual(0, [[(id)[ctx3 objectWithUUID: [child1 UUID]] contentArray] count]);
	UKIntsEqual(1, [[(id)[ctx3 objectWithUUID: [child2 UUID]] contentArray] count]);				
	
	// ctx3:
	//
	// parent
	//  |
	//  |\-child1
	//  | 
	//   \-child2
	//      |
	//      \-subchild1
	
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that the changes are conflicting
	
	[ctx3 release];
	[ctx2 release];
	[ctx1 release];		
}

- (void)testNonconflictingInsertInsertOnOneToManyRelationship
{
	// Expected: both succeed
	
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent addObject: child1];
	
	// ctx1:
	//
	// parent
	//  |
	//   \-child1
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];
	
	// ctx2: insert subchild1 in child1
	COContainer *subchild1Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx2 objectWithUUID: [child1 UUID]] addObject: subchild1Ctx2];
	UKObjectsSame([ctx2 objectWithUUID: [child1 UUID]], [subchild1Ctx2 valueForProperty: @"parentContainer"]);
	UKIntsEqual(1, [[(id)[ctx2 objectWithUUID: [child1 UUID]] contentArray] count]);
	
	// ctx2:
	//
	// parent
	//  | 
	//   \-child1
	//      |
	//      \-subchild1	
	
	
	// ctx3: insert subchild1 in child1
	[ctx3 insertObject: subchild1Ctx2];
	[(id)[ctx3 objectWithUUID: [child1 UUID]] addObject: [ctx3 objectWithUUID: [subchild1Ctx2 UUID]]];
	UKObjectsSame([ctx3 objectWithUUID: [child1 UUID]], [[ctx3 objectWithUUID: [subchild1Ctx2 UUID]] valueForProperty: @"parentContainer"]);
	// FIXME: UKIntsEqual(1, [[(id)[ctx3 objectWithUUID: [child1 UUID]] contentArray] count]);				
	
	// ctx3:
	//
	// parent
	//  | 
	//   \-child1
	//      |
	//      \-subchild1	
	
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that the changes are nonconflicting
	
	COContainer *subchild1 = (id)[ctx1 objectWithUUID: [subchild1Ctx2 UUID]];
	// FIXME: UKObjectsSame(child1, [subchild1 valueForProperty: @"parentContainer"]);
	// UKIntsEqual(1, [[child1 contentArray] count]);
	UKObjectsEqual(A(subchild1), [child1 contentArray]);
	
	[ctx3 release];
	[ctx2 release];
	[ctx1 release];		
}

- (void)testInsertInsertOnManyToManyRelationship
{
	// Expected: both succeed
	
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COGroup *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COGroup *tag2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];

	
	// ctx1:
	//
	// tag1         tag2
	
	COContainer *childCtx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *tag1Ctx2 = [ctx2 insertObject: tag1];
	COGroup *tag2Ctx2 = [ctx2 insertObject: tag2];

	COContainer *childCtx3 = [ctx3 insertObject: childCtx2];
	COGroup *tag1Ctx3 = [ctx3 insertObject: tag1];
	COGroup *tag2Ctx3 = [ctx3 insertObject: tag2];


	// ctx2: add child to tag1	
	[tag1Ctx2 addObject: childCtx2];	
	UKObjectsEqual(S(childCtx2), [tag1Ctx2 content]);
	UKObjectsEqual([NSSet set], [tag2Ctx2 content]);
	
	// ctx2:
	//
	// tag1         tag2
	//  |
	//   \--child
	
	
	
	// ctx3: add child to tag2
	[tag2Ctx3 addObject: childCtx3];
	UKObjectsEqual([NSSet set], [tag1Ctx3 content]);
	UKObjectsEqual(S(childCtx3), [tag2Ctx3 content]);
	
	// ctx3:
	//
	// tag1         tag2
	//               |
	//                \--child
	
	// Now do the merge
	NSArray *uuids = (id)[[A(tag1, tag2, childCtx2) mappedCollection] UUID];
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx2];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx3];
	UKNotNil(diff1vs3);
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts
	
	// Apply the resulting diff to ctx1
	[merged applyToContext: ctx1];
	
	// Expected result:
	//
	// tag1         tag2
	//  |            |
	//   \--child    \--child
	
	
	COContainer *child = (id)[ctx1 objectWithUUID: [childCtx2 UUID]];
	UKIntsEqual(1, [[tag1 contentArray] count]);
	UKIntsEqual(1, [[tag2 contentArray] count]);
	// FIXME: UKObjectsEqual(S(tag1, tag2), [child valueForProperty: @"parentCollections"]);
	UKObjectsEqual(A(child), [tag1 contentArray]);
	UKObjectsEqual(A(child), [tag2 contentArray]);
	UKObjectsEqual(S(child), [tag1 content]);
	UKObjectsEqual(S(child), [tag2 content]);
	
	[ctx3 release];
	[ctx2 release];
	[ctx1 release];
}


//
// Move/Move tests: (merging two diffs, where both diffs move the same objects)
//


- (void)testConflictingMoveAndMoveOnOneToManyRelationship
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[child1 addObject: subchild1];
	[parent addObject: child1];
	[parent addObject: child2];
	[parent addObject: child3];

	// ctx1:
	//
	// parent
	//  |
	//  |\-child1
	//  |   |
	//  |   \-subchild1	
	//  | 
	//  |\-child2
	//  | 
	//   \-child3
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];

	// ctx2: move subchild1 to child2
	[(id)[ctx2 objectWithUUID: [child2 UUID]] addObject: [ctx2 objectWithUUID: [subchild1 UUID]]];

	// ctx2:
	//
	// parent
	//  |
	//  |\-child1
	//  | 
	//  |\-child2
	//  |   |
	//  |   \-subchild1	
	//  | 
	//   \-child3
	
	
	// ctx3: move subchild1 to child3
	[(id)[ctx3 objectWithUUID: [child3 UUID]] addObject: [ctx3 objectWithUUID: [subchild1 UUID]]];
	
	// ctx3:
	//
	// parent
	//  |
	//  |\-child1
	//  | 
	//  |\-child2
	//  | 
	//   \-child3
	//      |
	//      \-subchild1
	
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that the changes are conflicting
	
	[ctx3 release];
	[ctx2 release];
	[ctx1 release];		
}

- (void)testNonconflictingMoveAndMoveOnOneToManyRelationship
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[child1 addObject: subchild1];
	[parent addObject: child1];
	[parent addObject: child2];
	
	// ctx1:
	//
	// parent
	//  |
	//  |\-child1
	//  |    |
	//  |    \-subchild1
	//  | 
	//   \-child2
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];
	
	// ctx2: move subchild1 to child2
	[(id)[ctx2 objectWithUUID: [child2 UUID]] addObject: [ctx2 objectWithUUID: [subchild1 UUID]]];

	// ctx2:
	//
	// parent
	//  |
	//  |\-child1
	//  | 
	//   \-child2
	//      |
	//      \-subchild1
	
	// ctx3: move subchild1 to child2
	[(id)[ctx3 objectWithUUID: [child2 UUID]] addObject: [ctx3 objectWithUUID: [subchild1 UUID]]];
	
	// ctx3:
	//
	// parent
	//  |
	//  |\-child1
	//  | 
	//   \-child2
	//      |
	//      \-subchild1
	
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that the changes are nonconflicting
	
	UKIntsEqual(2, [[parent contentArray] count]);
	// FIXME: UKIntsEqual(0, [[child1 contentArray] count]);
	// UKIntsEqual(1, [[child2 contentArray] count]);
	// UKObjectsEqual(child2, [subchild1 valueForProperty: @"parentContainer"]);
	UKObjectsEqual(A(child1, child2), [parent contentArray]);
	// FIXME: UKObjectsEqual(A(subchild1), [child2 contentArray]);
	
	[ctx3 release];
	[ctx2 release];
	[ctx1 release];		
}

- (void)testMoveAndMoveOnManyToManyRelationship
{
	// Expected: both succeed
	
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COGroup *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COGroup *tag2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COGroup *tag3 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COContainer *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[tag1 addObject: child];
	
	// ctx1:
	//
	// tag1         tag2          tag3
	//  |
	//   \--child
	
	COGroup *tag1Ctx2 = [ctx2 insertObject: tag1];
	COGroup *tag2Ctx2 = [ctx2 insertObject: tag2];
	COGroup *tag3Ctx2 = [ctx2 insertObject: tag3];
	COGroup *childCtx2 = [ctx2 insertObject: child];
	
	COGroup *tag1Ctx3 = [ctx3 insertObject: tag1];
	COGroup *tag2Ctx3 = [ctx3 insertObject: tag2];
	COGroup *tag3Ctx3 = [ctx3 insertObject: tag3];
	COGroup *childCtx3 = [ctx3 insertObject: child];	
	
	// ctx2: move child to tag2
	UKTrue([[tag1Ctx2 contentArray] containsObject: childCtx2]);
	[tag1Ctx2 removeObject: childCtx2];
	[tag2Ctx2 addObject: childCtx2];
	
	// ctx2:
	//
	// tag1         tag2          tag3
	//               |
	//                \--child
	
	// ctx3: move child to tag3
	UKTrue([[tag1Ctx3 contentArray] containsObject: childCtx3]);
	[tag1Ctx3 removeObject: childCtx3];
	[tag3Ctx3 addObject: childCtx3];
	
	// ctx3:
	//
	// tag1         tag2          tag3
	//                             |
	//                              \--child
	
	// Now do the merge
	NSArray *uuids = (id)[[A(tag1, tag2, tag3, child) mappedCollection] UUID];
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx2];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx3];
	UKNotNil(diff1vs3);
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts
	
	// Apply the resulting diff to ctx1
	[merged applyToContext: ctx1];
	
	// Expected result:
	//
	// tag1         tag2          tag3
	//               |             |
	//                \--child      \--child
	
	// FIXME: UKIntsEqual(0, [[tag1 contentArray] count]);
	UKIntsEqual(1, [[tag2 contentArray] count]);
	UKIntsEqual(1, [[tag3 contentArray] count]);
	// FIXME: UKObjectsEqual(S(tag2, tag3), [child valueForProperty: @"parentCollections"]);
	UKObjectsEqual(A(child), [tag2 contentArray]);
	UKObjectsEqual(A(child), [tag3 contentArray]);
	
	[ctx3 release];
	[ctx2 release];
	[ctx1 release];
}

@end
