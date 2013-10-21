#import "COSQLiteStore.h"
#import "FMDatabase.h"

/**
 * Private methods which are exposed so tests can look at the store internals.
 */
@interface COSQLiteStore ()

- (FMDatabase *) database;

- (ETUUID *) backingUUIDForPersistentRootUUID: (ETUUID *)aUUID;

- (BOOL) writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                           revisionUUID: (ETUUID *)aRevisionUUID
                               metadata: (NSDictionary *)metadata
                       parentRevisionID: (ETUUID *)aParent
                  mergeParentRevisionID: (ETUUID *)aMergeParent
                     persistentRootUUID: (ETUUID *)aUUID
                             branchUUID: (ETUUID*)branch;

@end

/** 
 * These methods are deprecated in favour of COStoreTransaction
 */
@interface COSQLiteStore (Deprecated)

- (BOOL) beginTransactionWithError: (NSError **)error;
- (BOOL) commitTransactionWithError: (NSError **)error;

/** @taskunit Revision Writing */

/**
 * Writes an inner object graph as a revision in the store.
 *
 * aParent determines the backing store to write the revision to; must be non-null.
 * modifiedItems is an array of the UUIDs of objects in anItemTree that were either added or changed from their state
 *     in aParent. nil can be passed to indicate that all inner objects were new/changed. This parameter
 *     is the delta compression, so it should be provided and must be accurate.
 *
 *     For optimal ease-of-use, this paramater would be removed, and the aParent revision would be feteched
 *     from disk or memory and compared to anItemTree to compute the modifiedItems set. Only problem is this
 *     requires comparing all items in the trees, which is fairly expensive.
 *
 * If an error occurred, returns nil and writes a reference to an NSError object in the error parameter.
 */
- (CORevisionID *) writeRevisionWithItemGraph: (COItemGraph*)anItemTree
                                 revisionUUID: (ETUUID *)aRevisionUUID
                                     metadata: (NSDictionary *)metadata
                             parentRevisionID: (CORevisionID *)aParent
                        mergeParentRevisionID: (CORevisionID *)aMergeParent
                                   branchUUID: (ETUUID *)aUUID
                           persistentRootUUID: (ETUUID *)aUUID
                                        error: (NSError **)error;


// TODO:
//  changedPropertiesForItemUUID: (NSDictionary*)changedProperties { uuidA : (propA, propB), uuidB : (propC) }




/** @taskunit Persistent Root Creation */

/**
 * Standard method to create a persistent root.
 *
 * Always creates a new backing store, so the contents will not be stored as a delta against another
 * persistent root. If the new persistent root is likely going to have content in common with another
 * persistent root, use -createPersistentRootWithInitialRevision: instead.
 *
 * Writes the item graph "contents" as an initial revision in the persistent root,
 * and creates a default branch (with nil metadata) whose current revision is set to the
 * initial revision.
 *
 * WARNING: with the current semantics, "contents" is not copied. After calling this
 * method you must not modify it. The should probably be changed.
 */
- (COPersistentRootInfo *) createPersistentRootWithInitialItemGraph: (id<COItemGraph>)contents
                                                               UUID: (ETUUID *)persistentRootUUID
                                                         branchUUID: (ETUUID *)aBranchUUID
                                                   revisionMetadata: (NSDictionary *)metadata
                                                              error: (NSError **)error;

/**
 * "Cheap copy" method of creating a persistent root.
 *
 * The created persistent root will have a single branch whose current revision is set to the
 * provided revision, and whose metadata is nil.
 *
 * The persistent root will share its backing store with the backing store of aRevision,
 * but this is an implementation detail and otherwise it's completely isolated from other
 * persistent roots sharing the same backing store.
 *
 * (The only way that sharing backing stores should be visible to uses is a corner case in
 * the behaviour of -finalizeDeletionsForPersistentRoot:. It will garbage collect all unreferenced
 * revisions in the backing store of the passed in persistent root)
 */
- (COPersistentRootInfo *) createPersistentRootWithInitialRevision: (CORevisionID *)aRevision
                                                              UUID: (ETUUID *)persistentRootUUID
                                                        branchUUID: (ETUUID *)aBranchUUID
												  parentBranchUUID: (ETUUID *)aParentBranch
                                                             error: (NSError **)error;

- (COPersistentRootInfo *) createPersistentRootWithUUID: (ETUUID *)persistentRootUUID
                                                  error: (NSError **)error;





/** @taskunit Persistent Root Modification */

/**
 * Sets the current branch. The current branch is used to resolve inter-persistent-root references
 * when no explicit branch is named.
 *
 * Returns NO if the branch does not exist, or is deleted (finalized or not).
 */
- (BOOL) setCurrentBranch: (ETUUID *)aBranch
        forPersistentRoot: (ETUUID *)aRoot
                    error: (NSError **)error;

- (BOOL) createBranchWithUUID: (ETUUID *)branchUUID
                 parentBranch: (ETUUID *)aParentBranch
              initialRevision: (CORevisionID *)revId
            forPersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error;

/**
 * All-in-one method for updating the current revision of a persistent root.
 *
 * Passing nil for any revision params means to keep the current value
 */
- (BOOL) setCurrentRevision: (CORevisionID*)currentRev
			initialRevision: (CORevisionID*)initialRev
               headRevision: (CORevisionID*)headRev
                  forBranch: (ETUUID *)aBranch
           ofPersistentRoot: (ETUUID *)aRoot
                      error: (NSError **)error;

- (BOOL) setMetadata: (NSDictionary *)metadata
           forBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot
               error: (NSError **)error;

/** @taskunit Persistent Root Deletion */

/**
 * Marks the given persistent root as deleted, can be reverted by -undeletePersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (BOOL) deletePersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error;

/**
 * Unmarks the given persistent root as deleted
 */
- (BOOL) undeletePersistentRoot: (ETUUID *)aRoot
                          error: (NSError **)error;

/**
 * Marks the given branch of the persistent root as deleted, can be reverted by -undeleteBranch:ofPersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (BOOL) deleteBranch: (ETUUID *)aBranch
     ofPersistentRoot: (ETUUID *)aRoot
                error: (NSError **)error;

/**
 * Unmarks the given branch of a persistent root as deleted
 */
- (BOOL) undeleteBranch: (ETUUID *)aBranch
       ofPersistentRoot: (ETUUID *)aRoot
                  error: (NSError **)error;

@end
