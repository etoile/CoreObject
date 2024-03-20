/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "COSQLiteStore.h"
#import "FMDatabase.h"

@class COSQLiteStorePersistentRootBackingStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * Private methods which are exposed so tests can look at the store internals.
 */
@interface COSQLiteStore ()

@property (nonatomic, readonly, strong) FMDatabase *database;
@property (nonatomic, readwrite, assign) NSUInteger maxNumberOfDeltaCommits;

- (BOOL)writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                          revisionUUID: (ETUUID *)aRevisionUUID
                              metadata: (NSDictionary<NSString *, id> *)metadata
                      parentRevisionID: (nullable ETUUID *)aParent
                 mergeParentRevisionID: (nullable ETUUID *)aMergeParent
                    persistentRootUUID: (ETUUID *)aUUID
                            branchUUID: (ETUUID *)branch
                         schemaVersion: (int64_t)aVersion;
- (COSQLiteStorePersistentRootBackingStore *)backingStoreForPersistentRootUUID: (ETUUID *)aUUID
                                                            createIfNotPresent: (BOOL)createIfNotPresent;
- (void)testingRunBlockInStoreQueue: (void (^)(void))aBlock;

@end

NS_ASSUME_NONNULL_END
