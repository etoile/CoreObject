/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreCreateBranch.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreCreateBranch

@synthesize branch, persistentRoot, initialRevision, parentBranch;

- (BOOL)execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [store.database executeUpdate: @"INSERT INTO branches (uuid, proot, current_revid, head_revid, metadata, deleted, parentbranch) VALUES(?,?,?,?,NULL,0,?)",
                                          [branch dataValue],
                                          [persistentRoot dataValue],
                                          [initialRevision dataValue],
                                          [initialRevision dataValue],
                                          [parentBranch dataValue]];
}

@end
