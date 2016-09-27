/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreSetCurrentRevision.h"
#import "COSQLiteStore+Private.h"
#import "FMDatabaseAdditions.h"

@implementation COStoreSetCurrentRevision

@synthesize branch, persistentRoot, currentRevision, headRevision;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    // TODO: Validate that current revision is ancestor of head. This will be
    // expensive in terms of I/O relative to what we are doing now, so it will need to be benchmarked.
    
    BOOL ok = [store.database executeUpdate: @"UPDATE branches SET current_revid = ? WHERE uuid = ?",
            [currentRevision dataValue], [branch dataValue]];
    
    if (headRevision != nil)
    {
        ok = [store.database executeUpdate: @"UPDATE branches SET head_revid = ? WHERE uuid = ?",
              [headRevision dataValue], [branch dataValue]];
    }
    
    return ok;
}

@end
