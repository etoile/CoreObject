#import <Foundation/Foundation.h>
#import <CoreObject/COItemGraph.h>

@class FMDatabase;
@class COItemGraph;
@class CORevisionInfo;
@class CORevisionID;
@class COSQLiteStore;

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
}

/**
 * @param
 *      aPath the pathn of a directory where the backing store
 *      should be opened or created.
 */
- (id)initWithPersistentRootUUID: (ETUUID*)aUUID
                           store: (COSQLiteStore *)store
                      useStoreDB: (BOOL)share
                           error: (NSError **)error;

- (BOOL)close;

- (BOOL) beginTransaction;
- (BOOL) commit;

- (CORevisionInfo *) revisionForID: (CORevisionID *)aToken;

- (ETUUID *) rootUUIDForRevid: (int64_t)revid;
- (BOOL) hasRevid: (int64_t)revid;

- (COItemGraph *) itemGraphForRevid: (int64_t)revid;

- (COItemGraph *) itemGraphForRevid: (int64_t)revid restrictToItemUUIDs: (NSSet *)itemSet;

/**
 * baseRevid must be < finalRevid.
 * returns nil if baseRevid or finalRevid are not valid revisions.
 */
- (COItemGraph *) partialItemGraphFromRevid: (int64_t)baseRevid toRevid: (int64_t)finalRevid;

- (COItemGraph *) partialItemGraphFromRevid: (int64_t)baseRevid
                                    toRevid: (int64_t)revid
                        restrictToItemUUIDs: (NSSet *)itemSet;

/**
 * 
 * @returns 0 for the first commit on an empty backing store, -1 on error
 */
- (CORevisionID *) writeItemGraph: (id<COItemGraph>)anItemTree
                     revisionUUID: (ETUUID *)aRevisionUUID
                     withMetadata: (NSDictionary *)metadata
                       withParent: (int64_t)aParent
                  withMergeParent: (int64_t)aMergeParent
                    modifiedItems: (NSArray *)modifiedItems // array of ETUUID
                            error: (NSError **)error;

- (NSIndexSet *) revidsFromRevid: (int64_t)baseRevid toRevid: (int64_t)finalRevid;

/**
 * Unconditionally deletes the specified revisions
 */
- (BOOL) deleteRevids: (NSIndexSet *)revids;

- (NSIndexSet *) revidsUsedRange;

- (int64_t) revidForUUID: (ETUUID *)aUUID;
- (int64_t) revidForRevisionID: (CORevisionID *)aToken;

- (CORevisionID *) revisionIDForRevid: (int64_t)aRevid;

@end
