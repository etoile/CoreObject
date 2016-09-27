/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreCreatePersistentRoot.h"
#import "COSQLiteStore+Private.h"
#import "FMDatabaseAdditions.h"
#import "COStoreTransaction.h"

@implementation COStoreCreatePersistentRoot

@synthesize persistentRoot, persistentRootForCopy;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
//    NSData *bs = [[store database] dataForQuery: @"SELECT backingstore FROM persistentroots WHERE uuid = ?", [persistentRootForCopy dataValue]];
//    
    // FIXME: Factor out the + 1... maybe -newTransactionIDForPersistentRoot
    int64_t transactionID = [aTransaction oldTransactionIDForPersistentRoot: persistentRoot] + 1;
    
    BOOL ok = YES;
    
    ok = ok && [store.database executeUpdate: @"INSERT INTO persistentroots (uuid, currentbranch, deleted, transactionid) VALUES(?, NULL, 0, ?)",
            [persistentRoot dataValue],
            @(transactionID)];
    
    ok = ok && [store.database executeUpdate: @"INSERT INTO persistentroot_backingstores (uuid, backingstore) VALUES(?, COALESCE((SELECT backingstore FROM persistentroot_backingstores WHERE uuid = ?), ?))",
                [persistentRoot dataValue],
                [persistentRootForCopy dataValue],
                [persistentRoot dataValue]];
    
    return ok;
}

@end
