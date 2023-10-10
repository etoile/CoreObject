/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class COSQLiteStore, COStoreTransaction;

NS_ASSUME_NONNULL_BEGIN

@protocol COStoreAction <NSObject>

@property (nonatomic, readwrite, copy) ETUUID *persistentRoot;

- (BOOL)execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction;

@end

NS_ASSUME_NONNULL_END
