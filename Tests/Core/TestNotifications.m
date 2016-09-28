/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestNotifications : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot1;
    COBranch *branch2;
    COPersistentRoot *persistentRoot2;
}

@end


@implementation TestNotifications

- (id)init
{
    SUPERINIT;

    persistentRoot1 = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    [persistentRoot1.rootObject setLabel: @"hello"];

    persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    [persistentRoot2.rootObject setLabel: @"hello2"];

    [ctx commit];

    branch2 = [persistentRoot1.currentBranch makeBranchWithLabel: @"branch2"];
    [ctx commit];

    return self;
}

- (void)testPersistentRootNotificationOnUndoLocal
{
    COUndoTrack *track = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    [track clear];

    [persistentRoot1.rootObject setLabel: @"world"];
    [ctx commitWithUndoTrack: track];

    [self    checkBlock: ^()
                         {
                            [track undo];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 1
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNotificationOnCommitInnerObjectChangesLocal
{
    [self    checkBlock: ^()
                         {
                             [persistentRoot1.rootObject setLabel: @"world"];
                             [ctx commit];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 1
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNoNotificationOnInnerObjectChangesLocal
{
    [self    checkBlock: ^()
                         {
                             [persistentRoot1.rootObject setLabel: @"world"];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 0
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNoNotificationOnDiscardChangesLocal
{
    [self    checkBlock: ^()
                         {
                             [persistentRoot1.rootObject setLabel: @"world"];
                             [persistentRoot1 discardAllChanges];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 0
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNotificationOnCommitInnerObjectChangesRemote
{
    [self    checkBlock: ^()
                         {
                             COEditingContext *ctx2 = [COEditingContext contextWithURL: store.URL];
                             COPersistentRoot *ctx2persistentRoot1 = [ctx2 persistentRootForUUID: persistentRoot1.UUID];
                             [ctx2persistentRoot1.rootObject setLabel: @"world"];
                             [ctx2 commit];

                             [self wait];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 1
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNotificationOnSetCurrentBranchLocal
{
    [self    checkBlock: ^()
                         {
                             persistentRoot1.currentBranch = branch2;
                             [ctx commit];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 1
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNoNotificationOnSetCurrentBranchLocal
{
    [self    checkBlock: ^()
                         {
                             persistentRoot1.currentBranch = branch2;
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 0
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNotificationOnDeleteBranchLocal
{
    [self    checkBlock: ^()
                         {
                             branch2.deleted = YES;
                             [ctx commit];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 1
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNoNotificationOnDeleteBranchLocal
{
    [self    checkBlock: ^()
                         {
                             branch2.deleted = YES;
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 0
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNoNotificationOnUndeleteBranchLocal
{
    branch2.deleted = YES;
    [ctx commit];

    [self    checkBlock: ^()
                         {
                             branch2.deleted = NO;
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 0
             fromObject: persistentRoot1
           withUserInfo: nil];
}

- (void)testPersistentRootNotificationOnUndeleteBranchLocal
{
    branch2.deleted = YES;
    [ctx commit];

    [self    checkBlock: ^()
                         {
                             branch2.deleted = NO;
                             [ctx commit];
                         }
      postsNotification: COPersistentRootDidChangeNotification
              withCount: 1
             fromObject: persistentRoot1
           withUserInfo: nil];
}

// COEditingContext notifications

- (void)testEditingContextNotificationOnCommitInnerObjectChangesLocal
{
    [self    checkBlock: ^()
                         {
                             [persistentRoot1.rootObject setLabel: @"world"];
                             [persistentRoot2.rootObject setLabel: @"world2"];
                             [ctx commit];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 1
             fromObject: ctx
           withUserInfo: nil];

    [self    checkBlock: ^()
                         {
                             [persistentRoot1.rootObject setLabel: @"world"];
                             [ctx discardAllChanges];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 0
             fromObject: ctx
           withUserInfo: nil];
}

- (void)testEditingContextNotificationOnCommitInnerObjectChangesRemote
{
    [self    checkBlock: ^()
                         {
                             COEditingContext *ctx2 = [COEditingContext contextWithURL: store.URL];
                             [[ctx2 persistentRootForUUID: persistentRoot1.UUID].rootObject setLabel: @"world"];
                             [[ctx2 persistentRootForUUID: persistentRoot2.UUID].rootObject setLabel: @"world2"];
                             [ctx2 commit];

                             [self wait];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 1
             fromObject: ctx
           withUserInfo: nil];
}

- (void)testEditingContextNotificationOnInsertPersistentRoot
{
    [self    checkBlock: ^()
                         {
                             [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
                             [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
                             [ctx commit];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 1
             fromObject: ctx
           withUserInfo: nil];

    [self    checkBlock: ^()
                         {
                             [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
                             [ctx discardAllChanges];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 0
             fromObject: ctx
           withUserInfo: nil];
}

- (void)testEditingContextNotificationOnDeletePersistentRoot
{
    [self    checkBlock: ^()
                         {
                             persistentRoot1.deleted = YES;
                             persistentRoot2.deleted = YES;
                             [ctx commit];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 1
             fromObject: ctx
           withUserInfo: nil];

    [self    checkBlock: ^()
                         {
                             persistentRoot1.deleted = YES;
                             [ctx discardAllChanges];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 0
             fromObject: ctx
           withUserInfo: nil];
}

- (void)testEditingContextNotificationOnUndeletePersistentRoot
{
    persistentRoot1.deleted = YES;
    persistentRoot2.deleted = YES;
    [ctx commit];

    [self    checkBlock: ^()
                         {
                             persistentRoot1.deleted = NO;
                             persistentRoot2.deleted = NO;
                             [ctx commit];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 1
             fromObject: ctx
           withUserInfo: nil];

    [self    checkBlock: ^()
                         {
                             persistentRoot1.deleted = NO;
                             [ctx discardAllChanges];
                         }
      postsNotification: COEditingContextDidChangeNotification
              withCount: 0
             fromObject: ctx
           withUserInfo: nil];
}

@end
