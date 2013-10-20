#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import <CoreObject/CoreObject.h>

#import "COSynchronizationClient.h"
#import "COSynchronizationServer.h"

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

#import "COSQLiteStore+Private.h"

#define SA(x) [NSSet setWithArray: x]

extern NSString * const kCOLabel;
extern NSString * const kCOContents;
extern NSString * const kCOParent;

/**
 * Base class for Core Object test classes that need a COSQLiteStore.
 */
@interface SQLiteStoreTestCase : NSObject
{
    COSQLiteStore *store;
}

/**
 * Returns the URL used for the store.
 */
+ (NSURL *)storeURL;

/**
 * Deletes all saved datas related to the store.
 *
 * Saved datas are usually .sqlitedb files.
 */
+ (void)deleteStore;

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

@end

@interface COObjectGraphContext (TestCommon)
- (id)insertObjectWithEntityName: (NSString *)aFullName;
@end
