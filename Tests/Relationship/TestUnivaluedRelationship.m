/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

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

- (void) testRetainCycleMemoryLeakWithUserSuppliedSet
{
	const NSUInteger deallocsBefore = [UnivaluedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
		COObjectGraphContext *ctx = [COObjectGraphContext new];
		UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
		UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
		group1.content = group2;
		group2.content = group1;
	}
	
	const NSUInteger deallocs = [UnivaluedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testRetainCycleMemoryLeakWithFrameworkSuppliedSet
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	group1.content = group2;
	group2.content = group1;
	
	const NSUInteger deallocsBefore = [UnivaluedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
 		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		[ctx2 setItemGraph: ctx];
	}
	
	const NSUInteger deallocs = [UnivaluedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void)testNullAllowedForUnivalued
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];

	UKDoesNotRaiseException([group1 setContent: nil]);
}

- (void)testNullAndNSNullEquivalent
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	group1.content = group2;
	
	UKNotNil(group1.content);
	UKDoesNotRaiseException(group1.content = (COObject *)[NSNull null]);
	UKNil(group1.content);
}

@end
