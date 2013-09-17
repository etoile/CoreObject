#import "COStoreCreatePersistentRoot.h"
#import "COSQLiteStore+Private.h"
#import "FMDatabaseAdditions.h"

@implementation COStoreCreatePersistentRoot

@synthesize persistentRoot, persistentRootForCopy;

- (BOOL) execute: (COSQLiteStore *)store
{
    NSData *bs = [[store database] dataForQuery: @"SELECT backingstore FROM persistentroots WHERE uuid = ?", [persistentRootForCopy dataValue]];
    
    
    return [[store database] executeUpdate: @"INSERT INTO persistentroots (uuid, backingstore, currentbranch, deleted, transactionuuid) "
            "VALUES(?, COALESCE((SELECT backingstore FROM persistentroots WHERE uuid = ?), ?), NULL, 0, ?)",
            [persistentRoot dataValue],
            [persistentRootForCopy dataValue],
            [persistentRoot dataValue],
            [[store transactionUUID] dataValue]];
}

@end
