/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"
#import "COUndoTrackHistoryCompaction.h"

@interface COBranch ()
- (void)reloadRevisions;
@end

@interface COUndoTrackHistoryCompaction (TestUndoTrackHistoryCompaction)
@property (nonatomic, readwrite) NSSet *finalizablePersistentRootUUIDs;
@property (nonatomic, readwrite) NSSet *compactablePersistentRootUUIDs;
@property (nonatomic, readwrite) NSDictionary *deadRevisionUUIDs;
@property (nonatomic, readwrite) NSDictionary *liveRevisionUUIDs;
@end

@implementation COUndoTrackHistoryCompaction (TestUndoTrackHistoryCompaction)

@dynamic finalizablePersistentRootUUIDs, compactablePersistentRootUUIDs, deadRevisionUUIDs, liveRevisionUUIDs;

- (void)setFinalizablePersistentRootUUIDs: (NSSet *)finalizablePersistentRootUUIDs
{
	[self setValue: [finalizablePersistentRootUUIDs mutableCopy] forKey: @"_finalizablePersistentRootUUIDs"];
}

- (void)setCompactablePersistentRootUUIDs: (NSSet *)compactablePersistentRootUUIDs
{
	[self setValue: [compactablePersistentRootUUIDs mutableCopy] forKey: @"_compactablePersistentRootUUIDs"];
}

- (void)setDeadRevisionUUIDs: (NSDictionary *)deadRevisionUUIDs
{
	[self setValue: [deadRevisionUUIDs mutableCopy] forKey: @"_deadRevisionUUIDs"];
}

- (void)setLiveRevisionUUIDs: (NSDictionary *)liveRevisionUUIDs
{
	[self setValue: [liveRevisionUUIDs mutableCopy] forKey: @"_liveRevisionUUIDs"];
}

@end


@interface TestUndoTrackHistoryCompaction : EditingContextTestCase <UKTest>
{
	COPersistentRoot *persistentRoot;
	COUndoTrack *track;
}

@end


@implementation TestUndoTrackHistoryCompaction

- (id)init
{
	SUPERINIT;
	store.maxNumberOfDeltaCommits = 0;
	track = [COUndoTrack trackForName: [self className]
	               withEditingContext: ctx];
	[track clear];
	return self;
}

- (NSArray *)createPersistentRootWithTrivialHistory
{
	persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
	[ctx commitWithUndoTrack: track];
	
	COObject *object = persistentRoot.rootObject;

	object.name = @"Anywhere";
	[ctx commitWithUndoTrack: track];
	
	object.name = @"Somewhere";
	[ctx commitWithUndoTrack: track];
	
	object.name = @"Nowhere";
	[ctx commitWithUndoTrack: track];
	
	return persistentRoot.currentBranch.nodes;
}

- (NSArray *)compactUpToCommand: (COCommand *)command
            expectingCompaction: (COUndoTrackHistoryCompaction *)expectedCompaction
{
	COUndoTrackHistoryCompaction *compaction =
		[[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
		                                            upToCommand: command];
	
	[compaction compute];
	
	NSSet *persistentRootUUIDs = [compaction.finalizablePersistentRootUUIDs
		setByAddingObjectsFromSet: compaction.compactablePersistentRootUUIDs];
	
	UKObjectsEqual(expectedCompaction.finalizablePersistentRootUUIDs, compaction.finalizablePersistentRootUUIDs);
	UKObjectsEqual(expectedCompaction.compactablePersistentRootUUIDs, compaction.compactablePersistentRootUUIDs);
	UKIntsEqual(persistentRootUUIDs.count, expectedCompaction.liveRevisionUUIDs.count);
	UKIntsEqual(persistentRootUUIDs.count, expectedCompaction.deadRevisionUUIDs.count);
	UKObjectsEqual([expectedCompaction liveRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]],
	                       [compaction liveRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]]);
	UKObjectsEqual([expectedCompaction deadRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]],
	                       [compaction deadRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]]);

	UKTrue([store compactHistory: compaction]);
	
	// TODO: Remove, the branches should receive a notification.
	[persistentRoot.currentBranch reloadRevisions];

	return persistentRoot.currentBranch.nodes;
}

- (void)testCompactPersistentRootWithTrivialHistory
{
	NSArray *oldRevs = [self createPersistentRootWithTrivialHistory];

	NSArray *liveRevs = [oldRevs subarrayFromIndex: 2];
	NSArray *deadRevs = [oldRevs arrayByRemovingObjectsInArray: liveRevs];
	COUndoTrackHistoryCompaction *compaction = [COUndoTrackHistoryCompaction new];

	compaction.finalizablePersistentRootUUIDs = [NSSet set];
	compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
	compaction.liveRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[liveRevs mappedCollection] UUID]) };
	compaction.deadRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[deadRevs mappedCollection] UUID]) };

	/* COCommandSetCurrentVersionForBranch.oldRevisionID is kept alive by 
	   COUndoTrackHistoryCompaction logic, this means the oldest kept revision 
	   will be the revision prior to track.allCommands[3].newRevisionID.

	   This explains the index mistmatch between oldRevs subarrayFromIndex: 2]
	   and the next line. */
	NSArray *newRevs = [self compactUpToCommand: track.allCommands[3]
	                        expectingCompaction: compaction];

	UKObjectsEqual(liveRevs, newRevs);
}

@end
