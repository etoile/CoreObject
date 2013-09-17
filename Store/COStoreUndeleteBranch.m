#import "COStoreUndeleteBranch.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreUndeleteBranch

@synthesize branch, persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store
{
    return [[store database] executeUpdate: @"UPDATE branches SET deleted = 0 WHERE uuid = ? AND proot = ?",
            [branch dataValue],
            [persistentRoot dataValue]];
}

@end
