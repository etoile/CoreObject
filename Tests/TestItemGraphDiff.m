#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestItemGraphDiff : TestCommon <UKTest>
@end

@implementation TestItemGraphDiff

- (void)testBasic
{
	COObjectGraphContext *ctx1 = [[COObjectGraphContext alloc] init];
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
	
	COObject *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [ctx1 setRootObject: parent];
	COObject *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *subchild2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *subchild3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild1 setValue: @"Pizza" forProperty: @"label"];
	[subchild2 setValue: @"Salad" forProperty: @"label"];
	[subchild3 setValue: @"Chips" forProperty: @"label"];
	[child insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[child insertObject: subchild2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[child insertObject: subchild3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
    // Copy the items to ctx2
    [ctx2 setItemGraph: ctx1];
    [ctx2 setRootObject: [ctx2 objectWithUUID: [parent UUID]]];
    
	COObject *parentCtx2 = [ctx2 rootObject];
	COObject *childCtx2 = [ctx2 objectWithUUID: [child UUID]];
	COObject *subchild1Ctx2 = [ctx2 objectWithUUID: [subchild1 UUID]];
	COObject *subchild2Ctx2 = [ctx2 objectWithUUID: [subchild2 UUID]];
	COObject *subchild3Ctx2 = [ctx2 objectWithUUID: [subchild3 UUID]];

	UKObjectsEqual([parent UUID], [parentCtx2 UUID]);
	UKObjectsEqual([child UUID], [childCtx2 UUID]);
	UKObjectsEqual([subchild1 UUID], [subchild1Ctx2 UUID]);
	UKObjectsEqual([subchild2 UUID], [subchild2Ctx2 UUID]);
	UKObjectsEqual([subchild3 UUID], [subchild3Ctx2 UUID]);
	
	// Now make some modifications to ctx2: 
	
	[childCtx2 removeObject: subchild2Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty:@"contents"]; // Remove "Salad"
	COObject *subchild4Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	ETUUID *subchild4UUID = [subchild4Ctx2 UUID];
	[subchild4Ctx2 setValue: @"Salsa" forProperty: @"label"];
	[childCtx2 insertObject: subchild4Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"]; // Add "Salsa"
	[childCtx2 setValue: @"Snacks" forProperty: @"label"];
	
	// Now create a diff
	COItemGraphDiff *diff = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"exampleDiff"];
    UKNotNil(diff);
	
	// Apply it to ctx1.
	
	[diff applyTo: ctx1];
	
	// Now check that all of the changes were properly made.
	
	UKStringsEqual(@"Snacks", [child valueForProperty: @"label"]);
    COObject *subchild4 = [[child valueForProperty: @"contents"] objectAtIndex: 2];
    
	UKObjectsSame(subchild1, [[child valueForProperty: @"contents"] objectAtIndex: 0]);
    UKObjectsSame(subchild3, [[child valueForProperty: @"contents"] objectAtIndex: 1]);
    UKObjectsSame(subchild4, [[child valueForProperty: @"contents"] objectAtIndex: 2]);
    
	UKObjectsEqual(A(@"Pizza", @"Chips", @"Salsa"), [child valueForKeyPath: @"contents.label"]);
	UKObjectsEqual(subchild4UUID, [subchild4 UUID]);
	[ctx2 release];
	[ctx1 release];
}

- (void)testMove
{
	COObjectGraphContext *ctx1 = [[COObjectGraphContext alloc] init];
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
	
	COObject *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [ctx1 setRootObject: parent];
	COObject *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child1 setValue: @"Groceries" forProperty: @"label"];
	[child2 setValue: @"Todo" forProperty: @"label"];
	[subchild1 setValue: @"Salad" forProperty: @"label"];
	[child1 insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
    // Copy the items to ctx2
    [ctx2 setItemGraph: ctx1];
    [ctx2 setRootObject: [ctx2 objectWithUUID: [parent UUID]]];
    
    COObject *parentCtx2 = [ctx2 rootObject];
    UKNotNil(parentCtx2);
	COObject *child1Ctx2 = [ctx2 objectWithUUID: [child1 UUID]];
	COObject *child2Ctx2 = [ctx2 objectWithUUID: [child2 UUID]];
	COObject *subchild1Ctx2 = [ctx2 objectWithUUID: [subchild1 UUID]];
	
	// Now make some modifications to ctx2: (move "Salad" from "Groceries" to "Todo")
	
	[child1Ctx2 removeObject: subchild1Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[child2Ctx2 insertObject: subchild1Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// Now create a diff
	COItemGraphDiff *diff = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"exampleDiff"];
    UKNotNil(diff);
	
	// Apply it to ctx1.
	
	[diff applyTo: ctx1];
	
	// Now check that all of the changes were properly made.
	
	UKIntsEqual(0, [[child1 valueForProperty: @"contents"] count]);
	UKIntsEqual(1, [[child2 valueForProperty: @"contents"] count]);
	UKObjectsSame(subchild1, [[child2 valueForProperty: @"contents"] objectAtIndex: 0]);
	
	[ctx2 release];
	[ctx1 release];
}

- (void)testSimpleNonconflictingMerge
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext objectGraphContext];
	COObjectGraphContext *ctx2 = [COObjectGraphContext objectGraphContext];
    COObjectGraphContext *ctx3 = [COObjectGraphContext objectGraphContext];
    
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[ctx1 setRootObject: parent];
    
	[child1 insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
    // Copy into ctx2 and ctx3
    
    [ctx2 setItemGraph: ctx1];
    [ctx3 setItemGraph: ctx1];
    
	// ctx2: remove child2, set a label for subchild1
    [[ctx2 objectWithUUID: [parent UUID]] removeObject: [ctx2 objectWithUUID: [child2 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];	
	[[ctx2 objectWithUUID: [subchild1 UUID]] setValue: @"Groceries" forProperty: @"label"];
	 
	// ctx3: move subchild1 to child3, insert child4
	[(id)[ctx3 objectWithUUID: [child3 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	OutlineItem *child4Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	[(id)[ctx3 objectWithUUID: [parent UUID]] insertObject: child4Ctx3 atIndex: 0];
	assert([[(id)[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	
	// Now do the merge
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];

    UKFalse([merged hasConflicts]);

    [merged applyTo: ctx1];
    
	UKStringsEqual(@"Groceries", [subchild1 valueForProperty: @"label"]);
    UKObjectsEqual(@[subchild1], [child3 contents]);
	UKObjectsSame(child3, [subchild1 valueForProperty: @"parentContainer"]);
	UKIntsEqual(3, [[parent contentArray] count]);
	OutlineItem *child4 = (id)[ctx1 objectWithUUID: [child4Ctx3 UUID]];
    UKObjectsSame(child4, [[parent contentArray] objectAtIndex: 0]);
    UKObjectsSame(child1, [[parent contentArray] objectAtIndex: 1]);
    UKObjectsSame(child3, [[parent contentArray] objectAtIndex: 2]);
}

#if 0
//
// Move/Delete tests: (merging two diffs, where one diff moves an object and the other deletes it)
//

- (void)testMoveAndDeleteOnOneToManyRelationship
{
	// Expected result: the delete wins, with no conflicts
	COEditingContext *ctx1 = ctx;
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
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
	OutlineItem *child3Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: [ctx3 objectWithUUID: [child1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: child3Ctx3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
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
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	COItemGraphDiff *merged = [COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
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
	
	OutlineItem *child3 = (id)[ctx1 objectWithUUID: [child3Ctx3 UUID]];

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
}

- (void)testMoveAndDeleteOnManyToManyRelationship
{
	// Expected: both succeed
	COEditingContext *ctx1 = ctx;
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COGroup *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COGroup *tag2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	OutlineItem *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[tag1 insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
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
	//COGroup *tag2Ctx3 = [ctx3 insertObject: tag2];
	COGroup *childCtx3 = [ctx3 insertObject: child];	
	
	// ctx2: move child to tag2
	UKTrue([[tag1Ctx2 contentArray] containsObject: childCtx2]);
	[tag1Ctx2 removeObject: childCtx2];
	[tag2Ctx2 insertObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
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
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx2];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx3];
	UKNotNil(diff1vs3);
	COItemGraphDiff *merged = [COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
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
}

//
// Insert/Insert tests: (merging two diffs, where both diffs insert the same object, possibly in different places)
//


- (void)testConflictingInsertInsertOnOneToManyRelationship
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
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
	OutlineItem *subchild1Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx2 objectWithUUID: [child1 UUID]] insertObject: subchild1Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
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
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1Ctx2 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
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
	
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
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
	
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// parent
	//  |
	//   \-child1
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];
	
	// ctx2: insert subchild1 in child1
	OutlineItem *subchild1Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx2 objectWithUUID: [child1 UUID]] insertObject: subchild1Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
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
	[(id)[ctx3 objectWithUUID: [child1 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1Ctx2 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	UKObjectsSame([ctx3 objectWithUUID: [child1 UUID]], [[ctx3 objectWithUUID: [subchild1Ctx2 UUID]] valueForProperty: @"parentContainer"]);
	// FIXME: UKIntsEqual(1, [[(id)[ctx3 objectWithUUID: [child1 UUID]] contentArray] count]);				
	
	// ctx3:
	//
	// parent
	//  | 
	//   \-child1
	//      |
	//      \-subchild1	
	
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that the changes are nonconflicting
	
	OutlineItem *subchild1 = (id)[ctx1 objectWithUUID: [subchild1Ctx2 UUID]];
	// FIXME: UKObjectsSame(child1, [subchild1 valueForProperty: @"parentContainer"]);
	// UKIntsEqual(1, [[child1 contentArray] count]);
	//UKObjectsEqual(A(subchild1), [child1 contentArray]);
	
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
	
	OutlineItem *childCtx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *tag1Ctx2 = [ctx2 insertObject: tag1];
	COGroup *tag2Ctx2 = [ctx2 insertObject: tag2];

	OutlineItem *childCtx3 = [ctx3 insertObject: childCtx2];
	COGroup *tag1Ctx3 = [ctx3 insertObject: tag1];
	COGroup *tag2Ctx3 = [ctx3 insertObject: tag2];


	// ctx2: add child to tag1	
	[tag1Ctx2 insertObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];	
	UKObjectsEqual(S(childCtx2), [tag1Ctx2 content]);
	UKObjectsEqual([NSSet set], [tag2Ctx2 content]);
	
	// ctx2:
	//
	// tag1         tag2
	//  |
	//   \--child
	
	
	
	// ctx3: add child to tag2
	[tag2Ctx3 insertObject: childCtx3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	UKObjectsEqual([NSSet set], [tag1Ctx3 content]);
	UKObjectsEqual(S(childCtx3), [tag2Ctx3 content]);
	
	// ctx3:
	//
	// tag1         tag2
	//               |
	//                \--child
	
	// Now do the merge
	NSArray *uuids = (id)[[A(tag1, tag2, childCtx2) mappedCollection] UUID];
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx2];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx3];
	UKNotNil(diff1vs3);
	COItemGraphDiff *merged = [COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts
	
	// Apply the resulting diff to ctx1
	[merged applyToContext: ctx1];
	
	// Expected result:
	//
	// tag1         tag2
	//  |            |
	//   \--child    \--child
	
	
	OutlineItem *child = (id)[ctx1 objectWithUUID: [childCtx2 UUID]];
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
	
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[child1 insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

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
	[(id)[ctx2 objectWithUUID: [child2 UUID]] insertObject: [ctx2 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

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
	[(id)[ctx3 objectWithUUID: [child3 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
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
	
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
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
	
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[child1 insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
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
	[(id)[ctx2 objectWithUUID: [child2 UUID]] insertObject: [ctx2 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

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
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// parent
	//  |
	//  |\-child1
	//  | 
	//   \-child2
	//      |
	//      \-subchild1
	
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffContainer: parent withContainer: (id)[ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
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
	OutlineItem *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[tag1 insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// tag1         tag2          tag3
	//  |
	//   \--child
	
	COGroup *tag1Ctx2 = [ctx2 insertObject: tag1];
	COGroup *tag2Ctx2 = [ctx2 insertObject: tag2];
	//COGroup *tag3Ctx2 = [ctx2 insertObject: tag3];
	COGroup *childCtx2 = [ctx2 insertObject: child];
	
	COGroup *tag1Ctx3 = [ctx3 insertObject: tag1];
	//COGroup *tag2Ctx3 = [ctx3 insertObject: tag2];
	COGroup *tag3Ctx3 = [ctx3 insertObject: tag3];
	COGroup *childCtx3 = [ctx3 insertObject: child];	
	
	// ctx2: move child to tag2
	UKTrue([[tag1Ctx2 contentArray] containsObject: childCtx2]);
	[tag1Ctx2 removeObject: childCtx2];
	[tag2Ctx2 insertObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx2:
	//
	// tag1         tag2          tag3
	//               |
	//                \--child
	
	// ctx3: move child to tag3
	UKTrue([[tag1Ctx3 contentArray] containsObject: childCtx3]);
	[tag1Ctx3 removeObject: childCtx3];
	[tag3Ctx3 insertObject: childCtx3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// tag1         tag2          tag3
	//                             |
	//                              \--child
	
	// Now do the merge
	NSArray *uuids = (id)[[A(tag1, tag2, tag3, child) mappedCollection] UUID];
	COItemGraphDiff *diff1vs2 = [COItemGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx2];
	UKNotNil(diff1vs2);
	COItemGraphDiff *diff1vs3 = [COItemGraphDiff diffObjectsWithUUIDs:uuids  inContext:ctx1 withContext:ctx3];
	UKNotNil(diff1vs3);
	COItemGraphDiff *merged = [COItemGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
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

- (void)testSelectiveUndoOfGroupOperation
{
	COEditingContext *ctx1 = ctx;
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	OutlineItem *doc = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *line1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *circle1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *square1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *image1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	[line1 setValue: @"line1" forProperty: @"label"];	
	[circle1 setValue: @"circle1" forProperty: @"label"];
	[square1 setValue: @"square1" forProperty: @"label"];	
	[image1 setValue: @"image1" forProperty: @"label"];
	
	[doc insertObject: line1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[doc insertObject: circle1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[doc insertObject: square1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[doc insertObject: image1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	[ctx1 commit];
	
	// snapshot the state: (line1, circle1, square1, image1) into ctx2
	[ctx2 insertObject: doc];
	
	OutlineItem *group1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[group1 setValue: @"group1" forProperty: @"label"];
	[doc insertObject: group1 atIndex: 1];
	[group1 insertObject: circle1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[group1 insertObject: square1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[ctx1 commit];
	
	// snapshot the state:  (line1, group1=(circle1, square1), image1) into ctx3
	[ctx3 insertObject: doc];
	
	OutlineItem *triangle1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[triangle1 setValue: @"triangle1" forProperty: @"label"];
	[doc insertObject: triangle1 atIndex: 0];
	[ctx1 commit];
	
	
	// ctx1 state:  (triangl1, line1, group1=(circle1, square1), image1)
	
	
	// Now do the merge
	
	COItemGraphDiff *diff_ctx3_vs_ctx2 = [COItemGraphDiff diffContainer: (id)[ctx3 objectWithUUID: [doc UUID]]
								  withContainer: (id)[ctx2 objectWithUUID: [doc UUID]]];
	UKNotNil(diff_ctx3_vs_ctx2);

	COItemGraphDiff *diff_ctx3_vs_ctx1 = [COItemGraphDiff diffContainer: (id)[ctx3 objectWithUUID: [doc UUID]]
								  withContainer: (id)[ctx1 objectWithUUID: [doc UUID]]];
	UKNotNil(diff_ctx3_vs_ctx2);
	

	COItemGraphDiff *merged = [COItemGraphDiff mergeDiff: diff_ctx3_vs_ctx2
							withDiff: diff_ctx3_vs_ctx1];
	// FIXME: Test that there are no conflicts
	
	
	// Apply the resulting diff to ctx3
	UKFalse([ctx1 hasChanges]);
	[merged applyToContext: ctx3];
	
	UKIntsEqual(5, [[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] count]);
	if (5 == [[doc contentArray] count])
	{
		UKStringsEqual(@"triangle1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 0] valueForProperty: @"label"]);
		UKStringsEqual(@"line1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 1] valueForProperty: @"label"]);
		UKStringsEqual(@"circle1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 2] valueForProperty: @"label"]);
		UKStringsEqual(@"square1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 3] valueForProperty: @"label"]);	
		UKStringsEqual(@"image1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 4] valueForProperty: @"label"]);
	}
	
	for (OutlineItem *object in [(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray])
	{
		UKObjectsSame([ctx3 objectWithUUID: [doc UUID]], [object valueForProperty: @"parentContainer"]);
	}
	
	[ctx3 release];
	[ctx2 release];
}
#endif
@end
