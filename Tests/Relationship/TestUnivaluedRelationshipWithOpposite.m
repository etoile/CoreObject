/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestUnivaluedRelationshipWithOpposite : NSObject <UKTest>
@end

@implementation TestUnivaluedRelationshipWithOpposite

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

- (void)testNullAllowedForUnivalued
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	
	UKDoesNotRaiseException([group1 setContent: nil]);
}

- (void)testNullAndNSNullEquivalent
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupContent"];
	group1.content = item1;
	
	UKNotNil(group1.content);
	UKDoesNotRaiseException(group1.content = (UnivaluedGroupContent *)[NSNull null]);
	UKNil(group1.content);
}

@end
