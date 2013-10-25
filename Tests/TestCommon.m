#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COObject+Private.h"
#import "COObject+RelationshipCache.h"
#import "COPersistentRoot.h"
#import "COSQLiteStore.h"
#import "TestCommon.h"

NSString * const kCOLabel = @"label";
NSString * const kCOContents = @"contents";
NSString * const kCOParent = @"parentContainer";

@implementation SQLiteStoreTestCase

+ (void) initialize
{
    if (self == [SQLiteStoreTestCase class])
    {
        [self deleteStore];
    }
}

- (id) init
{
    self = [super init];
    
    store = [[COSQLiteStore alloc] initWithURL: [SQLiteStoreTestCase storeURL]];
    [store clearStore];
    
    return self;
}

+ (void) deleteStore
{
	[[NSFileManager defaultManager] removeItemAtURL: [self storeURL] error: NULL];
}

+ (NSURL *) storeURL
{
	return [NSURL fileURLWithPath: [@"~/TestStore.sqlite" stringByExpandingTildeInPath]];
}

- (void) checkPersistentRoot: (ETUUID *)aPersistentRoot
		  hasInitialRevision: (ETUUID *)expectedInitial
					 current: (ETUUID *)expectedCurrent
						head: (ETUUID *)expectedHead
{
	COPersistentRootInfo *info = [store persistentRootInfoForUUID: aPersistentRoot];
	return [self checkBranch: info.currentBranchUUID
		  hasInitialRevision: expectedInitial
					 current: expectedCurrent
						head: expectedHead];
}

- (void) checkBranch: (ETUUID *)aBranch
  hasInitialRevision: (ETUUID *)expectedInitial
			 current: (ETUUID *)expectedCurrent
				head: (ETUUID *)expectedHead
{
	ETUUID *persistentRoot = [store persistentRootUUIDForBranchUUID: aBranch];
	COPersistentRootInfo *info = [store persistentRootInfoForUUID: persistentRoot];
	COBranchInfo *branchInfo = [info branchInfoForUUID: aBranch];
	
	UKNotNil(branchInfo);
	
	if (expectedInitial == nil)
	{
		UKNil(branchInfo.initialRevisionUUID);
	}
	else
	{
		UKObjectsEqual(expectedInitial, branchInfo.initialRevisionUUID);
	}

	if (expectedCurrent == nil)
	{
		UKNil(branchInfo.currentRevisionUUID);
	}
	else
	{
		UKObjectsEqual(expectedCurrent, branchInfo.currentRevisionUUID);
	}
	
	if (expectedHead == nil)
	{
		UKNil(branchInfo.headRevisionUUID);
	}
	else
	{
		UKObjectsEqual(expectedHead, branchInfo.headRevisionUUID);
	}
}

- (void)	checkBlock: (void (^)(void))block
  postsNotification: (NSString *)notif
		  withCount: (NSUInteger)count
		 fromObject: (id)sender
	   withUserInfo: (NSDictionary *)expectedUserInfo
{
    __block int timesNotified = 0;
	
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName: notif
                                                                    object: sender
                                                                     queue: nil
                                                                usingBlock: ^(NSNotification *notif) {
																	for (NSString *key in expectedUserInfo)
																	{
																		UKObjectsEqual(expectedUserInfo[key], notif.userInfo[key]);
																	}
																	timesNotified++;
																}];
    
	block();
    
    [[NSNotificationCenter defaultCenter] removeObserver: observer];
	
    UKIntsEqual(count, timesNotified);
}

- (COItemGraph *) currentItemGraphForBranch: (ETUUID *)aBranch
{
	ETUUID *persistentRoot = [store persistentRootUUIDForBranchUUID: aBranch];
	COPersistentRootInfo *info = [store persistentRootInfoForUUID: persistentRoot];
	COBranchInfo *branchInfo = [info branchInfoForUUID: aBranch];
	
	return [store itemGraphForRevisionUUID: branchInfo.currentRevisionUUID
							persistentRoot: persistentRoot];
}

- (COItemGraph *) currentItemGraphForPersistentRoot: (ETUUID *)aPersistentRoot
{
	COPersistentRootInfo *info = [store persistentRootInfoForUUID: aPersistentRoot];
	
	return [store itemGraphForRevisionUUID: info.currentRevisionUUID
							persistentRoot: aPersistentRoot];
}

@end

@implementation EditingContextTestCase

- (id) init
{
	SUPERINIT;
	ctx = [[COEditingContext alloc] initWithStore: store];
    return self;
}

- (void) checkBranchWithExistingAndNewContext: (COBranch *)aBranch
									 inBlock: (void (^)(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext))block
{
	block([aBranch editingContext], [aBranch persistentRoot], aBranch, NO);
	
	// Create a second, isolated context that opens a new store object
	// at the current one's URL
	
	COEditingContext *ctx2 = [COEditingContext contextWithURL: [[[aBranch persistentRoot] store] URL]];
	COPersistentRoot *ctx2PersistentRoot = [ctx2 persistentRootForUUID: [[aBranch persistentRoot] UUID]];
	COBranch *ctx2Branch = [ctx2PersistentRoot branchForUUID: [aBranch UUID]];
	
	// Run the tests again
	
	block(ctx2, ctx2PersistentRoot, ctx2Branch, YES);
}

- (void) checkPersistentRootWithExistingAndNewContext: (COPersistentRoot *)aPersistentRoot
											 inBlock: (void (^)(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext))block
{
	// N.B. This method is not merely a wrapper around -testBranchWithExistingAndNewContext:
	// because for the second execution of the block I want to pass in the current branch that
	// was persistent.
	
	block([aPersistentRoot editingContext], aPersistentRoot, [aPersistentRoot currentBranch], NO);
	
	// Create a second, isolated context that opens a new store object
	// at the current one's URL
	
	COEditingContext *ctx2 = [COEditingContext contextWithURL: [[aPersistentRoot store] URL]];
	COPersistentRoot *ctx2PersistentRoot = [ctx2 persistentRootForUUID: [aPersistentRoot UUID]];
	COBranch *ctx2Branch = [ctx2PersistentRoot currentBranch];
	
	// Run the tests again
	
	block(ctx2, ctx2PersistentRoot, ctx2Branch, YES);
}

- (void) wait
{
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
}

@end

@implementation COObjectGraphContext (TestCommon)

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
    ETEntityDescription *desc = [[self modelRepository] descriptionForName: aFullName];
    if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	Class objClass = [[self modelRepository] classForEntityDescription: desc];
    
    /* Nil root object means the new object will be a root */
	COObject *obj = [[objClass alloc] initWithEntityDescription: desc
                                             objectGraphContext: self];
    
	return obj;
}

@end
