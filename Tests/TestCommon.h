/*
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  December 2010
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import <CoreObject/CoreObject.h>

#import "COObjectGraphContext+GarbageCollection.h"
#import "COPrimitiveCollection.h"
#import "CODateSerialization.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

#import "COStoreTransaction.h"

#import "COCommandGroup.h"
#import "COCommandDeleteBranch.h"
#import "COCommandUndeleteBranch.h"
#import "COCommandSetBranchMetadata.h"
#import "COCommandSetCurrentBranch.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandDeletePersistentRoot.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COEndOfUndoTrackPlaceholderNode.h"

#import "OutlineItem.h"
#import "Tag.h"
#import "Parent.h"
#import "Child.h"
#import "Folder.h"
#import "FolderWithNoClass.h"
#import "OrderedGroupNoOpposite.h"
#import "UnivaluedGroupNoOpposite.h"
#import "UnorderedGroupNoOpposite.h"
#import "OrderedGroupWithOpposite.h"
#import "OrderedGroupContent.h"
#import "UnivaluedGroupWithOpposite.h"
#import "UnivaluedGroupContent.h"
#import "UnorderedGroupWithOpposite.h"
#import "UnorderedGroupContent.h"
#import "KeyedRelationshipModel.h"

#import "KeyedAttributeModel.h"
#import "OrderedAttributeModel.h"
#import "UnivaluedAttributeModel.h"
#import "UnorderedAttributeModel.h"

#import "ObjectWithTransientState.h"

#import "OverriddenIsEqualObject.h"

#import "COAttributedString.h"
#import "COAttributedStringChunk.h"
#import "COAttributedStringWrapper.h"
#import "COAttributedStringAttribute.h"
#import "COAttributedStringDiff.h"

#import "COPersistentRoot+Private.h"
#import "COBranch+Private.h"
#import "COSQLiteStore+Private.h"
#import "COObject+Private.h"
#import "COObjectGraphContext+Private.h"
#import "CORelationshipCache.h"
#import "COStoreTransaction.h"
#import "COObjectGraphContext+Graphviz.h"
#import "COEditingContext+Private.h"
#import "COMetamodel.h"
#import "COUndoTrackStore+Private.h"

#import "diff.h"

#define SA(x) [NSSet setWithArray: x]

extern NSString * const kCOLabel;
extern NSString * const kCOContents;
extern NSString * const kCOParent;

@interface TestCase : NSObject

/**
 * Execute the given block once with the provided objet graph context.
 * Then, serialize the object graph and load the serialized form in to a new
 * COObjectGraphContext instane, and re-run the tests in the block.
 */
- (void) checkObjectGraphBeforeAndAfterSerializationRoundtrip: (COObjectGraphContext *)anObjectGraph
													  inBlock: (void (^)(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy))block;
/**
 * Executes the provided block, and tests that the given notification type
 * is posted exactly count times from sender as a result.
 *
 * If expectedUserInfo is non-nil, test that each key/value pair in the dictionary
 * is also in [notif userInfo].
 */
- (void)	checkBlock: (void (^)(void))block
  postsNotification: (NSString *)notif
		  withCount: (NSUInteger)count
		 fromObject: (id)sender
	   withUserInfo: (NSDictionary *)expectedUserInfo;

- (void)	checkBlock: (void (^)(void))block
doesNotPostNotification: (NSString *)notif;

@end

/**
 * Base class for Core Object test classes that need a COSQLiteStore.
 */
@interface SQLiteStoreTestCase : TestCase
{
    COSQLiteStore *store;
}

/**
 * Returns the base URL in which all temporary files/stores used during
 * the test should be stored in.
 */
+ (NSURL *) temporaryURLForTestStorage;

/**
 * Same as +temporaryURLForTestStorage but returns a NSString path
 */
+ (NSString *) temporaryPathForTestStorage;

/**
 * Returns the URL used for the store.
 * This is a subdirectory of +temporaryDirectoryForTestStorage.
 */
+ (NSURL *)storeURL;
/**
 * Returns the URL used for the undo track store.
 * This is a subdirectory of +temporaryDirectoryForTestStorage.
 */
+ (NSURL *)undoTrackStoreURL;
/**
 * Deletes all saved datas related to the stores (this includes any undo track
 * store created with +undoTrackStoreURL).
 *
 * Saved datas are usually .sqlitedb files.
 */
+ (void)deleteStores;

- (void) checkPersistentRoot: (ETUUID *)aPersistentRoot
					 current: (ETUUID *)expectedCurrent
						head: (ETUUID *)expectedHead;

- (void) checkBranch: (ETUUID *)aBranch
			 current: (ETUUID *)expectedCurrent
				head: (ETUUID *)expectedHead;

- (COItemGraph *) currentItemGraphForBranch: (ETUUID *)aBranch;

- (COItemGraph *) currentItemGraphForBranch: (ETUUID *)aBranch
									  store: (COSQLiteStore *)aStore;

- (COItemGraph *) currentItemGraphForPersistentRoot: (ETUUID *)aPersistentRoot;

- (COItemGraph *) currentItemGraphForPersistentRoot: (ETUUID *)aPersistentRoot
											  store: (COSQLiteStore *)aStore;

@end

/**
 * Base class for Core Object test classes that test a COEditingContext
 */
@interface EditingContextTestCase : SQLiteStoreTestCase
{
	COEditingContext *ctx;
}

/**
 * Execute the given block once, passing in to the block the context and persistent
 * root of the provided branch. Then, open a new editing context and store object,
 * and run the block again.
 *
 * The intended use is for cases when you want to check some properties of an
 * editing context/persistent root/branch after a commit. If the commit was
 * successful, the observable state should be the same on the existing context
 * that made the commit, as well as a freshly created context.
 *
 * The isNewContext flag is NO when the block is executing with aBranch's
 * context/store, and YES when the block is executing with the reloaded context.
 */
- (void) checkBranchWithExistingAndNewContext: (COBranch *)aBranch
									  inBlock: (void (^)(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext))block;

/**
 * Same as above but uses the provided persistent root's current branch
 */
- (void) checkPersistentRootWithExistingAndNewContext: (COPersistentRoot *)aPersistentRoot
											  inBlock: (void (^)(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext))block;


/**
 * Runs the default runloop for a short period of time.
 * If you make changes in one editing context, you should call this to give
 * other editing contexts time to process the change notification
 */
- (void) wait;

/**
 * Returns a new context with its own store object, open on the same store URL
 * as the receiver.
 */
- (COEditingContext *) newContext;

@end

@interface COObjectGraphContext (TestCommon)
- (id)insertObjectWithEntityName: (NSString *)aFullName;
@end

@interface COObject (TestCommon)
/** 
 * Simple wrapper around -insertObjects:atIndexes:hints:forProperty:.
 */
- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key;
/** 
 * Simple wrapper around -removeObjects:atIndexes:hints:forProperty:.
 */
- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key;
@end
