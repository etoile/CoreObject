/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreDeleteBranch.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreDeleteBranch

@synthesize branch, persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [[store database] executeUpdate: @"UPDATE branches SET deleted = 1 WHERE uuid = ? AND proot = ?",
            [branch dataValue],
            [persistentRoot dataValue]];
}

@end
