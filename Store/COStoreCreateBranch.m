#import "COStoreCreateBranch.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreCreateBranch

@synthesize branch, persistentRoot, initialRevision;

- (BOOL) execute: (COSQLiteStore *)store
{
    return [[store database] executeUpdate: @"INSERT INTO branches (uuid, proot, initial_revid, current_revid, head_revid, metadata, deleted) VALUES(?,?,?,?,?,NULL,0)",
            [branch dataValue],
            [persistentRoot dataValue],
            [initialRevision dataValue],
            [initialRevision dataValue],
			[initialRevision dataValue]];
}

@end
