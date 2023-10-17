/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class COStoreTransaction;

/**
 * To properly send a COSynchronizerRevision over the network, it's assumed
 * that you have also sent any referenced attachments if needed. This should
 * probably be done optimistaically and is left up to lower levels of the networking
 * protocol.
 */
@interface COSynchronizerRevision : NSObject

@property (nonatomic, readwrite, strong) COItemGraph *modifiedItems;
@property (nonatomic, readwrite, copy) ETUUID *revisionUUID;
@property (nonatomic, readwrite, copy) ETUUID *parentRevisionUUID;
@property (nonatomic, readwrite, copy) NSDictionary *metadata;
@property (nonatomic, readwrite, copy) NSDate *date;

- (void)writeToTransaction: (COStoreTransaction *)txn
        persistentRootUUID: (ETUUID *)persistentRoot
                branchUUID: (ETUUID *)branch
           isFirstRevision: (BOOL)isFirst;
- (instancetype)initWithUUID: (ETUUID *)aUUID
              persistentRoot: (ETUUID *)aPersistentRoot
                       store: (COSQLiteStore *)store
  recordAsDeltaAgainstParent: (BOOL)delta NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, strong) id propertyList;

- (instancetype)initWithPropertyList: (id)aPropertyList NS_DESIGNATED_INITIALIZER;

@end
