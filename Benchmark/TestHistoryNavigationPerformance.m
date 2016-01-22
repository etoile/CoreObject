/*
	Copyright (C) 2016 Quentin Mathe

	Date:  January 2016
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestHistoryNavigationPerformance : EditingContextTestCase <UKTest>
{
	int commitCounter;
}

@end

@implementation TestHistoryNavigationPerformance

#define NUM_PERSISTENT_ROOTS 500

#define BIG_NUM_PERSISTENT_ROOTS 1000

#define NUM_TOUCHED_PERSISTENT_ROOTS_PER_COMMIT 3

#define NUM_COMMITS 100

- (NSArray *)commitPersistentRootsWithUndoTrack: (COUndoTrack *)track
                                          count: (int)nbOfPersistentRoots
{
	commitCounter++;
	NSMutableArray *proots = [NSMutableArray new];
	
	for (int i = 0; i < nbOfPersistentRoots; i++)
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
	NSArray *proots = [self commitPersistentRootsWithUndoTrack: track
	                                                     count: NUM_PERSISTENT_ROOTS];

	
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
	
	UKTrue(goToFirstNodeTime < 1.0); // FIXME: 0.5

	[track setCurrentNode: track.nodes.lastObject];
	
	NSTimeInterval goToLastNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to oldest node on undo track: %0.2fs", goToLastNodeTime);
	
	UKTrue(goToLastNodeTime < 1.0); // FIXME: 0.5
}

- (void)commitDeletionOfPersistentRoots: (NSArray *)prootSlice onUndoTrack: (COUndoTrack *)track
{
	commitCounter++;
	for (COPersistentRoot *proot in prootSlice)
	{
		proot.deleted = YES;
	}
	[ctx commitWithUndoTrack: track];
}

/**
 * Tests the cost associated with deleted persistent roots previously unloaded, 
 * that must be reloaded when navigating the history.
 *
 * A new editing context is created to ensure the revision cache is empty when
 * calling -[COUndoTrack setCurrentNode:].
 */
- (void)testGoToFirstCommitNodeToReloadManyDeletedPersistentRoots
{
	COUndoTrack *track = [COUndoTrack trackForName: @"TestHistoryNavigationPerformance"
	                            withEditingContext: ctx];
	
	NSDate *startDate = [NSDate date];
	NSArray *proots = [self commitPersistentRootsWithUndoTrack: track
	                                                     count: BIG_NUM_PERSISTENT_ROOTS];
	
	NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to commit %d new persistent roots with undo track: %0.2fs", BIG_NUM_PERSISTENT_ROOTS, creationTime);
	startDate = [NSDate date];

	for (int session = 0; session < NUM_COMMITS; session++)
	{
		NSUInteger sliceCount = BIG_NUM_PERSISTENT_ROOTS / NUM_COMMITS;
		NSUInteger splitIndex = proots.count - sliceCount;
		NSArray *prootSlice = [proots subarrayFromIndex: splitIndex];
		
		proots = [proots subarrayWithRange: NSMakeRange(0, splitIndex)];
		
		ETAssert(prootSlice.count == sliceCount);
		ETAssert(proots.count % sliceCount == 0);
		
		[self commitDeletionOfPersistentRoots: prootSlice onUndoTrack: track];
	}
	
	UKTrue(ctx.loadedPersistentRoots.isEmpty);
	
	NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to make %d commits with undo track: %0.2fs", NUM_COMMITS, commitTime);

	COEditingContext *ctx2 = [self newContext];
	COUndoTrack *track2 = [COUndoTrack trackForName: @"TestHistoryNavigationPerformance"
	                             withEditingContext: ctx2];
	
	// Destroy the context to prevent it to catch any distributed notifications
	ctx = nil;
	startDate = [NSDate date];
	
	UKTrue(ctx2.loadedPersistentRoots.isEmpty);

	[track2 setCurrentNode: track2.nodes[1]];
	
	UKIntsEqual(BIG_NUM_PERSISTENT_ROOTS, ctx2.loadedPersistentRoots.count);
	
	NSTimeInterval goToNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to first commit node on undo track: %0.2fs", goToNodeTime);
	startDate = [NSDate date];
	
	UKTrue(goToNodeTime < 1.0); // FIXME: 0.5
}


@end
