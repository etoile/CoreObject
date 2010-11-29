#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COHistoryTrack.h"
#import "COContainer.h"
#import "COCollection.h"
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
	COEditingContext *ctx1 = NewContext();
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
	assert([[[ctx2 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	[[ctx2 objectWithUUID: [child2 UUID]] setValue: nil forProperty: @"parentContainer"];
	assert([[[ctx2 objectWithUUID: [parent UUID]] contentArray] count] == 2);
	assert([[[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	
	[[ctx2 objectWithUUID: [subchild1 UUID]] setValue: @"Groceries" forProperty: @"label"];
	 
	// ctx3: move subchild1 to child3, insert child4
	[[ctx3 objectWithUUID: [child3 UUID]] addObject: [ctx3 objectWithUUID: [subchild1 UUID]]];
	COContainer *child4Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	[[ctx3 objectWithUUID: [parent UUID]] insertObject: child4Ctx3 atIndex: 0];
	assert([[[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	
	// Now do the merge
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: [ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: [ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts

	// Apply the resulting diff to ctx1
	UKFalse([ctx1 hasChanges]);
	assert([[[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	[merged applyToContext: ctx1];
	UKStringsEqual(@"Groceries", [subchild1 valueForProperty: @"label"]);
	UKObjectsSame(child3, [subchild1 valueForProperty: @"parentContainer"]);
	UKIntsEqual(3, [[parent contentArray] count]);
	COContainer *child4 = [ctx1 objectWithUUID: [child4Ctx3 UUID]];
	if (3 == [[parent contentArray] count])
	{
		UKObjectsSame(child4, [[parent contentArray] objectAtIndex: 0]);
		UKObjectsSame(child1, [[parent contentArray] objectAtIndex: 1]);
		UKObjectsSame(child3, [[parent contentArray] objectAtIndex: 2]);
	}
	
	[ctx3 release];
	[ctx2 release];
	TearDownContext(ctx1);
}

- (void)testNonconflictingMergeWithMove
{
	COEditingContext *ctx1 = NewContext();
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	COEditingContext *ctx3 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent addObject: child1];
	[parent addObject: child2];
	
	[ctx1 commit];
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];
	
	// ctx2: remove child1
	[[ctx2 objectWithUUID: [parent UUID]] removeObject: [ctx2 objectWithUUID: [child1 UUID]]];
	
	// ctx3: put child1 inside  child2, and add a new child3 inside child2
	COContainer *child3Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[[ctx3 objectWithUUID: [child2 UUID]] addObject: [ctx3 objectWithUUID: [child1 UUID]]];
	[[ctx3 objectWithUUID: [child2 UUID]] addObject: child3Ctx3];
	
	// Now do the merge
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: [ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: [ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that there are no conflicts
	
	// Apply the resulting diff to ctx1
	UKFalse([ctx1 hasChanges]);
	[merged applyToContext: ctx1];

	// Expected result:
	//
	// parent
	//  |
	//   \-child2
	//       |
	//       \-child3
	
	COContainer *child3 = [ctx1 objectWithUUID: [child3Ctx3 UUID]];

	UKIntsEqual(1, [[parent contentArray] count]);
	if ([[parent contentArray] count] == 1)
	{
		UKObjectsSame(child2, [[parent contentArray] firstObject]);
		UKObjectsSame(parent, [child2 valueForProperty: @"parentContainer"]);
	}
	UKIntsEqual(1, [[child2 contentArray] count]);
	if ([[child2 contentArray] count] == 1)
	{
		UKObjectsSame(child3, [[child2 contentArray] firstObject]);
		UKObjectsSame(child2, [child3 valueForProperty: @"parentContainer"]);
	}
	
	[ctx3 release];
	[ctx2 release];
	TearDownContext(ctx1);
}


- (void)testComplexNonconflictingMerge
{
	
}

- (void)testSimpleConflictingMerge
{
	
}

- (void)testComplexConflictingMerge
{
	
}

- (void)testConflictingMovesMerge
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
	
	[ctx2 insertObject: parent];
	[ctx3 insertObject: parent];

	// ctx2: move subchild1 to child2
	[[ctx2 objectWithUUID: [child2 UUID]] addObject: [ctx2 objectWithUUID: [subchild1 UUID]]];
	
	// ctx3: move subchild1 to child3
	[[ctx3 objectWithUUID: [child3 UUID]] addObject: [ctx3 objectWithUUID: [subchild1 UUID]]];
	
	
	COObjectGraphDiff *diff1vs2 = [COObjectGraphDiff diffContainer: parent withContainer: [ctx2 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs2);
	COObjectGraphDiff *diff1vs3 = [COObjectGraphDiff diffContainer: parent withContainer: [ctx3 objectWithUUID: [parent UUID]]];
	UKNotNil(diff1vs3);
	
	[COObjectGraphDiff mergeDiff:diff1vs2 withDiff: diff1vs3];
	// FIXME: Test that the changes are conflicting
	
	[ctx3 release];
	[ctx2 release];
	[ctx1 release];		
}


@end
