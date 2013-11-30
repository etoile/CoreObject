#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

/**
 * Test model object that has an ordered many-to-many relationship to COObject
 */
@interface OrderedGroupNoOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;
@end

/**
 * Test model object that has an ordered many-to-many relationship to OrderedGroupContent
 */
@interface OrderedGroupWithOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;
@end

/**
 * Test model object to be inserted as content in OrderedGroupWithOpposite
 */
@interface OrderedGroupContent : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *parentGroups;
@end

static int OrderedGroupNoOppositeDeallocCalls;

@implementation OrderedGroupNoOpposite

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"OrderedGroupNoOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.COObject"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: YES];
	
	[entity setPropertyDescriptions: @[labelProperty, contentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;

- (void) dealloc
{
	OrderedGroupNoOppositeDeallocCalls++;
}

@end

@implementation OrderedGroupWithOpposite

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"OrderedGroupWithOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.OrderedGroupContent"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: YES];
	[contentsProperty setOpposite: (id)@"Anonymous.OrderedGroupContent.parentGroups"];
	
	[entity setPropertyDescriptions: @[labelProperty, contentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;
@end

@implementation OrderedGroupContent

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"OrderedGroupContent"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *parentGroupsProperty = [ETPropertyDescription descriptionWithName: @"parentGroups"
																						type: (id)@"Anonymous.OrderedGroupWithOpposite"];
    [parentGroupsProperty setMultivalued: YES];
    [parentGroupsProperty setOrdered: NO];
	[parentGroupsProperty setOpposite: (id)@"Anonymous.OrderedGroupWithOpposite.contents"];
	
	[entity setPropertyDescriptions: @[labelProperty, parentGroupsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic parentGroups;
@end


@interface TestOrderedRelationship : NSObject <UKTest>
@end

@implementation TestOrderedRelationship

/**
 * Test that an object graph of OrderedGroupNoOpposite can be reloaded in another
 * context. Test that one OutlineItem can be in two OrderedGroupNoOpposite's.
 */
- (void) testOrderedGroupNoOppositeInnerReference
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	OrderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = @[item1, item2];
	group2.contents = @[item1];
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	OrderedGroupNoOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	OrderedGroupNoOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	OutlineItem *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	OutlineItem *item2ctx2 = [ctx2 loadedObjectForUUID: [item2 UUID]];
	
	UKObjectsEqual((@[item1ctx2, item2ctx2]), [group1ctx2 contents]);
	UKObjectsEqual((@[item1ctx2]), [group2ctx2 contents]);
	
	// Check that the relationship cache knows the inverse relationship, even though it is
	// not used in the metamodel (non-public API)
	UKObjectsEqual(S(group1, group2), [item1 referringObjects]);
	UKObjectsEqual(S(group1), [item2 referringObjects]);
	
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item1ctx2 referringObjects]);
	UKObjectsEqual(S(group1ctx2), [item2ctx2 referringObjects]);
}

- (void) testOrderedGroupNoOppositeOuterReference
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	
	OrderedGroupNoOpposite *group1 = [ctx1 insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	OutlineItem *item1 = [ctx2 insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = @[item1];
	
	// Check that the relationship cache knows the inverse relationship, even though it is
	// not used in the metamodel (non-public API)
	UKObjectsEqual(S(group1), [item1 referringObjects]);
}

- (void) testOrderedGroupWithOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
	OrderedGroupWithOpposite *group2 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
	OrderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
	OrderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
	
	group1.contents = @[item1, item2];
	group2.contents = @[item1];
	
	UKObjectsEqual(S(group1, group2), [item1 parentGroups]);
	UKObjectsEqual(S(group1), [item2 parentGroups]);

	// Make some changes
	
	group2.contents = @[item1, item2];

	UKObjectsEqual(S(group1, group2), [item2 parentGroups]);
	
	group1.contents = @[item2];

	UKObjectsEqual(S(group2), [item1 parentGroups]);
	
	// Reload in another graph
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	OrderedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	OrderedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	OrderedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	OrderedGroupContent *item2ctx2 = [ctx2 loadedObjectForUUID: [item2 UUID]];
	
	UKObjectsEqual((@[item2ctx2]), [group1ctx2 contents]);
	UKObjectsEqual((@[item1ctx2, item2ctx2]), [group2ctx2 contents]);
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item2ctx2 parentGroups]);
	UKObjectsEqual(S(group2ctx2), [item1ctx2 parentGroups]);
	
	// Check the relationship cache
	UKObjectsEqual(S(group2), [item1 referringObjects]);
	UKObjectsEqual(S(group1, group2), [item2 referringObjects]);
	
	UKObjectsEqual(S(group2ctx2), [item1ctx2 referringObjects]);
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item2ctx2 referringObjects]);
}

- (void) testRetainCycleMemoryLeakWithUserSuppliedSet
{
	const int deallocsBefore = OrderedGroupNoOppositeDeallocCalls;
	
	@autoreleasepool
	{
		COObjectGraphContext *ctx = [COObjectGraphContext new];
		OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
		OrderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
		group1.contents = @[group2];
		group2.contents = @[group1];
	}
	
	const int deallocs = OrderedGroupNoOppositeDeallocCalls - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testRetainCycleMemoryLeakWithFrameworkSuppliedSet
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	OrderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	group1.contents = @[group2];
	group2.contents = @[group1];
	
	const int deallocsBefore = OrderedGroupNoOppositeDeallocCalls;
	
	@autoreleasepool
	{
 		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		[ctx2 setItemGraph: ctx];
	}
	
	const int deallocs = OrderedGroupNoOppositeDeallocCalls - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

@end
