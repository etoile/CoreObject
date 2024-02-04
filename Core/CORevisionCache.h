/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

@class COSQLiteStore, CORevision;

NS_ASSUME_NONNULL_BEGIN

@interface CORevisionCache : NSObject
{
@private
    COSQLiteStore *_store;
    NSMutableDictionary *_revisionForRevisionID;
}

/** @taskunit Framework Private */

@property (nonatomic, readonly) COSQLiteStore *store;

- (instancetype)initWithStore: (COSQLiteStore *)aStore NS_DESIGNATED_INITIALIZER;
- (nullable CORevision *)revisionForRevisionUUID: (ETUUID *)aRevid
                              persistentRootUUID: (ETUUID *)aPersistentRoot;

@end

NS_ASSUME_NONNULL_END
