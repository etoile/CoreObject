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
	
    return [[store database] executeUpdate: @"INSERT INTO persistentroots (uuid, backingstore, currentbranch, deleted, transactionid) "
            "VALUES(?, COALESCE((SELECT backingstore FROM persistentroots WHERE uuid = ?), ?), NULL, 0, ?)",
            [persistentRoot dataValue],
            [persistentRootForCopy dataValue],
            [persistentRoot dataValue],
            @(transactionID)];
}

@end
