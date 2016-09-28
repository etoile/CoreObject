/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

#define TEST_TRACK @"TestUndoTrack"
#define TEST_TRACK_2 @"TestUndoTrack2"
#define TEST_TRACK_STAR @"TestUndoTrack*"

static COEndOfUndoTrackPlaceholderNode *placeholderNode = nil;

@interface TestUndoTrack : EditingContextTestCase <UKTest>
{
    COUndoTrack *_track;
    COUndoTrack *_track2;
    COUndoTrack *_patternTrack;
    COPersistentRoot *_persistentRoot;
    NSUInteger _trackNotificationCount;
    NSUInteger _track2NotificationCount;
    NSUInteger _patternTrackNotificationCount;
}

@end


@implementation TestUndoTrack

+ (void)initialize
{
    if (self != [TestUndoTrack class])
        return;

    placeholderNode = [COEndOfUndoTrackPlaceholderNode sharedInstance];
}

#pragma mark - test infrastructure

- (void)checkSettingCurrentNodeOfTrack: (COUndoTrack *)aTrack
                                    to: (id <COTrackNode>)aNode
                           undoesNodes: (NSArray *)undoNodes
                           redoesNodes: (NSArray *)redoNodes
{

}

- (void)trackDidChange: (NSNotification *)notif
{
    UKStringsEqual(COUndoTrackDidChangeNotification, notif.name);

    if (notif.object == _track)
    {
        _trackNotificationCount++;
    }
    else if (notif.object == _track2)
    {
        _track2NotificationCount++;
    }
    else if (notif.object == _patternTrack)
    {
        _patternTrackNotificationCount++;
    }
    else
    {
        ETAssertUnreachable();
    }
}

/**
 * Returns a new recordable and inversible command group that can be passed to 
 * -undoNode: and -redoNode:.
 *
 * On return, the command effects are already committed (but not recorded on any 
 * undo track yet).
 *
 * An empty command is inversible but not recordable, see 
 * -[COEditingContext recordEndUndoGroupWithUndoTrack:].
 *
 * To be recordable, a command must also causes changes in the editing context 
 * when applied to it.
 */
- (COCommandGroup *)switchToNewBranch
{
    COCommandGroup *group = [COCommandGroup new];
    COCommandSetCurrentBranch *command = [COCommandSetCurrentBranch new];

    if (_persistentRoot == nil)
    {
        _persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
        [ctx commit];
    }

    ETUUID *oldBranchUUID = _persistentRoot.currentBranch.UUID;
    COBranch *newBranch = [_persistentRoot.currentBranch makeBranchWithLabel: @"Untitled"];

    _persistentRoot.currentBranch = newBranch;
    [ctx commit];
    ETAssert([_persistentRoot.currentBranch.UUID isEqual: newBranch.UUID]);

    command.storeUUID = ctx.store.UUID;
    command.persistentRootUUID = _persistentRoot.UUID;
    command.oldBranchUUID = oldBranchUUID;
    command.branchUUID = newBranch.UUID;

    group.contents = [@[command] mutableCopy];

    return group;
}

#pragma mark - tests

- (instancetype)init
{
    SUPERINIT;

    _track = [COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx];
    [_track clear];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(trackDidChange:)
                                                 name: COUndoTrackDidChangeNotification
                                               object: _track];

    _track2 = [COUndoTrack trackForName: TEST_TRACK_2 withEditingContext: ctx];
    [_track2 clear];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(trackDidChange:)
                                                 name: COUndoTrackDidChangeNotification
                                               object: _track2];

    _patternTrack = [COUndoTrack trackForPattern: TEST_TRACK_STAR withEditingContext: ctx];
    [_patternTrack clear];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(trackDidChange:)
                                                 name: COUndoTrackDidChangeNotification
                                               object: _patternTrack];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)testEmptyTrack
{
    UKObjectsEqual(A(placeholderNode), _track.nodes);
    UKObjectsEqual(placeholderNode, _track.currentNode);
}

- (void)testEmptyTrackSetCurrentNode
{
    UKDoesNotRaiseException([_track setCurrentNode: placeholderNode]);
    UKObjectsEqual(placeholderNode, _track.currentNode);
}

- (void)testSingleRecord
{
    COCommandGroup *group = [[COCommandGroup alloc] init];
    [_track recordCommand: group];

    UKObjectsEqual(A(placeholderNode, group), _track.nodes);
    UKObjectsEqual(group, [_track currentNode]);

    /* -recordCommand: reloads the track before recording the command */
    UKIntsEqual(2, _trackNotificationCount);
    UKIntsEqual(0, _track2NotificationCount);
    UKIntsEqual(1, _patternTrackNotificationCount);

    // Check with a second COUndoTrack

    COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK
                                              withEditingContext: ctx];
    UKObjectsNotSame(_track, secondTrackInstance);
    UKObjectsEqual(A(placeholderNode, group), secondTrackInstance.nodes);
    UKObjectsEqual(group, [secondTrackInstance currentNode]);
}

- (void)testFirstCommandParent
{
    COCommandGroup *group = [[COCommandGroup alloc] init];
    [_track recordCommand: group];

    UKObjectsEqual(placeholderNode, [group parentNode]);
    UKObjectsEqual(placeholderNode.UUID, [group parentUUID]);
}

- (void)testTwoRecords
{
    COCommandGroup *group1 = [[COCommandGroup alloc] init];
    COCommandGroup *group2 = [[COCommandGroup alloc] init];
    [_track recordCommand: group1];
    [_track recordCommand: group2];

    UKObjectsEqual(A(placeholderNode, group1, group2), _track.nodes);
    UKObjectsEqual(group2, [_track currentNode]);
    UKObjectsEqual(group1.UUID, group2.parentUUID);

    /* -recordCommand: reloads the track before recording the command */
    UKIntsEqual(3, _trackNotificationCount);
    UKIntsEqual(0, _track2NotificationCount);
    UKIntsEqual(2, _patternTrackNotificationCount);

    // Check with a second COUndoTrack

    COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK
                                              withEditingContext: ctx];
    UKObjectsNotSame(_track, secondTrackInstance);
    UKObjectsEqual(A(placeholderNode, group1, group2), secondTrackInstance.nodes);
    UKObjectsEqual(group2, [secondTrackInstance currentNode]);
    UKObjectsEqual(group1.UUID, [(COCommandGroup *)[secondTrackInstance currentNode] parentUUID]);

    // Check in the store

    COUndoTrackState *state = [_track.store stateForTrackName: TEST_TRACK];
    UKObjectsEqual(TEST_TRACK, state.trackName);
    UKObjectsEqual(group2.UUID, state.headCommandUUID);
    UKObjectsEqual(group2.UUID, state.currentCommandUUID);
}

- (void)testUndoAndRedoOneNode
{
    COCommandGroup *group1 = [[COCommandGroup alloc] init];
    COCommandGroup *group2 = [[COCommandGroup alloc] init];
    [_track recordCommand: group1];
    [_track recordCommand: group2];

    [_track setCurrentNode: group1];

    UKObjectsEqual(group1, [_track currentNode]);

    /* -recordCommand: reloads the track before recording the command */
    UKIntsEqual(4, _trackNotificationCount);
    UKIntsEqual(0, _track2NotificationCount);
    UKIntsEqual(3, _patternTrackNotificationCount);

    // Check with a second COUndoTrack
    {
        COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK
                                                  withEditingContext: ctx];
        UKObjectsEqual(A(placeholderNode, group1, group2), secondTrackInstance.nodes);
        UKObjectsEqual(group1, [secondTrackInstance currentNode]);
        UKObjectsEqual(placeholderNode.UUID,
                       [(COCommandGroup *)[secondTrackInstance currentNode] parentUUID]);
    }

    [_track setCurrentNode: group2];

    UKObjectsEqual(group2, [_track currentNode]);

    {
        COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK
                                                  withEditingContext: ctx];
        UKObjectsEqual(group2, [secondTrackInstance currentNode]);
    }
}

- (void)testDivergentCommands
{
    COCommandGroup *group1 = [[COCommandGroup alloc] init];
    COCommandGroup *group1a = [[COCommandGroup alloc] init];
    COCommandGroup *group1b = [[COCommandGroup alloc] init];

    [_track recordCommand: group1];
    [_track recordCommand: group1a];
    [_track setCurrentNode: group1];
    [_track recordCommand: group1b];

    UKObjectsEqual(A(placeholderNode, group1, group1b), _track.nodes);
    UKObjectsEqual(S(group1, group1a, group1b), SA([_track allCommands]));
    UKIntsEqual(3, S(group1, group1a, group1b).count);
}

- (void)testSetCurrentNodeToDivergentNode
{
    COCommandGroup *group1 = [[COCommandGroup alloc] init];
    COCommandGroup *group1a = [[COCommandGroup alloc] init];
    COCommandGroup *group1b = [[COCommandGroup alloc] init];

    [_track recordCommand: group1];
    [_track recordCommand: group1a];
    [_track setCurrentNode: group1];
    [_track recordCommand: group1b];

    UKObjectsEqual(group1, group1a.parentNode);
    UKObjectsEqual(group1, group1b.parentNode);
    UKObjectsEqual(placeholderNode, group1.parentNode);

    UKObjectsEqual(group1.UUID, group1a.parentUUID);
    UKObjectsEqual(group1.UUID, group1b.parentUUID);
    UKObjectsEqual(placeholderNode.UUID, group1.parentUUID);

    UKObjectsEqual(A(placeholderNode, group1, group1b), _track.nodes);

    [_track setCurrentNode: group1a];

    UKObjectsEqual(A(placeholderNode, group1, group1a), _track.nodes);
}

- (void)testDivergentNodesWhereCommonAncestorIsPlaceholderNode
{
    COCommandGroup *group1a = [[COCommandGroup alloc] init];
    COCommandGroup *group1b = [[COCommandGroup alloc] init];

    [_track recordCommand: group1a];
    UKObjectsEqual(placeholderNode, group1a.parentNode);
    UKObjectsEqual(placeholderNode.UUID, group1a.parentUUID);
    UKObjectsEqual(A(placeholderNode, group1a), _track.nodes);
    UKObjectsEqual(group1a, _track.currentNode);

    [_track setCurrentNode: placeholderNode];
    UKObjectsEqual(A(placeholderNode, group1a), _track.nodes);
    UKObjectsEqual(placeholderNode, _track.currentNode);

    [_track recordCommand: group1b];
    UKObjectsEqual(placeholderNode, group1b.parentNode);
    UKObjectsEqual(placeholderNode.UUID, group1b.parentUUID);
    UKObjectsEqual(A(placeholderNode, group1b), _track.nodes);
    UKObjectsEqual(group1b, _track.currentNode);

    [_track setCurrentNode: group1a];
    UKObjectsEqual(A(placeholderNode, group1a), _track.nodes);
    UKObjectsEqual(group1a, _track.currentNode);
}

- (void)testNavigateToDivergentNodesFromPlaceholderNode
{
    COCommandGroup *group1a = [[COCommandGroup alloc] init];
    COCommandGroup *group1b = [[COCommandGroup alloc] init];

    [_track recordCommand: group1a];
    [_track setCurrentNode: placeholderNode];
    [_track recordCommand: group1b];
    [_track setCurrentNode: placeholderNode];

    UKObjectsEqual(A(placeholderNode, group1b), _track.nodes);

    [_track setCurrentNode: group1a];

    UKObjectsEqual(A(placeholderNode, group1a), _track.nodes);
    UKObjectsEqual(group1a, _track.currentNode);
}

- (void)testUndoOnPatternTrack
{
    UKObjectsEqual(A(placeholderNode), _patternTrack.nodes);

    COCommandGroup *group1a = [[COCommandGroup alloc] init];
    COCommandGroup *group1b = [[COCommandGroup alloc] init];
    COCommandGroup *group2a = [[COCommandGroup alloc] init];
    COCommandGroup *group2b = [[COCommandGroup alloc] init];

    [_track recordCommand: group1a];
    UKObjectsEqual(A(placeholderNode, group1a), _patternTrack.nodes);

    [_track2 recordCommand: group2a];
    UKObjectsEqual(A(placeholderNode, group1a, group2a), _patternTrack.nodes);

    [_track recordCommand: group1b];
    UKObjectsEqual(A(placeholderNode, group1a, group2a, group1b), _patternTrack.nodes);

    [_track2 recordCommand: group2b];
    UKObjectsEqual(A(placeholderNode, group1a, group2a, group1b, group2b), _patternTrack.nodes);

    [_patternTrack undo];

    UKObjectsEqual(group1b, [_track currentNode]);
    UKObjectsEqual(group2a, [_track2 currentNode]);
    UKObjectsEqual(group1b, [_patternTrack currentNode]);
    UKObjectsEqual(group1b,
                   [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
    UKObjectsEqual(group2a, [[COUndoTrack trackForName: TEST_TRACK_2
                                    withEditingContext: ctx] currentNode]);
    UKObjectsEqual(group1b, [[COUndoTrack trackForName: TEST_TRACK_STAR
                                    withEditingContext: ctx] currentNode]);

    [_patternTrack undo];

    UKObjectsEqual(group1a, [_track currentNode]);
    UKObjectsEqual(group2a, [_track2 currentNode]);
    UKObjectsEqual(group2a, [_patternTrack currentNode]);
    UKObjectsEqual(group1a,
                   [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
    UKObjectsEqual(group2a, [[COUndoTrack trackForName: TEST_TRACK_2
                                    withEditingContext: ctx] currentNode]);
    UKObjectsEqual(group2a, [[COUndoTrack trackForName: TEST_TRACK_STAR
                                    withEditingContext: ctx] currentNode]);

    [_patternTrack undo];

    UKObjectsEqual(group1a, [_track currentNode]);
    UKObjectsEqual(placeholderNode, [_track2 currentNode]);
    UKObjectsEqual(group1a, [_patternTrack currentNode]);
    UKObjectsEqual(group1a,
                   [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
    UKObjectsEqual(placeholderNode, [[COUndoTrack trackForName: TEST_TRACK_2
                                            withEditingContext: ctx] currentNode]);
    UKObjectsEqual(group1a, [[COUndoTrack trackForName: TEST_TRACK_STAR
                                    withEditingContext: ctx] currentNode]);

    [_patternTrack undo];

    UKObjectsEqual(placeholderNode, [_track currentNode]);
    UKObjectsEqual(placeholderNode, [_track2 currentNode]);
    UKObjectsEqual(placeholderNode, [_patternTrack currentNode]);
    UKObjectsEqual(placeholderNode,
                   [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
    UKObjectsEqual(placeholderNode, [[COUndoTrack trackForName: TEST_TRACK_2
                                            withEditingContext: ctx] currentNode]);
    UKObjectsEqual(placeholderNode, [[COUndoTrack trackForName: TEST_TRACK_STAR
                                            withEditingContext: ctx] currentNode]);
}

/**
 * See pattern track related comment in -[COUndoTrack setCurrentNode:].
 */
- (void)testRedoOnPatternTrackReorderingNodes
{
    COCommandGroup *A = [[COCommandGroup alloc] init];
    COCommandGroup *B = [[COCommandGroup alloc] init];
    COCommandGroup *C = [[COCommandGroup alloc] init];
    COCommandGroup *D = [[COCommandGroup alloc] init];

    [_track recordCommand: A];
    [_track2 recordCommand: B];
    [_track2 recordCommand: C];

    [_patternTrack undo];

    [_track recordCommand: D];

    UKObjectsEqual(A(placeholderNode, A, B, D, C), _patternTrack.nodes);
    UKObjectsEqual(D, [_patternTrack currentNode]);

    [_patternTrack redo];

    UKObjectsEqual(A(placeholderNode, A, B, C, D), _patternTrack.nodes);
    UKObjectsEqual(D, [_patternTrack currentNode]);
}

/**
 * See pattern track related comment in -[COUndoTrack setCurrentNode:].
 */
- (void)testUndoOnPatternTrackReorderingNodes
{
    COCommandGroup *A = [[COCommandGroup alloc] init];
    COCommandGroup *B = [[COCommandGroup alloc] init];
    COCommandGroup *C = [[COCommandGroup alloc] init];
    COCommandGroup *D = [[COCommandGroup alloc] init];

    [_track recordCommand: A];
    [_track2 recordCommand: B];
    [_track2 recordCommand: C];

    [_patternTrack undo];

    [_track recordCommand: D];

    UKObjectsEqual(A(placeholderNode, A, B, D, C), _patternTrack.nodes);
    UKObjectsEqual(D, [_patternTrack currentNode]);

    [_patternTrack undo];

    UKObjectsEqual(A(placeholderNode, A, B, C, D), _patternTrack.nodes);
    UKObjectsEqual(B, [_patternTrack currentNode]);
}

- (void)testUndoOnPatternTrackObservedTracks
{
    COCommandGroup *group1a = [[COCommandGroup alloc] init];
    COCommandGroup *group1b = [[COCommandGroup alloc] init];
    COCommandGroup *group2a = [[COCommandGroup alloc] init];
    COCommandGroup *group2b = [[COCommandGroup alloc] init];

    [_track recordCommand: group1a];
    [_track2 recordCommand: group2a];
    [_track recordCommand: group1b];
    [_track2 recordCommand: group2b];

    // NOTE: This has the effect of reordering the commands in _patternTrack.nodes
    [_track undo];

    UKObjectsEqual(A(placeholderNode, group1a, group2a, group2b, group1b), _patternTrack.nodes);
    UKObjectsEqual(group2b, [_patternTrack currentNode]);

    [_track undo];

    UKObjectsEqual(A(placeholderNode, group2a, group2b, group1a, group1b), _patternTrack.nodes);
    UKObjectsEqual(group2b, [_patternTrack currentNode]);
}

- (void)testUndoNode
{
    COCommandGroup *group1 = [self switchToNewBranch];
    COCommandGroup *group2 = [self switchToNewBranch];

    [_track recordCommand: group1];
    [_track recordCommand: group2];
    [_track undoNode: (id <COTrackNode>)group1];

    COCommandGroup *undoGroup1 = _track.nodes.lastObject;

    UKObjectsNotEqual(group1, undoGroup1);
    UKObjectsEqual(group1.parentUndoTrack, undoGroup1.parentUndoTrack);
    UKObjectsEqual([group1 inverse].contents, undoGroup1.contents);
    UKObjectsEqual(group2, undoGroup1.parentNode);
    UKIntsEqual(group2.sequenceNumber + 1, undoGroup1.sequenceNumber);

    UKObjectsEqual(A(placeholderNode, group1, group2, undoGroup1), _track.nodes);
    UKObjectsEqual(undoGroup1, [_track currentNode]);

    /* -recordCommand: reloads the track before recording the command */
    UKIntsEqual(4, _trackNotificationCount);
    UKIntsEqual(0, _track2NotificationCount);
    UKIntsEqual(3, _patternTrackNotificationCount);
}

- (void)testUndoNodeOnPatternTrack
{
    COCommandGroup *group1 = [self switchToNewBranch];
    COCommandGroup *group2 = [self switchToNewBranch];

    [_track recordCommand: group1];
    [_track recordCommand: group2];
    [_patternTrack undoNode: _patternTrack.nodes[1]];

    COCommandGroup *undoGroup1 = _patternTrack.nodes.lastObject;

    UKObjectsEqual(undoGroup1, _track.nodes.lastObject);

    UKObjectsNotEqual(group1, undoGroup1);
    UKObjectsNotEqual(group1.parentUndoTrack, undoGroup1.parentUndoTrack);
    UKObjectsEqual([group1 inverse].contents, undoGroup1.contents);
    UKObjectsEqual(group2, undoGroup1.parentNode);
    UKIntsEqual(group2.sequenceNumber + 1, undoGroup1.sequenceNumber);

    UKObjectsEqual(A(placeholderNode, group1, group2, undoGroup1), _track.nodes);
    UKObjectsEqual(undoGroup1, [_track currentNode]);
    UKObjectsEqual(A(placeholderNode, group1, group2, undoGroup1), _patternTrack.nodes);
    UKObjectsEqual(undoGroup1, [_patternTrack currentNode]);

    /* -recordCommand: reloads the track before recording the command */
    UKIntsEqual(4, _trackNotificationCount);
    UKIntsEqual(0, _track2NotificationCount);
    UKIntsEqual(3, _patternTrackNotificationCount);
}

- (void)testRedoNode
{
    COCommandGroup *group1 = [self switchToNewBranch];
    COCommandGroup *group2 = [self switchToNewBranch];

    [_track recordCommand: group1];
    [_track recordCommand: group2];
    [_track redoNode: (id <COTrackNode>)group1];

    COCommandGroup *redoGroup1 = _track.nodes.lastObject;

    UKObjectsNotEqual(group1, redoGroup1);
    UKObjectsEqual(group1.parentUndoTrack, redoGroup1.parentUndoTrack);
    UKObjectsEqual(group1.contents, redoGroup1.contents);
    UKObjectsEqual(group2, redoGroup1.parentNode);
    UKIntsEqual(group2.sequenceNumber + 1, redoGroup1.sequenceNumber);

    UKObjectsEqual(A(placeholderNode, group1, group2, redoGroup1), _track.nodes);
    UKObjectsEqual(redoGroup1, [_track currentNode]);

    /* -recordCommand: reloads the track before recording the command */
    UKIntsEqual(4, _trackNotificationCount);
    UKIntsEqual(0, _track2NotificationCount);
    UKIntsEqual(3, _patternTrackNotificationCount);
}

- (void)testRedoNodeOnPatternTrack
{
    COCommandGroup *group1 = [self switchToNewBranch];
    COCommandGroup *group2 = [self switchToNewBranch];

    [_track recordCommand: group1];
    [_track recordCommand: group2];
    [_patternTrack redoNode: (id <COTrackNode>)group1];

    COCommandGroup *redoGroup1 = _patternTrack.nodes.lastObject;

    UKObjectsNotEqual(group1, redoGroup1);
    UKObjectsNotEqual(group1.parentUndoTrack, redoGroup1.parentUndoTrack);
    UKObjectsEqual(group1.contents, redoGroup1.contents);
    UKObjectsEqual(group2, redoGroup1.parentNode);
    UKIntsEqual(group2.sequenceNumber + 1, redoGroup1.sequenceNumber);

    UKObjectsEqual(A(placeholderNode, group1, group2, redoGroup1), _track.nodes);
    UKObjectsEqual(redoGroup1, [_track currentNode]);
    UKObjectsEqual(A(placeholderNode, group1, group2, redoGroup1), _patternTrack.nodes);
    UKObjectsEqual(redoGroup1, [_patternTrack currentNode]);

    /* -recordCommand: reloads the track before recording the command */
    UKIntsEqual(4, _trackNotificationCount);
    UKIntsEqual(0, _track2NotificationCount);
    UKIntsEqual(3, _patternTrackNotificationCount);
}

// TODO: Test mixing commands between tracks illegally

@end
