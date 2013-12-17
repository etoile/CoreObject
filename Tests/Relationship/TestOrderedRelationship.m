/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

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

- (void) testRetainCycleMemoryLeakWithUserSuppliedSet
{
	const NSUInteger deallocsBefore = [OrderedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
		COObjectGraphContext *ctx = [COObjectGraphContext new];
		OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
		OrderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
		group1.contents = @[group2];
		group2.contents = @[group1];
	}
	
	const NSUInteger deallocs = [OrderedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testRetainCycleMemoryLeakWithFrameworkSuppliedSet
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	OrderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	group1.contents = @[group2];
	group2.contents = @[group1];
	
	const NSUInteger deallocsBefore = [OrderedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
 		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		[ctx2 setItemGraph: ctx];
	}
	
	const NSUInteger deallocs = [OrderedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testDuplicatesAutomaticallyRemoved
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
		
	group1.contents = @[item1, item2, item1, item1, item1, item2];
	UKTrue(([@[item2, item1] isEqual: group1.contents]
			|| [@[item1, item2] isEqual: group1.contents]));
}

- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = @[item1, item2];
		
	UKRaisesException([(NSMutableArray *)group1.contents removeObjectAtIndex: 1]);
}

- (void)testNullDisallowedInCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupNoOpposite"];

	UKRaisesException([group1 setContents: A([NSNull null])]);
}

@end
