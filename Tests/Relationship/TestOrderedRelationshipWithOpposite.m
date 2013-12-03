#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestOrderedRelationshipWithOpposite : NSObject <UKTest>
@end

@implementation TestOrderedRelationshipWithOpposite

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

- (void) testDuplicatesAutomaticallyRemoved
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = @[item1, item2, item1, item1, item1, item2];
	UKTrue(([@[item2, item1] isEqual: group1.contents]
			|| [@[item1, item2] isEqual: group1.contents]));
}

- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	OutlineItem *item2 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.contents = @[item1, item2];
	
	UKRaisesException([(NSMutableArray *)group1.contents removeObjectAtIndex: 1]);
}

@end
