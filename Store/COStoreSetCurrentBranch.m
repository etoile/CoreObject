/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreSetCurrentBranch.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreSetCurrentBranch

@synthesize branch, persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [store.database executeUpdate: @"UPDATE persistentroots SET currentbranch = ? WHERE uuid = ?",
            [branch dataValue], [persistentRoot dataValue]];
}

@end
