/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe
 
	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestItemGraph : NSObject <UKTest>
@end

@implementation TestItemGraph

- (void) testInit
{
	COItemGraph *graph = [[COItemGraph alloc] init];
	
	UKNil([graph rootItemUUID]);
	UKObjectsEqual(@[], [graph itemUUIDs]);
	
	COItem *item = [[COMutableItem alloc] init];
	[graph insertOrUpdateItems: @[item]];

	UKNil([graph rootItemUUID]);
	UKObjectsEqual(@[item.UUID], [graph itemUUIDs]);

	graph.rootItemUUID = item.UUID;
	
	UKObjectsEqual(item.UUID, [graph rootItemUUID]);
}

@end
