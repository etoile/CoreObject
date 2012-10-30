#import <Foundation/Foundation.h>
#import <UnitKit/UKRunner.h>
#import "COEditingContext.h"
#import "COSQLStore.h"

#define SA(x) [NSSet setWithArray: x]

#define STORE_CLASS [COSQLStore class]
#define STORE_URL [NSURL fileURLWithPath: [@"~/TestStore.sqlitedb" stringByExpandingTildeInPath]]

/**
 * Base class for Core Object test classes.
 */
@interface TestCommon : NSObject
{
	NSAutoreleasePool *pool;
	COEditingContext *ctx;
	COStore *store;
}

/**
 * Returns STORE_CLASS by default.
 *
 * For each test class, can be overriden to return a dedicated store class.
 */
- (Class)storeClass;
/**
 * Returns STORE_URL by default.
 *
 * For each test class, can be overriden to return a dedicated store URL.
 */
- (NSURL *)storeURL;
/**
 * Calls -discardsContextAndStore to reset the test class state to a clean state 
 * (without deleting the saved dates from store), then instantiates a new 
 * autorelease pool, a store based on -storeClass and -storeURL, and a 
 * COEditingContext using the resulting store.
 *
 * The new context and store are retained objects (-dealloc releases them).
 *
 * Note that we create an autorelease pool. This is very deliberate - the nature
 * of the unit tests is that we open and close the database connection alot.
 * sqlite3 requires that all the prepared statements are "finalized" before the 
 * connection is closed. FM uses prepared statements to perform SQL queries, but 
 * it doesn't destroy them before returning - they are attached to the FMResult 
 * objects, which are autoreleased. This means that un-released FMStatement
 * instances are floating about, which means that in turn un-finalised prepared 
 * statements are around when we close the database. This sequence ensures that 
 * all the prepared statements are finalized before the database is closed. This 
 * problem is unlikely to occur in a real programme, as the DB connection is 
 * open for the entire programme length and probably controlled through a
 * ETApplication hook, where we could control the NSAutoreleasePool creation.
 */
- (void)instantiateNewContextAndStore;
/**
 * Drains the autorelease pool created in -instantiatedNewContextAndStore and 
 * releases both <code>ctx</code> and <code>store</code>.
 *
 * Both the editing context and the store are instantiated at initialization 
 * time through -instantiateNewContextAndStore.
 */
- (void)discardContextAndStore;
/**
 * Deletes all saved datas related to the store.
 *
 * Saved datas are usually .sqlitedb files.
 */
- (void)deleteStore;

@end
