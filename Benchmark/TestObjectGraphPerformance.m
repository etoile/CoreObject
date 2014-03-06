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
#import "BenchmarkCommon.h"

@interface TestObjectGraphPerformance : EditingContextTestCase <UKTest>
@end

#define COMMIT_ITERATIONS 10
#define MS_PER_SECOND 1000

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

- (NSTimeInterval) timeToMakeInitialCommitToPersistentRoot: (COPersistentRoot *)persistentRoot
{
	COObjectGraphContext *graph = [persistentRoot objectGraphContext];
	[self make3LevelNestedTreeInContainer: [graph rootObject]];
	
	NSDate *start = [NSDate date];
	[ctx commit];
	const NSTimeInterval secondsForFullSave = [[NSDate date] timeIntervalSinceDate: start];
	return secondsForFullSave;
}

- (void) makeIncrementalCommitToPersistentRoot: (COPersistentRoot *)persistentRoot
{
	COObjectGraphContext *graph = [persistentRoot objectGraphContext];
	NSArray *itemUUIDS = [graph itemUUIDs];
	int randNumber = rand();
	OutlineItem *randomItem = [graph loadedObjectForUUID: itemUUIDS[randNumber % [itemUUIDS count]]];
	randomItem.label = [NSString stringWithFormat: @"random number: %d", randNumber];
	[ctx commit];
}

- (NSTimeInterval) timeToMakeIncrementalCommitToPersistentRoot: (COPersistentRoot *)persistentRoot
{
	NSDate *start = [NSDate date];
	for (int i=0; i<COMMIT_ITERATIONS; i++)
	{
		[self makeIncrementalCommitToPersistentRoot: persistentRoot];
	}
	const NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start] / COMMIT_ITERATIONS;
	return time;
}

- (void) testCommitIsIncremental
{
	COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];

	NSTimeInterval timeToMakeInitialCommitToPersistentRoot = [self timeToMakeInitialCommitToPersistentRoot: persistentRoot];
	NSTimeInterval timeToMakeIncrementalCommitToPersistentRoot = [self timeToMakeIncrementalCommitToPersistentRoot: persistentRoot];
	NSTimeInterval timeToCommit1KUsingSQLite = [BenchmarkCommon timeToCommit1KUsingSQLite];
	
	double coreObjectTimesWorse = timeToMakeIncrementalCommitToPersistentRoot / timeToCommit1KUsingSQLite;
	UKTrue(coreObjectTimesWorse < 100);
	
	NSLog(@"Took %f ms to commit %d objects",
		  timeToMakeInitialCommitToPersistentRoot * MS_PER_SECOND,
		  (int)[[persistentRoot.objectGraphContext itemUUIDs] count]);
	
	NSLog(@"Took %f ms to commit a change to 1 object in that graph. SQLite takes %f ms to commit 1K bytes. CO is %f times worse.",
		  timeToMakeIncrementalCommitToPersistentRoot * MS_PER_SECOND,
		  timeToCommit1KUsingSQLite * MS_PER_SECOND,
		  coreObjectTimesWorse);
}

@end
