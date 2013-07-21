#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "TestCommon.h"
#import "COContainer.h"

@interface TestRelationshipIntegrity : TestCommon <UKTest>
@end

@implementation TestRelationshipIntegrity

- (void)testBasicRelationshipIntegrity
{
	// Test one-to-many relationships
	
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[o1 setValue: A(o2) forProperty: @"contents"];
	[o2 setValue: A(o3) forProperty: @"contents"];

	UKNil([o1 valueForProperty: @"parentContainer"]);
	UKObjectsEqual(o1, [o2 valueForProperty: @"parentContainer"]);
	UKObjectsEqual(o2, [o3 valueForProperty: @"parentContainer"]);
	UKObjectsEqual([NSArray array], [o3 valueForProperty: @"contents"]);

	// Test many-to-many relationships
	
	COObject *t1 = [ctx insertObjectWithEntityName: @"Anonymous.Tag"];
	COObject *t2 = [ctx insertObjectWithEntityName: @"Anonymous.Tag"];
	COObject *t3 = [ctx insertObjectWithEntityName: @"Anonymous.Tag"];
	
	[t1 insertObject: o1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[t2 insertObject: o1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	UKObjectsEqual(S(t1, t2), [o1 valueForProperty: @"parentCollections"]);
	
	[t2 insertObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[t3 insertObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	UKObjectsEqual(S(o1), [t1 valueForProperty: @"contents"]);
	UKObjectsEqual(S(o1, o2), [t2 valueForProperty: @"contents"]);
	UKObjectsEqual(S(o2), [t3 valueForProperty: @"contents"]);
}

- (void)testRelationshipIntegrityForMove
{
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[o1 setValue: A(o2) forProperty: @"contents"];
	[o3 setValue: A(o2) forProperty: @"contents"]; // should add o2 to o3's contents, and remove o2 from o1
	UKObjectsEqual([NSArray array], [o1 valueForProperty: @"contents"]);
	UKObjectsEqual(A(o2), [o3 valueForProperty: @"contents"]);	

	// Check that removing an object from a group nullifys that object's parent group pointer
	
	[o3 removeObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	UKNil([o2 valueForProperty: @"parentContainer"]);
	
	// Now test moving by modifying the multivalued side of the relationship
	
	COContainer *o4 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"]; 
	COContainer *o5 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *o6 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	
	[o5 addObject: o4];
	[o6 addObject: o4]; // Should move o4 from o5 to o6
	UKObjectsEqual([NSArray array], [o5 contentArray]);
	UKObjectsEqual(A(o4), [o6 contentArray]);
	UKObjectsSame(o6, [o4 valueForProperty: @"parentContainer"]);
}

- (void)testRelationshipIntegrityMarksDamage
{
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[ctx commit];
	
	UKFalse([ctx isUpdatedObject: o1]);
	UKFalse([ctx isUpdatedObject: o2]);
	UKFalse([ctx isUpdatedObject: o3]);
			 
	[o1 setValue: A(o2) forProperty: @"contents"];
	UKTrue([ctx isUpdatedObject: o1]);
	UKFalse([ctx isUpdatedObject: o2]);
	UKFalse([ctx isUpdatedObject: o3]);
	
	[ctx commit];
	UKFalse([ctx isUpdatedObject: o1]);
	UKFalse([ctx isUpdatedObject: o2]);
	UKFalse([ctx isUpdatedObject: o3]);
	
	[o3 setValue: A(o2) forProperty: @"contents"]; // should add o2 to o3's contents, and remove o2 from o1
	UKTrue([ctx isUpdatedObject: o1]);
	UKFalse([ctx isUpdatedObject: o2]);
	UKTrue([ctx isUpdatedObject: o3]);
	
	[ctx commit];
	
	[o3 removeObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"]; // should make o2's parentContainer nil
	UKFalse([ctx isUpdatedObject: o1]);
	UKFalse([ctx isUpdatedObject: o2]);
	UKTrue([ctx isUpdatedObject: o3]);	
}

- (void)testShoppingList
{
	COContainer *workspace = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *document1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *group1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *group2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *leaf3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	COContainer *document2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	// Set up the initial state
	[document1 setValue:@"Document 1" forProperty: @"label"];
	[group1 setValue:@"Group 1" forProperty: @"label"];
	[leaf1 setValue:@"Leaf 1" forProperty: @"label"];
	[leaf2 setValue:@"Leaf 2" forProperty: @"label"];
	[group2 setValue:@"Group 2" forProperty: @"label"];
	[leaf3 setValue:@"Leaf 3" forProperty: @"label"];
	[document2 setValue:@"Document 2" forProperty: @"label"];
	
	[workspace addObject: document1];
	[workspace addObject: document2];
	[document1 addObject: group1];
	[group1 addObject: leaf1];
	[group1 addObject: leaf2];	
	[document1 addObject: group2];	
	[group2 addObject: leaf3];
	
	[ctx commit];
	// Now make some changes
	
	[group2 addObject: leaf2]; [ctx commit];
	[document2 addObject: group2]; [ctx commit];

	UKObjectsSame(workspace, [document1 valueForProperty: @"parentContainer"]);
	UKObjectsSame(workspace, [document2 valueForProperty: @"parentContainer"]);	
	UKObjectsSame(document1, [group1 valueForProperty: @"parentContainer"]);	
	UKObjectsSame(document2, [group2 valueForProperty: @"parentContainer"]);	
	UKObjectsSame(group1, [leaf1 valueForProperty: @"parentContainer"]);	
	UKObjectsSame(group2, [leaf2 valueForProperty: @"parentContainer"]);	
	UKObjectsSame(group2, [leaf3 valueForProperty: @"parentContainer"]);	
	UKObjectsEqual(S(document1, document2), [NSSet setWithArray: [workspace contentArray]]);
	UKObjectsEqual(S(group1), [NSSet setWithArray: [document1 contentArray]]);
	UKObjectsEqual(S(group2), [NSSet setWithArray: [document2 contentArray]]);
	UKObjectsEqual(S(leaf1), [NSSet setWithArray: [group1 contentArray]]);
	UKObjectsEqual(S(leaf2, leaf3), [NSSet setWithArray: [group2 contentArray]]);
}

@end
