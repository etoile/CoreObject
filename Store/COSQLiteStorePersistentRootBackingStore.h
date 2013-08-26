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
    COSQLiteStore *_store; // weak reference
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
 * @returns 0 for the first commit on an empty backing store
 */
- (int64_t) writeItemGraph: (id<COItemGraph>)anItemTree
              withMetadata: (NSDictionary *)metadata
                withParent: (int64_t)aParent
             modifiedItems: (NSArray*)modifiedItems; // array of COUUID

- (NSIndexSet *) revidsFromRevid: (int64_t)baseRevid toRevid: (int64_t)finalRevid;

/**
 * Unconditionally deletes the specified revisions
 */
- (BOOL) deleteRevids: (NSIndexSet *)revids;

- (NSIndexSet *) revidsUsedRange;

@end
