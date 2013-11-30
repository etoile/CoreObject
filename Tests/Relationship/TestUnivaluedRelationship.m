#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@class UnivaluedGroupContent;

/**
 * Test model object that has an univalued relationship to COObject (no opposite)
 */
@interface UnivaluedGroupNoOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) COObject *content;
@end

/**
 * Test model object that has an univalued relationship to UnivaluedGroupContent
 */
@interface UnivaluedGroupWithOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) UnivaluedGroupContent *content;
@end

/**
 * Test model object to be inserted as content in UnivaluedGroupWithOpposite
 */
@interface UnivaluedGroupContent : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *parents;
@end

static int UnivaluedGroupNoOppositeDeallocCalls;

@implementation UnivaluedGroupNoOpposite

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnivaluedGroupNoOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentProperty = [ETPropertyDescription descriptionWithName: @"content"
																				   type: (id)@"Anonymous.COObject"];
    [contentProperty setPersistent: YES];
	
	[entity setPropertyDescriptions: @[labelProperty, contentProperty]];
	
    return entity;
}

@dynamic label;
@dynamic content;

- (void) dealloc
{
	UnivaluedGroupNoOppositeDeallocCalls++;
}

@end

@implementation UnivaluedGroupWithOpposite

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnivaluedGroupWithOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentProperty = [ETPropertyDescription descriptionWithName: @"content"
																				   type: (id)@"Anonymous.UnivaluedGroupContent"];
    [contentProperty setPersistent: YES];
	[contentProperty setOpposite: (id)@"Anonymous.UnivaluedGroupContent.parents"];
	
	[entity setPropertyDescriptions: @[labelProperty, contentProperty]];
	
    return entity;
}

@dynamic label;
@dynamic content;
@end

@implementation UnivaluedGroupContent

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnivaluedGroupContent"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *parentsProperty = [ETPropertyDescription descriptionWithName: @"parents"
																				   type: (id)@"Anonymous.UnivaluedGroupWithOpposite"];
    [parentsProperty setMultivalued: YES];
    [parentsProperty setOrdered: NO];
	[parentsProperty setOpposite: (id)@"Anonymous.UnivaluedGroupWithOpposite.content"];
	
	[entity setPropertyDescriptions: @[labelProperty, parentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic parents;
@end



@interface TestUnivaluedRelationship : NSObject <UKTest>

@end

@implementation TestUnivaluedRelationship

/**
 * Test that an object graph of UnivaluedGroupNoOpposite can be reloaded in another
 * context. Test that one OutlineItem can be in two UnivaluedGroupNoOpposite's.
 */
- (void) testUnivaluedGroupNoOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.content = item1;
	group2.content = item1;
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnivaluedGroupNoOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnivaluedGroupNoOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	OutlineItem *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	
	UKObjectsEqual(item1ctx2, [group1ctx2 content]);
	UKObjectsEqual(item1ctx2, [group2ctx2 content]);
}

- (void) testUnivaluedGroupNoOppositeOuterReference
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	
	UnivaluedGroupNoOpposite *group1 = [ctx1 insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	OutlineItem *item1 = [ctx2 insertObjectWithEntityName: @"OutlineItem"];
	
	group1.content = item1;
	
	// Check that the relationship cache knows the inverse relationship, even though it is
	// not used in the metamodel (non-public API)
	UKObjectsEqual(S(group1), [item1 referringObjects]);
}

- (void) testUnivaluedGroupWithOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupWithOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupWithOpposite *group3 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupContent"];
	
	group1.content = item1;
	group2.content = item1;
	UKNil(group3.content);
	
	UKObjectsEqual(S(group1, group2), [item1 parents]);
	
	// Make some changes
	
	group2.content = nil;
	
	UKObjectsEqual(S(group1), [item1 parents]);
	
	group3.content = item1;
	
	UKObjectsEqual(S(group1, group3), [item1 parents]);
	
	// Reload in another graph
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnivaluedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnivaluedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	UnivaluedGroupWithOpposite *group3ctx2 = [ctx2 loadedObjectForUUID: [group3 UUID]];
	UnivaluedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	
	UKObjectsEqual(item1ctx2, [group1ctx2 content]);
	UKNil([group2ctx2 content]);
	UKObjectsEqual(item1ctx2, [group3ctx2 content]);
	UKObjectsEqual(S(group1ctx2, group3ctx2), [item1ctx2 parents]);
	
	// Check the relationship cache
	UKObjectsEqual(S(group1, group3), [item1 referringObjects]);
	UKObjectsEqual(S(group1ctx2, group3ctx2), [item1ctx2 referringObjects]);
}

- (void) testRetainCycleMemoryLeakWithUserSuppliedSet
{
	const int deallocsBefore = UnivaluedGroupNoOppositeDeallocCalls;
	
	@autoreleasepool
	{
		COObjectGraphContext *ctx = [COObjectGraphContext new];
		UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
		UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
		group1.content = group2;
		group2.content = group1;
	}
	
	const int deallocs = UnivaluedGroupNoOppositeDeallocCalls - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testRetainCycleMemoryLeakWithFrameworkSuppliedSet
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	group1.content = group2;
	group2.content = group1;
	
	const int deallocsBefore = UnivaluedGroupNoOppositeDeallocCalls;
	
	@autoreleasepool
	{
 		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		[ctx2 setItemGraph: ctx];
	}
	
	const int deallocs = UnivaluedGroupNoOppositeDeallocCalls - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

@end
