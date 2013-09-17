#import "COStoreSetCurrentRevision.h"
#import "COSQLiteStore+Private.h"
#import "FMDatabaseAdditions.h"

@implementation COStoreSetCurrentRevision

@synthesize branch, persistentRoot, currentRevision;

- (BOOL) execute: (COSQLiteStore *)store
{
    return [[store database] executeUpdate: @"UPDATE branches SET current_revid = ? WHERE uuid = ?",
            [currentRevision dataValue], [branch dataValue]];
}

@end
