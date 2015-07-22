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


@interface UndoTrackHistoryCompactionTestCase : EditingContextTestCase
{
	COPersistentRoot *persistentRoot;
	COPersistentRoot *otherPersistentRoot;
	COUndoTrack *track;
}

@end


@implementation UndoTrackHistoryCompactionTestCase

- (id)init
{
	SUPERINIT;
	store.maxNumberOfDeltaCommits = 0;
	[self prepareTracks];
	return self;
}

- (void)prepareTracks
{
	// NOTE: The name must not start with 'TestUndoTrack', otherwise this
	// conflicts with pattern track tests in TestUndoTrack.m.
	track = [COUndoTrack trackForName: @"TestHistoryCompaction"
	               withEditingContext: ctx];
	[track clear];
}

- (NSDictionary *)compactUpToCommand: (COCommandGroup *)command
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
		// Will retain the store but not release it due to the exception (looks
		// like the store is retained as a receiver in -[COBranch revisionsWithOptions:]).
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

#define NODES(x) [@[[COEndOfUndoTrackPlaceholderNode sharedInstance]] arrayByAddingObjectsFromArray: x]

- (void)checkUndoRedo
{
	__unused NSUInteger counter = [track nodes].count;

	while ([track canUndo])
	{
		UKDoesNotRaiseException([track undo]);
		counter--;
	}
	while ([track canRedo])
	{
		counter++;
		UKDoesNotRaiseException([track redo]);
	}
}

@end


@interface TestUndoTrackHistoryCompaction : UndoTrackHistoryCompactionTestCase <UKTest>
@end

@implementation TestUndoTrackHistoryCompaction

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
	
	object.name = @"Wherever";
	[ctx commitWithUndoTrack: track];
	
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

	NSArray *liveCommands = [track.allCommands subarrayFromIndex: 3];
	/* COCommandSetCurrentVersionForBranch.oldRevisionID is kept alive by 
	   COUndoTrackHistoryCompaction logic, this means the oldest kept revision 
	   will be the revision prior to track.allCommands[3].newRevisionID.

	   This explains the index mistmatch between [oldRevs subarrayFromIndex: 2]
	   and the next line. */
	NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[3]
	                             expectingCompaction: compaction];

	UKObjectsEqual(liveRevs, newRevs[persistentRoot.UUID]);
	UKObjectsEqual(NODES(liveCommands), track.nodes);
	UKObjectsEqual(liveCommands, track.allCommands);
	
	[self checkUndoRedo];
}

/**
 * This is a regression test to ensure we detect compactable persistent roots
 * correctly, even when the initial undeletion/creation command has been
 * finalized with a previous compaction.
 */
- (void)testCompactPersistentRootWithTrivialHistoryTwice
{
	NSArray *oldRevs = [self createPersistentRootsWithTrivialHistory: NO][persistentRoot.UUID];

	/* First compaction */

	NSArray *liveRevs = [oldRevs subarrayFromIndex: 1];
	NSArray *deadRevs = [oldRevs arrayByRemovingObjectsInArray: liveRevs];
	COUndoTrackHistoryCompaction *compaction = [COUndoTrackHistoryCompaction new];

	compaction.finalizablePersistentRootUUIDs = [NSSet set];
	compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
	compaction.liveRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[liveRevs mappedCollection] UUID]) };
	compaction.deadRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[deadRevs mappedCollection] UUID]) };

	NSArray *liveCommands = [track.allCommands subarrayFromIndex: 2];
	/* See comment in -testCompactPersistentRootWithTrivialHistory */
	NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[2]
	                             expectingCompaction: compaction];
	
	/* Second compaction */
	
	oldRevs = liveRevs;

	liveRevs = [oldRevs subarrayFromIndex: 2];
	deadRevs = [oldRevs arrayByRemovingObjectsInArray: liveRevs];
	compaction = [COUndoTrackHistoryCompaction new];

	compaction.finalizablePersistentRootUUIDs = [NSSet set];
	compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
	compaction.liveRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[liveRevs mappedCollection] UUID]) };
	compaction.deadRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[deadRevs mappedCollection] UUID]) };

	/* COCommandSetCurrentVersionForBranch.oldRevisionID is kept alive by 
	   COUndoTrackHistoryCompaction logic, this means the oldest kept revision 
	   will be the revision prior to track.allCommands[2].newRevisionID.

	   However oldRevs starts with the old revision ID for track.allCommands[0]
	   and the old revision ID for track.allCommands[1] (which happens to be the
	   revision ID bound to track.allCommands[0]). Both will be discarded.
	   
	   After a first compaction, we always have an old revision to discard 
	   together with the first command, so there is no index mismatch between 
	   [oldRevs subarrayFromIndex: 2] and the next line. */
	liveCommands = [track.allCommands subarrayFromIndex: 2];
	newRevs = [self compactUpToCommand: track.allCommands[2]
	               expectingCompaction: compaction];

	UKObjectsEqual(liveRevs, newRevs[persistentRoot.UUID]);
	UKObjectsEqual(NODES(liveCommands), track.nodes);
	UKObjectsEqual(liveCommands, track.allCommands);
	
	[self checkUndoRedo];
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

	NSArray *liveCommands = [track.allCommands subarrayFromIndex: 6];
	/* See comment in -testCompactPersistentRootWithTrivialHistory */
	NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[6]
	                             expectingCompaction: compaction];

	UKObjectsEqual(mainLiveRevs, newRevs[persistentRoot.UUID]);
	UKNil([ctx persistentRootForUUID: otherPersistentRoot.UUID]);
	UKObjectsEqual(NODES(liveCommands), track.nodes);
	UKObjectsEqual(liveCommands, track.allCommands);
	
	[self checkUndoRedo];
}

- (void)testReachableRevisionsEncloseLiveContiguousRevisionsWithMismatchedCurrentAndHeadNodes
{
	COObject *object = [ctx insertNewPersistentRootWithEntityName: @"COObject"].rootObject;
	[ctx commitWithUndoTrack: track];
	
	object.name = @"Ding";
	[ctx commitWithUndoTrack: track];
	
	[track undo];

	COUndoTrackHistoryCompaction *compaction =
		[[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
		                                            upToCommand: (COCommandGroup *)track.currentNode];
	[compaction compute];

	UKDoesNotRaiseException([store compactHistory: compaction]);
}

@end


@interface TestPatternUndoTrackHistoryCompaction : UndoTrackHistoryCompactionTestCase <UKTest>
{
	COUndoTrack *concreteTrack1;
	COUndoTrack *concreteTrack2;
}

@end

@implementation TestPatternUndoTrackHistoryCompaction

- (void)prepareTracks
{
	// NOTE: The name must not start with 'TestUndoTrack', otherwise this
	// conflicts with pattern track tests in TestUndoTrack.m.
	track = [COUndoTrack trackForPattern: @"TestHistoryCompaction/Pattern/*"
	                  withEditingContext: ctx];
	[track clear];
	concreteTrack1 = [COUndoTrack trackForName: @"TestHistoryCompaction/Pattern/1"
	                        withEditingContext: ctx];
	[concreteTrack1 clear];
	concreteTrack2 = [COUndoTrack trackForName: @"TestHistoryCompaction/Pattern/2"
	                        withEditingContext: ctx];
	[concreteTrack2 clear];
}

- (NSArray *)createPersistentRootWithMinimalHistory
{
	COObject *object = nil;

	persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
	object = persistentRoot.rootObject;
	[ctx commitWithUndoTrack: concreteTrack2];
	
	object.name = @"Bop";
	[ctx commitWithUndoTrack: concreteTrack2];

	object.name = @"Bip";
	[ctx commitWithUndoTrack: concreteTrack2];
	
	object.name = @"Bap";
	[ctx commitWithUndoTrack: concreteTrack1];

	return persistentRoot.currentBranch.nodes;
}

/**
 * For -[COUndoTrackHistoryCompaction substractAdditionalCommandsToKeep].
 */
- (void)testCompactionKeepsCurrentCommandsOfMatchingTracks
{
	NSArray *oldRevs = [self createPersistentRootWithMinimalHistory];

	NSArray *liveRevs = [oldRevs subarrayFromIndex: 1];
	NSArray *deadRevs = [oldRevs arrayByRemovingObjectsInArray: liveRevs];
	COUndoTrackHistoryCompaction *compaction = [COUndoTrackHistoryCompaction new];

	compaction.finalizablePersistentRootUUIDs = [NSSet set];
	compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
	compaction.liveRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[liveRevs mappedCollection] UUID]) };
	compaction.deadRevisionUUIDs = @{ persistentRoot.UUID : SA((id)[[deadRevs mappedCollection] UUID]) };

	NSArray *liveCommands = [track.allCommands subarrayFromIndex: 2];
	/* Keeping 'Bap' command means we also keep keep 'Bip' which is the latest 
	   command on the other concrete track. If the compaction keeps 'Bip', then 
	   this its old revision corresponding to 'Bop' is also kept.
	   In the end, we only delete the first revision, so this is why we have 
	   this special index mismatch 1 vs 2 vs 3.
	   See also -testCompactPersistentRootWithTrivialHistory. */
	NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[3]
	                             expectingCompaction: compaction];

	UKObjectsEqual(liveRevs, newRevs[persistentRoot.UUID]);
	UKObjectsEqual(NODES(liveCommands), track.nodes);
	UKObjectsEqual(liveCommands, track.allCommands);
	
	UKObjectsEqual(NODES(@[liveCommands.lastObject]), concreteTrack1.nodes);
	UKObjectsEqual(@[liveCommands.lastObject], concreteTrack1.allCommands);

	UKObjectsEqual(NODES(@[liveCommands.firstObject]), concreteTrack2.nodes);
	UKObjectsEqual(@[liveCommands.firstObject], concreteTrack2.allCommands);
	
	[self checkUndoRedo];
}

/**
 * For -[COUndoTrackHistoryCompaction substractAdditionalCommandsToKeep] and 
 * –[[COUndoTrackHistoryCompaction validateCompaction]. 
 *
 * In these methods, when the current node is the place holder node, we must be 
 * sure we can cope with -[COSerializedCommand currentCommandUUID] returning nil.
 */
- (void)testCompactionWithPlaceholderNodeAsCurrentNodeInChildTrack
{
	COObject *object = [ctx insertNewPersistentRootWithEntityName: @"COObject"].rootObject;
	[ctx commitWithUndoTrack: concreteTrack1];
	
	object.name = @"Ding";
	[ctx commitWithUndoTrack: concreteTrack2];
	
	[track undo];

	COUndoTrackHistoryCompaction *compaction =
		[[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
		                                            upToCommand: (COCommandGroup *)track.currentNode];
	
	UKObjectKindOf(concreteTrack2.currentNode, COEndOfUndoTrackPlaceholderNode);
	UKDoesNotRaiseException([compaction compute]);
	UKDoesNotRaiseException([store compactHistory: compaction]);
}

@end
