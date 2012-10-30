#import <Foundation/Foundation.h>
#import <UnitKit/UKRunner.h>
#import "COEditingContext.h"
#import "COSQLStore.h"

#define SA(x) [NSSet setWithArray: x]

#define STORE_CLASS [COSQLStore class]
#define STORE_URL [NSURL fileURLWithPath: [@"~/TestStore.sqlitedb" stringByExpandingTildeInPath]]
/**
  * Open the store. Note that we create an autorelease pool. This is very deliberate - the nature
  * of the unit tests is that we open and close the database connection alot. sqlite3 requires that
  * all the prepared statements are "finalized" before the connection is closed. FM uses prepared
  * statements to perform SQL queries, but it doesn't destroy them before returning - they are 
  * attached to the FMResult objects, which are autoreleased. This means that un-released FMStatement
  * instances are floating about, which means that in turn un-finalised prepared statements are
  * around when we close the database. This sequence ensures that all the prepared statements are
  * finalized before the database is closed. This problem is unlikely to occur in a real programme,
  * as the DB connection is open for the entire programme length and probably controlled through a
  * ETApplication hook, where we could control the NSAutoreleasePool creation.
  */
#define OPEN_STORE(store)  NSAutoreleasePool *_pool = [NSAutoreleasePool new]; COStore *store = [[STORE_CLASS alloc] initWithURL: STORE_URL];
#define CLOSE_STORE(store) [_pool drain]; [store release];
#define DELETE_STORE [[NSFileManager defaultManager] removeFileAtPath: [STORE_URL path] handler: nil]

// NOTE: The Xcode project includes a test suite limited to the store tests
#ifndef STORE_TEST

@interface TestCommon : NSObject
{
	NSAutoreleasePool *pool;
	COEditingContext *ctx;
	COStore *store;
}

+ (void) setUp;

- (Class)storeClass;

- (void)instantiateNewContextAndStore;
- (void)discardContextAndStore;
- (void)deleteStore;

@end

COEditingContext *NewContext(COStore *store);
void TearDownContext(COEditingContext *ctx);

#endif
