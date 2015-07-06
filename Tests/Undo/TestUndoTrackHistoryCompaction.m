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
	COPersistentRoot *otherPersistentRoot;
	COUndoTrack *track;
}

@end


@implementation TestUndoTrackHistoryCompaction

- (id)init
{
	SUPERINIT;
	store.maxNumberOfDeltaCommits = 0;
	// NOTE: The name must not start with 'TestUndoTrack', otherwise this
	// conflicts with pattern track tests in TestUndoTrack.m.
	track = [COUndoTrack trackForName: @"TestHistoryCompaction"
	               withEditingContext: ctx];
	[track clear];
	return self;
}

- (NSDictionary *)createPersistentRootsWithTrivialHistory: (BOOL)createMultiplePersistentRoots
{
	COObject *object = nil;
	COObject *otherObject = nil;

	persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
	object = persistentRoot.rootObject;
	[ctx commitWithUndoTrack: track];

	object.name = @"Anywhere";
	[ctx commitWithUndoTrack: track];
	
	if (createMultiplePersistentRoots)
	{
		otherPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
		otherObject = otherPersistentRoot.rootObject;
		[ctx commitWithUndoTrack: track];
	}
	
	object.name = @"Somewhere";
	[ctx commitWithUndoTrack: track];
	
	if (createMultiplePersistentRoots)
	{
		otherObject.name = @"Badger";
		[ctx commitWithUndoTrack: track];
		
		otherPersistentRoot.deleted = YES;
		[ctx commitWithUndoTrack: track];
	}
	
	object.name = @"Nowhere";
	[ctx commitWithUndoTrack: track];
	
	NSMutableDictionary *revs =  [NSMutableDictionary new];
	
	revs[persistentRoot.UUID] = persistentRoot.currentBranch.nodes;
	if (otherPersistentRoot != nil)
	{
	     revs[otherPersistentRoot.UUID] = otherPersistentRoot.currentBranch.nodes;
	}
	return revs;
}

- (NSDictionary *)compactUpToCommand: (COCommand *)command
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

	if (otherPersistentRoot.isDeleted)
	{
		UKRaisesException([otherPersistentRoot.currentBranch reloadRevisions]);
	}

	NSMutableDictionary *revs =  [NSMutableDictionary new];
	
	revs[persistentRoot.UUID] = persistentRoot.currentBranch.nodes;
	if (otherPersistentRoot != nil)
	{
	     revs[otherPersistentRoot.UUID] = otherPersistentRoot.currentBranch.nodes;
	}
	return revs;
}

- (void)testCompactPersistentRootWithTrivialHistory
{
	NSArray *oldRevs = [self createPersistentRootsWithTrivialHistory: NO][persistentRoot.UUID];

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
	NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[3]
	                             expectingCompaction: compaction];

	UKObjectsEqual(liveRevs, newRevs[persistentRoot.UUID]);
}

- (void)testPersistentRootFinalization
{
	NSDictionary *oldRevs = [self createPersistentRootsWithTrivialHistory: YES];

	/* We have 4 revisions in the main persistent root, we discard the last 
	   command (keeping 6 commands out of 7), this means we keep the last 
	   revision and the one just before, so we keep 2 revisions. */
	NSArray *mainLiveRevs = [oldRevs[persistentRoot.UUID] subarrayFromIndex: 2];
	NSArray *mainDeadRevs = [oldRevs[persistentRoot.UUID] arrayByRemovingObjectsInArray: mainLiveRevs];
	COUndoTrackHistoryCompaction *compaction = [COUndoTrackHistoryCompaction new];

	compaction.finalizablePersistentRootUUIDs = S(otherPersistentRoot.UUID);
	compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
	compaction.liveRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[mainLiveRevs mappedCollection] UUID]),
	                             otherPersistentRoot.UUID : [NSSet new] };
	compaction.deadRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[mainDeadRevs mappedCollection] UUID]),
	                             otherPersistentRoot.UUID : oldRevs[otherPersistentRoot.UUID] };

	/* See comment in -testCompactPersistentRootWithTrivialHistory */
	NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[6]
	                             expectingCompaction: compaction];

	UKObjectsEqual(mainLiveRevs, newRevs[persistentRoot.UUID]);
	UKNil([ctx persistentRootForUUID: otherPersistentRoot.UUID]);
}

@end
