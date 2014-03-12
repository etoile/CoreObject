/*
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  December 2010
    License:  MIT  (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COObject+Private.h"
#import "COObject+RelationshipCache.h"
#import "COPersistentRoot.h"
#import "COSQLiteStore.h"
#import "TestCommon.h"
#import "COObjectGraphContext+Private.h"

NSString * const kCOLabel = @"label";
NSString * const kCOContents = @"contents";
NSString * const kCOParent = @"parentContainer";

@implementation TestCase

- (void) checkObjectGraphBeforeAndAfterSerializationRoundtrip: (COObjectGraphContext *)anObjectGraph
													  inBlock: (void (^)(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy))block
{
	block(anObjectGraph, [anObjectGraph rootObject], NO);
	
	NSData *data = COItemGraphToJSONData(anObjectGraph);
	COItemGraph *deseriazlied = COItemGraphFromJSONData(data);
	
	COObjectGraphContext *deserializedContext = [[COObjectGraphContext alloc] init];
	[deserializedContext setItemGraph: deseriazlied];
	[deserializedContext removeUnreachableObjects];
	
	block(deserializedContext, [deserializedContext rootObject], YES);
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

- (void)	checkBlock: (void (^)(void))block
doesNotPostNotification: (NSString *)notif
{
	[self checkBlock: block postsNotification: notif withCount: 0 fromObject: nil withUserInfo: nil];
}

@end

@implementation SQLiteStoreTestCase

- (id) init
{
    self = [super init];
    
    store = [[COSQLiteStore alloc] initWithURL: [SQLiteStoreTestCase storeURL]];
    [store clearStore];
    
    return self;
}

- (void) dealloc
{
#ifdef DELETE_STORE_AFTER_EACH_TEST_METHOD
	// FIXME: For Mac OS X 10.7, this is unsupported, SQLite disk errors
	// (DB Error: 10 "disk I/O error") appear in TestStoreSQLite.m.
	[[self class] deleteStore];
#endif
}

+ (void) deleteStore
{
	BOOL isDir = NO;

	if ([[NSFileManager defaultManager] fileExistsAtPath: [[self storeURL] path]
	                                         isDirectory: &isDir] && isDir)
	{
		NSError *error = nil;

		[[NSFileManager defaultManager] removeItemAtURL: [self storeURL] error: &error];
		ETAssert(error == nil);
	}
}

+ (NSURL *) storeURL
{
#ifdef IN_MEMORY_STORE
	return [NSURL fileURLWithPath: @"/tmp/coreobject-ramdisk/TestStore.sqlite"];
#else
	return [NSURL fileURLWithPath: [@"~/TestStore.sqlite" stringByExpandingTildeInPath]];
#endif
}

- (void) checkPersistentRoot: (ETUUID *)aPersistentRoot
					 current: (ETUUID *)expectedCurrent
						head: (ETUUID *)expectedHead
{
	COPersistentRootInfo *info = [store persistentRootInfoForUUID: aPersistentRoot];
	return [self checkBranch: info.currentBranchUUID
					 current: expectedCurrent
						head: expectedHead];
}

- (void) checkBranch: (ETUUID *)aBranch
			 current: (ETUUID *)expectedCurrent
				head: (ETUUID *)expectedHead
{
	ETUUID *persistentRoot = [store persistentRootUUIDForBranchUUID: aBranch];
	COPersistentRootInfo *info = [store persistentRootInfoForUUID: persistentRoot];
	COBranchInfo *branchInfo = [info branchInfoForUUID: aBranch];
	
	UKNotNil(branchInfo);
	
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

- (COItemGraph *) currentItemGraphForBranch: (ETUUID *)aBranch
{
	return [self currentItemGraphForBranch: aBranch store: store];
}

- (COItemGraph *) currentItemGraphForBranch: (ETUUID *)aBranch
									  store: (COSQLiteStore *)aStore
{
	ETUUID *persistentRoot = [aStore persistentRootUUIDForBranchUUID: aBranch];
	COPersistentRootInfo *info = [aStore persistentRootInfoForUUID: persistentRoot];
	COBranchInfo *branchInfo = [info branchInfoForUUID: aBranch];
	
	return [store itemGraphForRevisionUUID: branchInfo.currentRevisionUUID
							persistentRoot: persistentRoot];
}

- (COItemGraph *) currentItemGraphForPersistentRoot: (ETUUID *)aPersistentRoot
{
	return [self currentItemGraphForPersistentRoot: aPersistentRoot store: store];
}

- (COItemGraph *) currentItemGraphForPersistentRoot: (ETUUID *)aPersistentRoot
											  store: (COSQLiteStore *)aStore
{
	COPersistentRootInfo *info = [aStore persistentRootInfoForUUID: aPersistentRoot];
	
	return [aStore itemGraphForRevisionUUID: info.currentRevisionUUID
							persistentRoot: aPersistentRoot];
}

@end

@implementation EditingContextTestCase

+ (void) willRunTestSuite
{
	[SQLiteStoreTestCase deleteStore];

	// NOTE: We are about to initialize every loaded class. Make sure
	// NSApplication is created first or various other gui classes on GNUstep
	// will throw exceptions.
	[NSApplication sharedApplication];
}

+ (void) didRunTestSuite
{
	[SQLiteStoreTestCase deleteStore];
	
	// Run a runloop so we handle any outstanding notifications, so
	// we can check for leaks afterwards.
	
	@autoreleasepool
	{
		NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
		[runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	}

#ifdef FMDatabase_DEBUG

	// Count up the number of open sqlite database connections at this
	// point.
	//
	// As of 2014-01-24, there are 3 open connections:
	//
	//  - In TestSynchronizer, -testBasicServerRevert and -testBasicClientRevert each leak a store.
	//    (I don't understand why, but they're not so serious because
	//     they only happen when throwing an exception in response to incorrect API usage.)
	//
	//  - +[COUndoTrackStore defaultStore] intentionally opens and never closes a database connection
	//    to the ~/Library/CoreObject/Undo/undo.sqlite database

	@autoreleasepool
	{
		[FMDatabase logOpenDatabases];

		const int expectedOpenDatabases = 3;
		if ([FMDatabase countOfOpenDatabases] > expectedOpenDatabases)
		{
			NSLog(@"ERROR: Expected only %d SQLite database connections to still be open.", expectedOpenDatabases);
			UKFail();
		}
	}

#endif
}

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
    [runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
}

@end

@implementation COObjectGraphContext (TestCommon)

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
    ETEntityDescription *desc = [[self modelDescriptionRepository] descriptionForName: aFullName];
    if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	Class objClass = [[self modelDescriptionRepository] classForEntityDescription: desc];
    
    /* Nil root object means the new object will be a root */
	COObject *obj = [[objClass alloc] initWithEntityDescription: desc
                                             objectGraphContext: self];
    
	return obj;
}

@end

@implementation COObject (TestCommon)

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	NSIndexSet *indexes =
		(index != ETUndeterminedIndex ? [NSIndexSet indexSetWithIndex: index] : [NSIndexSet indexSet]);
	
	[self insertObjects: (object != nil ? A(object) : [NSArray array])
	          atIndexes: indexes
	              hints: (hint != nil ? A(hint) : nil)
	        forProperty: key];
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	NSIndexSet *indexes =
		(index != ETUndeterminedIndex ? [NSIndexSet indexSetWithIndex: index] : [NSIndexSet indexSet]);
	
	[self removeObjects: (object != nil ? A(object) : [NSArray array])
	          atIndexes: indexes
	              hints: (hint != nil ? A(hint) : nil)
	        forProperty: key];
}

@end
