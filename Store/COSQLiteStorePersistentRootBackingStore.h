/**
    Copyright (C) 2012 Eric Wasylishen

    Date:  November 2012
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COItemGraph.h>
#import <CoreObject/COSQLiteStore.h>

@class FMDatabase;
@class COItemGraph;
@class CORevisionInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * Database connection for manipulating a persistent root backing store.
 *
 * Not a public class, only intended to be used by COSQLiteStore.
 */
@interface COSQLiteStorePersistentRootBackingStore : NSObject
{
    COSQLiteStore *__weak _store; // weak reference
    ETUUID *_uuid;
    FMDatabase *db_;
    BOOL _shareDB;

    /**
     * Can be cached after being read for the first time, since it can never change
     */
    ETUUID *_rootObjectUUID;
}

+ (void)migrateForBackingUUID: (ETUUID *)uuid
                      inStore: (COSQLiteStore *)store
                  fromVersion: (int64_t)version;

/**
 * @param
 *      aPath the pathn of a directory where the backing store
 *      should be opened or created.
 */
- (instancetype)initWithPersistentRootUUID: (ETUUID *)aUUID
                                     store: (COSQLiteStore *)store
                                useStoreDB: (BOOL)share
                                     error: (NSError *_Nullable *_Nullable)error NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) BOOL close;

- (nullable CORevisionInfo *)revisionInfoForRevisionUUID: (ETUUID *)aToken;

@property (nonatomic, readonly, strong) ETUUID *UUID;
@property (nonatomic, readonly, strong) ETUUID *rootUUID;

- (BOOL)hasRevid: (int64_t)revid;
- (COItemGraph *)itemGraphForRevid: (int64_t)revid;
- (COItemGraph *)itemGraphForRevid: (int64_t)revid restrictToItemUUIDs: (nullable NSSet<ETUUID *> *)itemSet;
/**
 * baseRevid must be < finalRevid.
 * returns nil if baseRevid or finalRevid are not valid revisions.
 */
- (COItemGraph *)partialItemGraphFromRevid: (int64_t)baseRevid toRevid: (int64_t)finalRevid;
- (COItemGraph *)partialItemGraphFromRevid: (int64_t)baseRevid
                                   toRevid: (int64_t)revid
                       restrictToItemUUIDs: (nullable NSSet<ETUUID *> *)itemSet;
- (BOOL)writeItemGraph: (COItemGraph *)anItemTree
          revisionUUID: (ETUUID *)aRevisionUUID
          withMetadata: (nullable NSDictionary<NSString *, id> *)metadata
                parent: (int64_t)aParent
           mergeParent: (int64_t)aMergeParent
            branchUUID: (ETUUID *)aBranchUUID
    persistentRootUUID: (ETUUID *)aPersistentRootUUID
         schemaVersion: (int64_t)aVersion
                 error: (NSError *_Nullable *_Nullable)error;
- (NSIndexSet *)revidsFromRevid: (int64_t)baseRevid toRevid: (int64_t)finalRevid;
//- (BOOL)rewriteRevisionUUID: (ETUUID *)aRevisionUUID
//              withItemGraph: (COItemGraph *)anItemGraph;
- (BOOL)migrateRevisionsToVersion: (int64_t)newVersion withHandler: (COMigrationHandler)handler;

/**
 * Unconditionally deletes the specified revisions
 */
- (BOOL)deleteRevids: (NSIndexSet *)revids;

/**
 * Returns a revision set containing all the revids used in the backing store.
 *
 * Initially this revision set starts at zero, but after compacting the history
 * the first index corresponds to the first kept revision.
 */
@property (nonatomic, readonly) NSIndexSet *revidsUsedRange;

- (int64_t)revidForUUID: (ETUUID *)aUUID;
- (NSIndexSet *)revidsForUUIDs: (NSArray *)UUIDs;
- (nullable ETUUID *)revisionUUIDForRevid: (int64_t)aRevid;
- (NSArray<CORevisionInfo *> *)revisionInfosForBranchUUID: (ETUUID *)aBranchUUID
                                         headRevisionUUID: (nullable ETUUID *)aHeadRevUUID
                                                  options: (COBranchRevisionReadingOptions)options;

@property (nonatomic, readonly) NSArray *revisionInfos;
@property (nonatomic, readonly) uint64_t fileSize;

- (void)clearBackingStore;
- (int64_t)deltabaseForRowid: (int64_t)aRowid;

@end

NSData *contentsBLOBWithItemTree(id <COItemGraph> itemGraph);

NS_ASSUME_NONNULL_END
