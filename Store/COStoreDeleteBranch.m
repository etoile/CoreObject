#import "COStoreDeleteBranch.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreDeleteBranch

@synthesize branch, persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store
{
    return [[store database] executeUpdate: @"UPDATE branches SET deleted = 1 WHERE uuid = ? AND proot = ?",
            [branch dataValue],
            [persistentRoot dataValue]];
}

@end
