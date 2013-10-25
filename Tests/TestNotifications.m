#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestNotifications : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
}
@end

@implementation TestNotifications

- (id) init
{
    SUPERINIT;

    persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot rootObject] setLabel: @"hello"];
    [ctx commit];

    return self;
}

#if 0
- (void)testPersistentRootNotificationOnUndoLocal
{
    COUndoTrack *track = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    [track clear];
    
    [[persistentRoot rootObject] setLabel: @"world"];
    [ctx commitWithUndoTrack: track];
    
	[self checkBlock: ^(){
		[track undo];
	} postsNotification: COPersistentRootDidChangeNotification withCount: 1 fromObject: persistentRoot withUserInfo: nil];
}

- (void)testPersistentRootNotificationOnCommitInnerObjectChangesLocal
{
	[self checkBlock: ^(){
		[[persistentRoot rootObject] setLabel: @"world"];
		[ctx commit];
	} postsNotification: COPersistentRootDidChangeNotification withCount: 1 fromObject: persistentRoot withUserInfo: nil];
	
	[self checkBlock: ^(){
		[[persistentRoot rootObject] setLabel: @"world"];
		[persistentRoot discardAllChanges];
	} postsNotification: COPersistentRootDidChangeNotification withCount: 0 fromObject: persistentRoot withUserInfo: nil];
}

- (void)testPersistentRootNotificationOnCommitInnerObjectChangesRemote
{
	[self checkBlock: ^(){
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *persistentRoot2 = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		[[persistentRoot2 rootObject] setLabel: @"world"];
		[ctx2 commit];
		
		[self wait];
	} postsNotification: COPersistentRootDidChangeNotification withCount: 1 fromObject: persistentRoot withUserInfo: nil];
}
#endif

// COEditingContext notifications

- (void)testEditingContextNotificationOnCommitInnerObjectChangesLocal
{
	[self checkBlock: ^(){
		[[persistentRoot rootObject] setLabel: @"world"];
		[ctx commit];
	} postsNotification: COEditingContextDidChangeNotification withCount: 1 fromObject: ctx	withUserInfo: nil];
	
	[self checkBlock: ^(){
		[[persistentRoot rootObject] setLabel: @"world"];
		[ctx discardAllChanges];
	} postsNotification: COEditingContextDidChangeNotification withCount: 0 fromObject: ctx	withUserInfo: nil];
}

#if 0
- (void)testEditingContextNotificationOnCommitInnerObjectChangesRemote
{
	[self checkBlock: ^(){
		COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
		COPersistentRoot *persistentRoot2 = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		[[persistentRoot2 rootObject] setLabel: @"world"];
		[ctx2 commit];
		
		[self wait];
	} postsNotification: COEditingContextDidChangeNotification withCount: 1 fromObject: ctx	withUserInfo: nil];
}
#endif

- (void)testEditingContextNotificationOnInsertPersistentRoot
{
	[self checkBlock: ^(){
		[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
		[ctx commit];
	} postsNotification: COEditingContextDidChangeNotification withCount: 1 fromObject: ctx	withUserInfo: nil];
	
	[self checkBlock: ^(){
		[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
		[ctx discardAllChanges];
	} postsNotification: COEditingContextDidChangeNotification withCount: 0 fromObject: ctx	withUserInfo: nil];
}

- (void)testEditingContextNotificationOnDeletePersistentRoot
{
	[self checkBlock: ^(){
		persistentRoot.deleted = YES;
		[ctx commit];
	} postsNotification: COEditingContextDidChangeNotification withCount: 1 fromObject: ctx	withUserInfo: nil];
	
	[self checkBlock: ^(){
		persistentRoot.deleted = YES;
		[ctx discardAllChanges];
	} postsNotification: COEditingContextDidChangeNotification withCount: 0 fromObject: ctx	withUserInfo: nil];
}

- (void)testEditingContextNotificationOnUndeletePersistentRoot
{
	persistentRoot.deleted = YES;
	[ctx commit];
	
	[self checkBlock: ^(){
		persistentRoot.deleted = NO;
		[ctx commit];
	} postsNotification: COEditingContextDidChangeNotification withCount: 1 fromObject: ctx	withUserInfo: nil];
	
	[self checkBlock: ^(){
		persistentRoot.deleted = NO;
		[ctx discardAllChanges];
	} postsNotification: COEditingContextDidChangeNotification withCount: 0 fromObject: ctx	withUserInfo: nil];
}

@end
