#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestItemGraphDiff : NSObject <UKTest>
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

@end
