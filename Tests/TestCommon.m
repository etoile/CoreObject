#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COPersistentRoot.h"
#import "COSQLiteStore.h"
#import "TestCommon.h"

NSString * const kCOLabel = @"label";
NSString * const kCOContents = @"contents";
NSString * const kCOParent = @"parentContainer";

@implementation SQLiteStoreTestCase

- (id) init
{
    self = [super init];
    
    [self deleteStore];
    store = [[COSQLiteStore alloc] initWithURL: [self storeURL]];
    
    return self;
}


- (void) deleteStore
{
	[[NSFileManager defaultManager] removeItemAtURL: [self storeURL] error: NULL];
}

- (NSURL *) storeURL
{
	return [NSURL fileURLWithPath: [@"~/TestStore.sqlite" stringByExpandingTildeInPath]];
}

@end

@implementation EditingContextTestCase

- (id) init
{
	SUPERINIT;
	ctx = [[COEditingContext alloc] initWithStore: store];
    return self;
}


@end
