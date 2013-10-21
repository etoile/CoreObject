#import "COStoreUndeletePersistentRoot.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreUndeletePersistentRoot

@synthesize persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [[store database] executeUpdate: @"UPDATE persistentroots SET deleted = 0 WHERE uuid = ?",
            [persistentRoot dataValue]];
}

@end