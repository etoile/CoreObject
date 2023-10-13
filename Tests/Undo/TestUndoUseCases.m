/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

/**
 * These tests are simulate some real-world use cases, whereas TestUndo
 * tests feature-by-feature.
 */
@interface TestUndoUseCases : EditingContextTestCase <UKTest>
{
    COUndoTrack *_testTrack;
}

@end


@implementation TestUndoUseCases

- (instancetype)init
{
    SUPERINIT;

    _testTrack = [COUndoTrack trackForName: @"test" withContext: ctx];
    [_testTrack clear];

    return self;
}

/*
         ----r2b
        /
 r0---r1---r2---r3
 

 (starting state: r0)
 
 states visited:
 r1
 r2
 r3
 r1
 r2b
 
 */
- (void)testRevertAndMakeDivergentCommit
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    [ctx commit];
    CORevision *r0 = persistentRoot.currentRevision;

    [persistentRoot.rootObject setLabel: @"r1"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r1 = persistentRoot.currentRevision;

    [persistentRoot.rootObject setLabel: @"r2"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r2 = persistentRoot.currentRevision;

    [persistentRoot.rootObject setLabel: @"r3"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r3 = persistentRoot.currentRevision;

    persistentRoot.currentRevision = r1;
    [ctx commitWithUndoTrack: _testTrack];

    [persistentRoot.rootObject setLabel: @"r2b"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r2b = persistentRoot.currentRevision;

    [_testTrack undo];
    UKObjectsEqual(r1, persistentRoot.currentRevision);
    [_testTrack undo];
    UKObjectsEqual(r3, persistentRoot.currentRevision);
    [_testTrack undo];
    UKObjectsEqual(r2, persistentRoot.currentRevision);
    [_testTrack undo];
    UKObjectsEqual(r1, persistentRoot.currentRevision);
    [_testTrack undo];
    UKObjectsEqual(r0, persistentRoot.currentRevision);

    UKFalse(_testTrack.canUndo);

    [_testTrack redo];
    UKObjectsEqual(r1, persistentRoot.currentRevision);
    [_testTrack redo];
    UKObjectsEqual(r2, persistentRoot.currentRevision);
    [_testTrack redo];
    UKObjectsEqual(r3, persistentRoot.currentRevision);
    [_testTrack redo];
    UKObjectsEqual(r1, persistentRoot.currentRevision);
    [_testTrack redo];
    UKObjectsEqual(r2b, persistentRoot.currentRevision);

    UKFalse(_testTrack.canRedo);
}

- (void)checkPersistentRoot: (COPersistentRoot *)proot
         hasCurrentRevision: (CORevision *)currentExpected
                       head: (CORevision *)headExpected
{
    [self checkPersistentRootWithExistingAndNewContext: proot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           UKObjectsEqual(currentExpected,
                          testProot.currentRevision);
           UKObjectsEqual(headExpected,
                          testProot.headRevision);
       }];
}

/*
        ----r2b
       /
 r0---r1---r2---r3
 
 */
- (void)testUndoAndBranchNavigation
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    [ctx commit];

    [persistentRoot.rootObject setLabel: @"r1"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r1 = persistentRoot.currentRevision;

    [persistentRoot.rootObject setLabel: @"r2"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r2 = persistentRoot.currentRevision;

    [persistentRoot.rootObject setLabel: @"r3"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r3 = persistentRoot.currentRevision;

    [persistentRoot.currentBranch undo];
    [ctx commitWithUndoTrack: _testTrack];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r2 head: r3];

    [persistentRoot.currentBranch undo];
    [ctx commitWithUndoTrack: _testTrack];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r1 head: r3];

    [persistentRoot.rootObject setLabel: @"r2b"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *r2b = persistentRoot.currentRevision;

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r2b head: r2b];

    [persistentRoot.currentBranch undo];
    [ctx commitWithUndoTrack: _testTrack];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r1 head: r2b];

    [persistentRoot.currentBranch redo];
    [ctx commitWithUndoTrack: _testTrack];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r2b head: r2b];

    // Switch to using track undo, instead of branch navigation

    [_testTrack undo];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r1 head: r2b];

    [_testTrack undo];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r2b head: r2b];

    // The main point of the test is that the following -undo restores the
    // branch head_revid (-newestRevision) to point to r3, which means
    // [persistentRoot.currentBranch redo] moves towards r3 instead of r2b.

    [_testTrack undo];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r1 head: r3];

    [persistentRoot.currentBranch redo];
    [ctx commitWithUndoTrack: _testTrack];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r2 head: r3];

    [persistentRoot.currentBranch redo];
    [ctx commitWithUndoTrack: _testTrack];

    [self checkPersistentRoot: persistentRoot hasCurrentRevision: r3 head: r3];
}

@end
