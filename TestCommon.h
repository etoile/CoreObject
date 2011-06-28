#import <Cocoa/Cocoa.h>
#import <UnitKit/UKRunner.h>
#import "COEditingContext.h"

#define STORE_URL [NSURL fileURLWithPath: [@"~/TestStore.sqlitedb" stringByExpandingTildeInPath]]
#define DELETE_STORE [[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL]

@interface UKRunner (TestSuiteSetUp)
+ (void) setUp;
@end

COEditingContext *NewContext();
void TearDownContext(COEditingContext *ctx);