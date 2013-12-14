/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class COSQLiteStore, COStoreTransaction;

@protocol COStoreAction <NSObject>

@property (nonatomic, strong) ETUUID *persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction;

@end
