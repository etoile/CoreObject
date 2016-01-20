/*
	Copyright (C) 2016 Quentin Mathe

	Date:  January 2016
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestHistoryNavigationPerformance : EditingContextTestCase <UKTest>
@end

@implementation TestHistoryNavigationPerformance

#define NUM_PERSISTENT_ROOTS 500

#define NUM_TOUCHED_PERSISTENT_ROOTS_PER_COMMIT 3

#define NUM_COMMITS 100

static int commitCounter = 0;

- (NSArray *)commitPersistentRootsWithUndoTrack: (COUndoTrack *)track
{
	commitCounter++;
	NSMutableArray *proots = [NSMutableArray new];
	
	for (int i = 0; i < NUM_PERSISTENT_ROOTS; i++)
	{
		[proots addObject: [ctx insertNewPersistentRootWithEntityName: @"COTag"]];
	}
	[ctx commitWithUndoTrack: track];

	return proots;
}

- (void)commitSessionWithPersistentRoot: (COPersistentRoot *)proot onUndoTrack: (COUndoTrack *)track
{
	commitCounter++;

	for (int session = 0; session < NUM_TOUCHED_PERSISTENT_ROOTS_PER_COMMIT; session++)
	{
		COTag *tag = [ctx.persistentRoots.anyObject rootObject];
	
		tag.name = [NSString stringWithFormat: @"Commit %d", commitCounter];
		[proot.rootObject addObjects: @[tag]];
	}

	[ctx commitWithUndoTrack: track];
}

- (void)testGoToOldestAndNewestNodesInHistory
{
	COUndoTrack *track = [COUndoTrack trackForName: @"TestHistoryNavigationPerformance"
	                            withEditingContext: ctx];
	
	NSDate *startDate = [NSDate date];
	NSArray *proots = [self commitPersistentRootsWithUndoTrack: track];

	
	NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to commit %d new persistent roots with undo track: %0.2fs", NUM_PERSISTENT_ROOTS, creationTime);
	startDate = [NSDate date];

	for (int session = 0; session < NUM_COMMITS; session++)
	{
		const int prootIndex = rand() % NUM_PERSISTENT_ROOTS;
		COPersistentRoot *proot = proots[prootIndex];
		
		[self commitSessionWithPersistentRoot: proot onUndoTrack: track];
	}
	
	NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to make %d commits with undo track: %0.2fs", NUM_COMMITS, commitTime);
	startDate = [NSDate date];

	[track setCurrentNode: track.nodes.firstObject];
	
	NSTimeInterval goToFirstNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to newest node on undo track: %0.2fs", goToFirstNodeTime);
	startDate = [NSDate date];
	
	// FIXME: UKTrue(goToFirstNodeTime < 0.5);

	[track setCurrentNode: track.nodes.lastObject];
	
	NSTimeInterval goToLastNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to oldest node on undo track: %0.2fs", goToLastNodeTime);
	
	// FIXME: UKTrue(goToLastNodeTime < 0.5);
}

@end
