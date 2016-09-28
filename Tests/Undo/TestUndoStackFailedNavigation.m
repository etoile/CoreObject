/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestUndoTrackFailedNavigation : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
    COUndoTrack *track;

    id <COTrackNode> node1;
    id <COTrackNode> node2;
    id <COTrackNode> node3;
    id <COTrackNode> node4;
}

@end


@implementation TestUndoTrackFailedNavigation

- (id)init
{
    SUPERINIT;
    track = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    [track clear];

    // set root to "0" ---- not on undo track
    persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    [persistentRoot.rootObject setLabel: @"0"];
    [ctx commit];
    node1 = [track currentNode];

    // set root to "1"
    [persistentRoot.rootObject setLabel: @"1"];
    [ctx commitWithUndoTrack: track];
    node2 = [track currentNode];

    // set child to "a"
    OutlineItem *child1 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    child1.label = @"a";
    [persistentRoot.rootObject addObject: child1];
    [ctx commitWithUndoTrack: track];
    node3 = [track currentNode];

    // set child to "b"
    child1.label = @"b";
    [ctx commitWithUndoTrack: track];
    node4 = [track currentNode];

    // set root to "2" ---- not on undo track
    [persistentRoot.rootObject setLabel: @"2"];
    [ctx commit];

    // Since this last change is not recorded on the undo track,
    // any undo/redo using the track will be using selective undo.

    return self;
}

// TODO: Rewrite if we keep the new semantics (nov 21)
#if 0
- (void) testFailedNavigation
{
    UKObjectsEqual(node4, [track currentNode]);
    UKFalse([track setCurrentNode: node1]);
    UKObjectsEqual(node2, [track currentNode]);
}
#endif

@end
