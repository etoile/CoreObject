#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

/**
 * Test model object that has an unordered many-to-many relationship to COObject
 */
@interface UnorderedGroupNoOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *contents;
@end

static int UnorderedGroupNoOppositeDeallocCalls;

@implementation UnorderedGroupNoOpposite

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnorderedGroupNoOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.COObject"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];
	
	[entity setPropertyDescriptions: @[labelProperty, contentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;

- (void) dealloc
{
	UnorderedGroupNoOppositeDeallocCalls++;
}

@end

@interface TestUnorderedRelationship : NSObject <UKTest>

@end

@implementation TestUnorderedRelationship

/**
 * Test that an object graph of UnorderedGroupNoOpposite can be reloaded in another
 * context. Test that one OutlineItem can be in two UnorderedGroupNoOpposite's.
 */
- (void) testUnorderedGroupNoOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	UnorderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = S(item1, item2);
	group2.contents = S(item1);
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnorderedGroupNoOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnorderedGroupNoOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	OutlineItem *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	OutlineItem *item2ctx2 = [ctx2 loadedObjectForUUID: [item2 UUID]];
	
	UKObjectsEqual(S(item1ctx2, item2ctx2), [group1ctx2 contents]);
	UKObjectsEqual(S(item1ctx2), [group2ctx2 contents]);
}

- (void) testUnorderedGroupNoOppositeOuterReference
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	
	UnorderedGroupNoOpposite *group1 = [ctx1 insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	OutlineItem *item1 = [ctx2 insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = S(item1);
	
	// Check that the relationship cache knows the inverse relationship, even though it is
	// not used in the metamodel (non-public API)
	UKObjectsEqual(S(group1), [item1 referringObjects]);
}

- (void) testRetainCycleMemoryLeakWithUserSuppliedSet
{
	const int deallocsBefore = UnorderedGroupNoOppositeDeallocCalls;
	
	@autoreleasepool
	{
		COObjectGraphContext *ctx = [COObjectGraphContext new];
		UnorderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
		UnorderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
		group1.contents = S(group2);
		group2.contents = S(group1);
	}

	const int deallocs = UnorderedGroupNoOppositeDeallocCalls - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testRetainCycleMemoryLeakWithFrameworkSuppliedSet
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	UnorderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	group1.contents = S(group2);
	group2.contents = S(group1);

	const int deallocsBefore = UnorderedGroupNoOppositeDeallocCalls;
	
	@autoreleasepool
	{
 		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		[ctx2 setItemGraph: ctx];
	}
	
	const int deallocs = UnorderedGroupNoOppositeDeallocCalls - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = S(item1, item2);
	
	UKRaisesException([(NSMutableSet *)group1.contents removeObject: item1]);
}

@end
