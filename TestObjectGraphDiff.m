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
