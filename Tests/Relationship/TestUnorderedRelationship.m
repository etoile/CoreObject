/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

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
	const NSUInteger deallocsBefore = [UnorderedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
		COObjectGraphContext *ctx = [COObjectGraphContext new];
		UnorderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
		UnorderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
		group1.contents = S(group2);
		group2.contents = S(group1);
	}

	const NSUInteger deallocs = [UnorderedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testRetainCycleMemoryLeakWithFrameworkSuppliedSet
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	UnorderedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	group1.contents = S(group2);
	group2.contents = S(group1);

	const NSUInteger deallocsBefore = [UnorderedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
 		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		[ctx2 setItemGraph: ctx];
	}
	
	const NSUInteger deallocs = [UnorderedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
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

- (void)testNullDisallowedInCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
	
	UKRaisesException([group1 setContents: S([NSNull null])]);
}

@end
