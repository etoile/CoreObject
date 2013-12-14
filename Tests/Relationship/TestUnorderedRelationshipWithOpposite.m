/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestUnorderedRelationshipWithOpposite : NSObject <UKTest>
@end

@implementation TestUnorderedRelationshipWithOpposite

- (void) testUnorderedGroupWithOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupWithOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	UnorderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	
	group1.contents = S(item1, item2);
	group2.contents = S(item1);
	
	UKObjectsEqual(S(group1, group2), [item1 parentGroups]);
	UKObjectsEqual(S(group1), [item2 parentGroups]);
	
	// Make some changes
	
	group2.contents = S(item1, item2);
	
	UKObjectsEqual(S(group1, group2), [item2 parentGroups]);
	
	group1.contents = S(item2);
	
	UKObjectsEqual(S(group2), [item1 parentGroups]);
	
	// Reload in another graph
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnorderedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnorderedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	UnorderedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	UnorderedGroupContent *item2ctx2 = [ctx2 loadedObjectForUUID: [item2 UUID]];
	
	UKObjectsEqual(S(item2ctx2), [group1ctx2 contents]);
	UKObjectsEqual(S(item1ctx2, item2ctx2), [group2ctx2 contents]);
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item2ctx2 parentGroups]);
	UKObjectsEqual(S(group2ctx2), [item1ctx2 parentGroups]);
}

- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = S(item1, item2);
	
	UKRaisesException([(NSMutableSet *)group1.contents removeObject: item1]);
}

- (void)testNullDisallowedInCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	
	UKRaisesException([group1 setContents: S([NSNull null])]);
}

@end
