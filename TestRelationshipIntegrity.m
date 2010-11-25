#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"

@interface TestRelationshipIntegrity : NSObject <UKTest>
{
}
@end

@implementation TestRelationshipIntegrity


- (void)testBasicRelationshipIntegrity
{
	COStore *store = [[COStore alloc] initWithURL: STORE_URL];
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
	
	// Test one-to-many relationships
	
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"]; // See COObject.m for metamodel definition
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"];
	COObject *o3 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"];
	
	[o2 setValue: o1 forProperty: @"parentGroup"]; // should add o2 to o1's contents
	[o2 setValue: A(o3) forProperty: @"contents"]; // should set parentGroup of o3

	UKNil([o1 valueForProperty: @"parentGroup"]);
	UKObjectsEqual(A(o2), [o1 valueForProperty: @"contents"]);
	UKObjectsEqual(o1, [o2 valueForProperty: @"parentGroup"]);
	UKObjectsEqual(A(o3), [o2 valueForProperty: @"contents"]);
	UKObjectsEqual(o2, [o3 valueForProperty: @"parentGroup"]);
	UKObjectsEqual([NSArray array], [o3 valueForProperty: @"contents"]);
	
	
	// Test many-to-many relationships
	
	COObject *t1 = [ctx insertObjectWithEntityName: @"Anonymous.COCollection"]; // See COObject.m for metamodel definition
	COObject *t2 = [ctx insertObjectWithEntityName: @"Anonymous.COCollection"];
	COObject *t3 = [ctx insertObjectWithEntityName: @"Anonymous.COCollection"];
	
	[t1 addObject: o1 forProperty: @"contents"];
	[t2 addObject: o1 forProperty: @"contents"];
	
	UKObjectsEqual(S(t1, t2), [o1 valueForProperty: @"parentCollections"]);
	
	[o2 addObject: t2 forProperty: @"parentCollections"];
	[o2 addObject: t3 forProperty: @"parentCollections"];
	
	UKObjectsEqual(S(o1), [t1 valueForProperty: @"contents"]);
	UKObjectsEqual(S(o1, o2), [t2 valueForProperty: @"contents"]);
	UKObjectsEqual(S(o2), [t3 valueForProperty: @"contents"]);
	
	[ctx release];
	[store release];
	DELETE_STORE;
}

- (void)testRelationshipIntegrityForMove
{
	COStore *store = [[COStore alloc] initWithURL: STORE_URL];
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
	
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"]; // See COObject.m for metamodel definition
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"];
	COObject *o3 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"];
	
	[o2 setValue: o1 forProperty: @"parentGroup"]; // should add o2 to o1's contents
	UKObjectsEqual(A(o2), [o1 valueForProperty: @"contents"]);
	UKObjectsEqual([NSArray array], [o3 valueForProperty: @"contents"]);
	[o2 setValue: o3 forProperty: @"parentGroup"]; // should add o2 to o3's contents, and remove o2 from o1
	UKObjectsEqual([NSArray array], [o1 valueForProperty: @"contents"]);
	UKObjectsEqual(A(o2), [o3 valueForProperty: @"contents"]);	

	// Check that removing an object from a group nullifys that object's parent group pointer
	
	[o3 removeObject: o2 forProperty: @"contents"];
	UKNil([o2 valueForProperty: @"parentGroup"]);
	
	[ctx release];
	[store release];
	DELETE_STORE;
}

- (void)testRelationshipIntegrityMarksDamage
{
	COStore *store = [[COStore alloc] initWithURL: STORE_URL];
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
	
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"]; // See COObject.m for metamodel definition
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"];
	COObject *o3 = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"];
	[ctx commit];
	
	UKFalse([ctx objectHasChanges: [o1 UUID]]);
	UKFalse([ctx objectHasChanges: [o2 UUID]]);
	UKFalse([ctx objectHasChanges: [o3 UUID]]);
			 
	[o2 setValue: o1 forProperty: @"parentGroup"]; // should add o2 to o1's contents
	UKTrue([ctx objectHasChanges: [o1 UUID]]);
	UKTrue([ctx objectHasChanges: [o2 UUID]]);
	UKFalse([ctx objectHasChanges: [o3 UUID]]);
	
	[ctx commit];
	UKFalse([ctx objectHasChanges: [o1 UUID]]);
	UKFalse([ctx objectHasChanges: [o2 UUID]]);
	UKFalse([ctx objectHasChanges: [o3 UUID]]);
	
	[o2 setValue: o3 forProperty: @"parentGroup"]; // should add o2 to o3's contents, and remove o2 from o1
	UKTrue([ctx objectHasChanges: [o1 UUID]]);
	UKTrue([ctx objectHasChanges: [o2 UUID]]);
	UKTrue([ctx objectHasChanges: [o3 UUID]]);
	
	[ctx commit];
	
	[o3 removeObject: o2 forProperty: @"contents"]; // should make o2's parentGroup nil
	UKFalse([ctx objectHasChanges: [o1 UUID]]);
	UKTrue([ctx objectHasChanges: [o2 UUID]]);
	UKTrue([ctx objectHasChanges: [o3 UUID]]);	

	[ctx release];
	[store release];
	DELETE_STORE;
}

@end
