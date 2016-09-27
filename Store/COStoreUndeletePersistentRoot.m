/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreUndeletePersistentRoot.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreUndeletePersistentRoot

@synthesize persistentRoot;

- (BOOL)execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [store.database executeUpdate: @"UPDATE persistentroots SET deleted = 0 WHERE uuid = ?",
                                          [persistentRoot dataValue]];
}

@end
