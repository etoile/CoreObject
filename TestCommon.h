#import <Cocoa/Cocoa.h>

#define STORE_URL [NSURL fileURLWithPath: [@"~/TestStore.sqlitedb" stringByExpandingTildeInPath]]
#define DELETE_STORE [[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL]

void setUpMetamodel();