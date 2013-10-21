#import "COStoreDeletePersistentRoot.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreDeletePersistentRoot

@synthesize persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [[store database] executeUpdate: @"UPDATE persistentroots SET deleted = 1 WHERE uuid = ?",
            [persistentRoot dataValue]];
}

@end
