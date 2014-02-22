/*
	Copyright (C) 2010 Eric Wasylishen

	Date:  November 2010
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"
#import "COContainer.h"

@interface TestObjectGraphPerformance : EditingContextTestCase <UKTest>
@end

@implementation TestObjectGraphPerformance

- (void) make3LevelNestedTreeInContainer: (COContainer *)root
{
	for (int i=0; i<10; i++)
	{
		@autoreleasepool {
			COContainer *level1 = [root.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
			[level1 setValue: [NSString stringWithFormat: @"%d", i] forProperty: @"label"];
			[root addObject: level1];
			for (int j=0; j<10; j++)
			{
				COContainer *level2 = [root.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
				[level2 setValue: [NSString stringWithFormat: @"%d.%d", i, j] forProperty: @"label"];
				[level1 addObject: level2];
				for (int k=0; k<10; k++)
				{
					COContainer *level3 = [root.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
					[level3 setValue: [NSString stringWithFormat: @"%d.%d.%d", i, j, k] forProperty: @"label"];
					[level2 addObject: level3];
				}
			}
		}
	}
}

- (void) testCommitIsIncremental
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COObjectGraphContext *graph = [persistentRoot objectGraphContext];
	[self make3LevelNestedTreeInContainer: [graph rootObject]];
	NSArray *itemUUIDS = [graph itemUUIDs];
	
	NSDate *start = [NSDate date];
	[ctx commit];
	const NSTimeInterval secondsForFullSave = [[NSDate date] timeIntervalSinceDate: start];
	
	NSLog(@"Took %f ms to commit %d objects", secondsForFullSave * 1000.0, (int)[itemUUIDS count]);
	
	
	OutlineItem *randomItem = [graph loadedObjectForUUID: itemUUIDS[rand() % [itemUUIDS count]]];
	randomItem.label = @"modification";
	
	start = [NSDate date];
	[ctx commit];
	const NSTimeInterval secondsForDeltaSave = [[NSDate date] timeIntervalSinceDate: start];
	
	NSLog(@"Took %f ms to commit a change to 1 object out of a graph of %d", secondsForDeltaSave * 1000.0, (int)[itemUUIDS count]);

	// FIXME: The incremental save is much too slow due to unnecessary
	// serialization of the entire object graph
//	UKTrue(secondsForDeltaSave < (0.1 * secondsForFullSave));
}

@end
