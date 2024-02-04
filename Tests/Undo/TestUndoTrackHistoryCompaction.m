/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface COBranch ()

- (void)reloadRevisions;

@end

@interface COExpectedCompaction : COUndoTrackHistoryCompaction

- (instancetype)init;

@property (nonatomic, readwrite, copy) NSSet *finalizablePersistentRootUUIDs;
@property (nonatomic, readwrite, copy) NSSet *compactablePersistentRootUUIDs;
@property (nonatomic, readwrite, copy) NSDictionary *deadRevisionUUIDs;
@property (nonatomic, readwrite, copy) NSDictionary *liveRevisionUUIDs;

- (instancetype)init;

@end


@implementation COExpectedCompaction

@dynamic finalizablePersistentRootUUIDs, compactablePersistentRootUUIDs, deadRevisionUUIDs, liveRevisionUUIDs;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    return self;
}

#pragma clang diagnostic pop

- (void)setFinalizablePersistentRootUUIDs: (NSSet *)finalizablePersistentRootUUIDs
{
    [self setValue: [finalizablePersistentRootUUIDs mutableCopy]
            forKey: @"_finalizablePersistentRootUUIDs"];
}

- (void)setCompactablePersistentRootUUIDs: (NSSet *)compactablePersistentRootUUIDs
{
    [self setValue: [compactablePersistentRootUUIDs mutableCopy]
            forKey: @"_compactablePersistentRootUUIDs"];
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

- (instancetype)init
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
                   withContext: ctx];
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

    UKObjectsEqual(expectedCompaction.finalizablePersistentRootUUIDs,
                   compaction.finalizablePersistentRootUUIDs);
    UKObjectsEqual(expectedCompaction.compactablePersistentRootUUIDs,
                   compaction.compactablePersistentRootUUIDs);
    UKIntsEqual(persistentRootUUIDs.count, expectedCompaction.liveRevisionUUIDs.count);
    UKIntsEqual(persistentRootUUIDs.count, expectedCompaction.deadRevisionUUIDs.count);
    UKObjectsEqual([expectedCompaction liveRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]],
                   [compaction liveRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]]);
    UKObjectsEqual([expectedCompaction deadRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]],
                   [compaction deadRevisionUUIDsForPersistentRootUUIDs: @[persistentRoot.UUID]]);

    UKTrue([store compactHistory: compaction]);

    if (otherPersistentRoot.deleted)
    {
        // Will retain the store but not release it due to the exception (looks
        // like the store is retained as a receiver in -[COBranch revisionsWithOptions:]).
        UKRaisesException([otherPersistentRoot.currentBranch reloadRevisions]);
    }

    NSMutableDictionary *revs = [NSMutableDictionary new];

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
     __attribute__((unused)) NSUInteger counter = track.nodes.count;

    while (track.canUndo)
    {
        UKDoesNotRaiseException([track undo]);
        counter--;
    }
    while (track.canRedo)
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

    NSMutableDictionary *revs = [NSMutableDictionary new];

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
    COExpectedCompaction *compaction = [COExpectedCompaction new];

    compaction.finalizablePersistentRootUUIDs = [NSSet set];
    compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
    compaction.liveRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[liveRevs mappedCollection] UUID])};
    compaction.deadRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[deadRevs mappedCollection] UUID])};

    NSArray *liveCommands = [track.allCommands subarrayFromIndex: 3];
    /* The oldest kept revision is track.allCommands[3].oldRevision, so
       track.allCommands[2] is discarded but track.allCommands[2].revision isn't.

       We discard 3 commands and 2 revisions. */
    NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[2]
                                 expectingCompaction: compaction];

    UKObjectsEqual(liveRevs, newRevs[persistentRoot.UUID]);
    UKObjectsEqual(liveCommands, [track.nodes subarrayFromIndex: 1]);
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
    COExpectedCompaction *compaction = [COExpectedCompaction new];

    compaction.finalizablePersistentRootUUIDs = [NSSet set];
    compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
    compaction.liveRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[liveRevs mappedCollection] UUID])};
    compaction.deadRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[deadRevs mappedCollection] UUID])};

    NSArray *liveCommands = [track.allCommands subarrayFromIndex: 2];
    /* See comment in -testCompactPersistentRootWithTrivialHistory */
    NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[1]
                                 expectingCompaction: compaction];

    /* Second compaction */

    oldRevs = liveRevs;

    liveRevs = [oldRevs subarrayFromIndex: 2];
    deadRevs = [oldRevs arrayByRemovingObjectsInArray: liveRevs];
    compaction = [COExpectedCompaction new];

    compaction.finalizablePersistentRootUUIDs = [NSSet set];
    compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
    compaction.liveRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[liveRevs mappedCollection] UUID])};
    compaction.deadRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[deadRevs mappedCollection] UUID])};

    /* The oldest kept revision is track.allCommands[2].oldRevision, so
       track.allCommands[1] is discarded but track.allCommands[1].revision isn't.
       
       The latest discarded revision is track.allCommands[0].oldRevision, that
       isn't nil since this is the second compaction.

       We discard 2 commands and 2 revisions. */
    liveCommands = [track.allCommands subarrayFromIndex: 2];
    newRevs = [self compactUpToCommand: track.allCommands[1]
                   expectingCompaction: compaction];

    UKObjectsEqual(liveRevs, newRevs[persistentRoot.UUID]);
    UKObjectsEqual(liveCommands, [track.nodes subarrayFromIndex: 1]);
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
    COExpectedCompaction *compaction = [COExpectedCompaction new];

    compaction.finalizablePersistentRootUUIDs = S(otherPersistentRoot.UUID);
    compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
    compaction.liveRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[mainLiveRevs mappedCollection] UUID]),
                                     otherPersistentRoot.UUID: [NSSet new]};
    compaction.deadRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[mainDeadRevs mappedCollection] UUID]),
                                     otherPersistentRoot.UUID: oldRevs[otherPersistentRoot.UUID]};

    NSArray *liveCommands = [track.allCommands subarrayFromIndex: 6];
    /* See comment in -testCompactPersistentRootWithTrivialHistory */
    NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[5]
                                 expectingCompaction: compaction];

    UKObjectsEqual(mainLiveRevs, newRevs[persistentRoot.UUID]);
    UKNil([ctx persistentRootForUUID: otherPersistentRoot.UUID]);
    UKObjectsEqual(liveCommands, [track.nodes subarrayFromIndex: 1]);
    UKObjectsEqual(liveCommands, track.allCommands);

    [self checkUndoRedo];
}

/**
 * In this precise case, live contiguous revisions are a subset of reachable 
 * revisions in -[COSQLiteStore compactHistory:], but they can overlap in other 
 * situations. 
 *
 * See -testDivergentRevisionsWithUndoFollowedByCommit.
 */
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

- (void)testExceptionOnPlaceholderNodeAsOldestKeptCommand
{
    // Will retain the undo track but not release it due to the exception (looks
    // like the undo track store remains retained).
    UKRaisesException([[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                                  upToCommand: (COCommandGroup *)track.currentNode]);
}

- (void)testDivergentRevisionsWithUndoFollowedByCommit
{
    COObject *object = [ctx insertNewPersistentRootWithEntityName: @"COObject"].rootObject;
    [ctx commitWithUndoTrack: track];

    object.name = @"Ding";
    [ctx commitWithUndoTrack: track];

    [track undo];

    object.name = @"Dong";
    [ctx commitWithUndoTrack: track];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.currentNode];
    [compaction compute];

    UKDoesNotRaiseException([store compactHistory: compaction]);
}

- (void)testDeadRevisionsForUnknownOrFinalizablePersistentRoot
{
    [ctx insertNewPersistentRootWithEntityName: @"COObject"];
    [ctx commitWithUndoTrack: track];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.currentNode];

    UKObjectsEqual([NSSet new],
                   [compaction deadRevisionUUIDsForPersistentRootUUIDs: @[[ETUUID new]]]);
}

/** 
 * When we compact a backing store where some revisions have no corresponding
 * commands in the compacted undo track, -[COSQLiteStore compactHistory:] can 
 * end up finalizing these revisions belonging to persistent roots unknown by 
 * the undo track.
 */
- (void)testLiveRevisionsForUnknownOrFinalizablePersistentRoot
{
    [ctx insertNewPersistentRootWithEntityName: @"COObject"];
    [ctx commitWithUndoTrack: track];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.currentNode];

    UKObjectsEqual([NSSet new],
                   [compaction liveRevisionUUIDsForPersistentRootUUIDs: @[[ETUUID new]]]);
}

- (OutlineItem *)createPersistentRootWithAttachmentInHistory: (NSString *)fakeAttachment
{
    OutlineItem *item = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    [ctx commitWithUndoTrack: track];

    COAttachmentID *hash = [store importAttachmentFromData:
        [fakeAttachment dataUsingEncoding: NSUTF8StringEncoding]];

    item.attachmentID = hash;
    [ctx commitWithUndoTrack: track];

    return item;
}

- (void)testKeepAttachmentReferencedByLiveRevisions
{
    NSString *fakeAttachment = @"this is a large attachment";
    OutlineItem *item = [self createPersistentRootWithAttachmentInHistory: fakeAttachment];
    NSURL *URL = [store URLForAttachmentID: item.attachmentID];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.currentNode.parentNode];
    [compaction compute];
    [store compactHistory: compaction];

    UKObjectsNotEqual(NODES(@[]), track.nodes);
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: URL
                                                            encoding: NSUTF8StringEncoding
                                                               error: NULL]);
    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: URL.path]);
}

- (void)testKeepAttachmentReferencedByLiveRevisionsOnEmptyTrack
{
    NSString *fakeAttachment = @"this is a large attachment";
    OutlineItem *item = [self createPersistentRootWithAttachmentInHistory: fakeAttachment];
    NSURL *URL = [store URLForAttachmentID: item.attachmentID];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.currentNode];
    [compaction compute];
    [store compactHistory: compaction];

    UKObjectsEqual(NODES(@[]), track.nodes);
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: URL
                                                            encoding: NSUTF8StringEncoding
                                                               error: NULL]);
    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: URL.path]);
}

- (void)testFinalizeAttachmentReferencedByDeadRevisions
{
    NSString *fakeAttachment = @"this is a large attachment";
    OutlineItem *item = [self createPersistentRootWithAttachmentInHistory: fakeAttachment];
    NSURL *URL = [store URLForAttachmentID: item.attachmentID];

    item.attachmentID = nil;
    [ctx commitWithUndoTrack: track];

    // At this point, the revision that created the attachment is still
    // referenced by track.currentNode.oldRevisionUUID.
    // We make one more commit to ensure the attachment won't be referenced,
    // if we compact up to the current node.
    item.name = @"Oak";
    [ctx commitWithUndoTrack: track];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.currentNode.parentNode];
    [compaction compute];
    [store compactHistory: compaction];

    UKObjectsNotEqual(NODES(@[]), track.nodes);
    UKNil([NSString stringWithContentsOfURL: URL
                                   encoding: NSUTF8StringEncoding
                                      error: NULL]);
    UKFalse([[NSFileManager defaultManager] fileExistsAtPath: URL.path]);
}

- (void)testFinalizeAttachmentReferencedByDeadRevisionsOnEmptyTrack
{
    NSString *fakeAttachment = @"this is a large attachment";
    OutlineItem *item = [self createPersistentRootWithAttachmentInHistory: fakeAttachment];
    NSURL *URL = [store URLForAttachmentID: item.attachmentID];

    item.attachmentID = nil;
    [ctx commitWithUndoTrack: track];

    // At this point, the revision that created the attachment is still
    // referenced by track.currentNode.oldRevisionUUID.
    // We make one more commit to ensure the attachment won't be referenced,
    // if we compact up to the current node.
    item.name = @"Oak";
    [ctx commitWithUndoTrack: track];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.currentNode];
    [compaction compute];
    [store compactHistory: compaction];

    UKObjectsEqual(NODES(@[]), track.nodes);
    UKNil([NSString stringWithContentsOfURL: URL
                                   encoding: NSUTF8StringEncoding
                                      error: NULL]);
    UKFalse([[NSFileManager defaultManager] fileExistsAtPath: URL.path]);
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
                      withContext: ctx];
    [track clear];
    concreteTrack1 = [COUndoTrack trackForName: @"TestHistoryCompaction/Pattern/1"
                            withContext: ctx];
    [concreteTrack1 clear];
    concreteTrack2 = [COUndoTrack trackForName: @"TestHistoryCompaction/Pattern/2"
                            withContext: ctx];
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

- (void)testCompactionDiscardsAllCommandsOfMatchingTracks
{
    NSArray *oldRevs = [self createPersistentRootWithMinimalHistory];

    NSArray *liveRevs = [oldRevs subarrayFromIndex: 2];
    NSArray *deadRevs = [oldRevs arrayByRemovingObjectsInArray: liveRevs];
    COExpectedCompaction *compaction = [COExpectedCompaction new];

    compaction.finalizablePersistentRootUUIDs = [NSSet set];
    compaction.compactablePersistentRootUUIDs = S(persistentRoot.UUID);
    compaction.liveRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[liveRevs mappedCollection] UUID])};
    compaction.deadRevisionUUIDs = @{persistentRoot.UUID: SA((id)[[deadRevs mappedCollection] UUID])};

    NSArray *liveCommands = [track.allCommands subarrayFromIndex: 3];
    /* Keeping 'Bap' command means we also keep keep 'Bip' which is the latest 
       command on the other concrete track. The old revision corresponding to 
       'Bop' is not kept, and we only delete the two first revisions.
       See also -testCompactPersistentRootWithTrivialHistory. */
    NSDictionary *newRevs = [self compactUpToCommand: track.allCommands[2]
                                 expectingCompaction: compaction];

    UKObjectsEqual(liveRevs, newRevs[persistentRoot.UUID]);
    UKObjectsEqual(NODES(liveCommands), track.nodes);
    UKObjectsEqual(liveCommands, track.allCommands);

    UKObjectsEqual(NODES(@[liveCommands.lastObject]), concreteTrack1.nodes);
    UKObjectsEqual(@[liveCommands.lastObject], concreteTrack1.allCommands);

    UKObjectsEqual(NODES(@[]), concreteTrack2.nodes);
    UKObjectsEqual(@[], concreteTrack2.allCommands);

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

- (void)testCompactionsInterleavedWithCommitsAndUndoRedo
{
    COObject *object = [ctx insertNewPersistentRootWithEntityName: @"COObject"].rootObject;
    [ctx commitWithUndoTrack: concreteTrack1];

    COUndoTrackHistoryCompaction *compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.nodes.lastObject];

    UKIntsEqual(2, track.nodes.count);
    UKDoesNotRaiseException([compaction compute]);
    UKDoesNotRaiseException([store compactHistory: compaction]);
    UKIntsEqual(1, track.nodes.count);

    object.name = @"Ding";
    [ctx commitWithUndoTrack: concreteTrack1];

    compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.nodes.lastObject];

    UKIntsEqual(2, track.nodes.count);
    UKDoesNotRaiseException([compaction compute]);
    UKDoesNotRaiseException([store compactHistory: compaction]);
    UKIntsEqual(1, track.nodes.count);

    object.persistentRoot.deleted = YES;
    [ctx commitWithUndoTrack: concreteTrack2];

    /* Undo Deletion */

    [track undo];

    compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.nodes.lastObject];

    UKIntsEqual(2, track.nodes.count);
    UKDoesNotRaiseException([compaction compute]);
    UKDoesNotRaiseException([store compactHistory: compaction]);
    UKIntsEqual(2, track.nodes.count);

    /* Redo Deletion */

    [track redo];

    compaction =
        [[COUndoTrackHistoryCompaction alloc] initWithUndoTrack: track
                                                    upToCommand: (COCommandGroup *)track.nodes.lastObject];

    UKIntsEqual(2, track.nodes.count);
    UKDoesNotRaiseException([compaction compute]);
    UKDoesNotRaiseException([store compactHistory: compaction]);
    UKIntsEqual(1, track.nodes.count);

    UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], track.currentNode);
}

@end
