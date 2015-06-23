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
	COPersistentRoot *_persistentRoot;
	COUndoTrack *_track;
}

@end


@implementation TestUndoTrackHistoryCompaction

- (id)init
{
	SUPERINIT;
	_track = [COUndoTrack trackForName: [self className]
	                withEditingContext: ctx];
	[_track clear];
	return self;
}

- (NSArray *)createPersistentRootWithTrivialHistory
{
	_persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
	[ctx commitWithUndoTrack: _track];
	
	COObject *object = _persistentRoot.rootObject;

	object.name = @"Anywhere";
	[ctx commitWithUndoTrack: _track];
	
	object.name = @"Somewhere";
	[ctx commitWithUndoTrack: _track];
	
	object.name = @"Nowhere";
	[ctx commitWithUndoTrack: _track];
	
	return _persistentRoot.currentBranch.nodes;
}

- (NSArray *)compactUpToCommand: (COCommand *)command
            expectingCompaction: (COUndoTrackHistoryCompaction *)expectedCompaction
{
	COUndoTrackHistoryCompaction *compaction =
		[[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: _track
		                                            upToCommand: command];
	
	[compaction compute];
	
	NSSet *persistentRootUUIDs = [compaction.finalizablePersistentRootUUIDs
		setByAddingObjectsFromSet: compaction.compactablePersistentRootUUIDs];
	
	UKObjectsEqual(expectedCompaction.finalizablePersistentRootUUIDs, compaction.finalizablePersistentRootUUIDs);
	UKObjectsEqual(expectedCompaction.compactablePersistentRootUUIDs, compaction.compactablePersistentRootUUIDs);
	UKIntsEqual(persistentRootUUIDs.count, expectedCompaction.liveRevisionUUIDs.count);
	UKIntsEqual(persistentRootUUIDs.count, expectedCompaction.deadRevisionUUIDs.count);
	UKObjectsEqual([expectedCompaction liveRevisionUUIDsForPersistentRootUUIDs: @[_persistentRoot.UUID]],
	                       [compaction liveRevisionUUIDsForPersistentRootUUIDs: @[_persistentRoot.UUID]]);
	UKObjectsEqual([expectedCompaction deadRevisionUUIDsForPersistentRootUUIDs: @[_persistentRoot.UUID]],
	                       [compaction deadRevisionUUIDsForPersistentRootUUIDs: @[_persistentRoot.UUID]]);

	UKTrue([store compactHistory: compaction]);
	
	// TODO: Remove, the branches should receive a notification.
	[_persistentRoot.currentBranch reloadRevisions];

	return _persistentRoot.currentBranch.nodes;
}

- (void)testCompactPersistentRootWithTrivialHistory
{
	NSArray *oldRevs = [self createPersistentRootWithTrivialHistory];

	NSArray *liveRevs = [oldRevs subarrayFromIndex: 2];
	NSArray *deadRevs = [oldRevs arrayByRemovingObjectsInArray: liveRevs];
	COUndoTrackHistoryCompaction *compaction = [COUndoTrackHistoryCompaction new];

	compaction.finalizablePersistentRootUUIDs = [NSSet set];
	compaction.compactablePersistentRootUUIDs = S(_persistentRoot.UUID);
	compaction.liveRevisionUUIDs = @{ _persistentRoot.UUID : SA((id)[[liveRevs mappedCollection] UUID]) };
	compaction.deadRevisionUUIDs = @{ _persistentRoot.UUID : SA((id)[[deadRevs mappedCollection] UUID]) };

	/* COCommandSetCurrentVersionForBranch.oldRevisionID is kept alive by 
	   COUndoTrackHistoryCompaction logic, this means the oldest kept revision 
	   will be the revision prior to _track.allCommands[3].newRevisionID.

	   This explains the index mistmatch between oldRevs subarrayFromIndex: 2]
	   and the next line. */
	NSArray *newRevs = [self compactUpToCommand: _track.allCommands[3]
	                        expectingCompaction: compaction];

	// FIXME: UKObjectsEqual(liveRevs, newRevs);
}

@end
