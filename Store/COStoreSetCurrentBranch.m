#import "COStoreSetCurrentBranch.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreSetCurrentBranch

@synthesize branch, persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store
{
    return [[store database] executeUpdate: @"UPDATE persistentroots SET currentbranch = ? WHERE uuid = ?",
            [branch dataValue], [persistentRoot dataValue]];
}

@end
