#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import <CoreObject/CoreObject.h>

#import "COSynchronizationClient.h"
#import "COSynchronizationServer.h"

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

@end
