#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@protocol COItemGraph;
@class ETUUID;
@class COItem, CORevisionID, CORevisionInfo, COItemGraph, COBranchInfo, COPersistentRootInfo;
@class FMDatabase, COStoreTransaction;

enum COBranchRevisionReadingOptions
{
	COBranchRevisionReadingParentBranches = 2,
	COBranchRevisionReadingDivergentRevisions = 4
};
typedef NSUInteger COBranchRevisionReadingOptions;

/**
 * This class implements a Core Object store using SQLite databases.
 *
 * Conceptual model
 * ----------------
 *
 * - A _store_ is comprised of a set of _persistent roots_.
 *   Each _persistent root_ has a UUID and it is unique within the store; however, it is possible for
 *   the same _persistent root_ to be in multiple stores, without necessairily having the same contents.
 *   (Consider cases where a store is copied onto backup storage.)
 *
 *   A _persistent root_ consists of:
 *
 *     - a set of _branches_, and a marker indicating the current branch
 *     - a flexible, user-facing metadata dictionary, for storing thigns like name, author.
 *       This metadata is not interpreted or used by COSQLiteStore.
 *
 *   A _branch_ consists of a linear sequence of _revisions_:  A _revision_ is a snapshot of the 
 *   persistent root contents. It also records its parent. In the future, metadata could be added per-revision.
 *
 *   The revisions in a branch are produced by making
 *   sequential edits to the _contents_ of the persistent root.
 *
 *   There is a  marker indicating the current revision, as well as two special revsions called
 *   "head" and "initial".
 *
 *   oldest           newest
 *     o--------o--------o
 *    initial current   head
 *
 *   The purpose of the head and initial pointers is to keep track of all revisions that have ever
 *   been committed to a branch. The initial represents the start of the recorded history of the branch,
 *   the head represents the newest. Normally the current revision is the same as the head,
 *   but the current revision could be moved to an older revision if the user wants to revert to an
 *   older sate.
 *
 *   Note: making a commit when the current branch is an older than the head revision would mean
 *   that the old head is lost. When exposing this functionality in the UI, the user should
 *   probably be encouraged/forced to make a new branch so that the old head isn't lost.
 *
 *   oldest                newest
 *
 *               /------------o
 *              /            new head
 *     o--------o . . . . o
 *    initial    current   (lost head)
 *
 *   (Note that if -finalizeDeletionsForPersistentRoot: is called in this state, the dotted revisions
 *   will be lost forever.) History compaction is accomplished by moving the initial pointer forward,
 *   and calling -finalizeDeletionsForPersistentRoot:.
 *
 *   The contents of a revision consists of a graph of
 *   _embedded objects_, along with one designated as the _root embedded object_. The designation
 *   of _root embedded object_ is for users' convenience; the intent is that this object is what
 *   the persistent root represents. Note that the root embedded object does not have the same UUID
 *   as the _persistent root_ that contains it.
 *
 *   Persistent roots and branches are mutable, and any changes made are unversioned (only the current
 *   state is stored.) Undo/redo should be implemented at a higher layer by logging changes made
 *   to the store.
 *
 *   The revisions of the versioned contents are stored in a DAG structure. Each revision is
 *   identified by, currently, an opaque ID (internally, backing store UUID + an integer).
 *   A hash, like git and other dvcs's use, could be used instead - the current scheme was chosen for
 *   simplicity and speculated better performance but we may switch to a hash.
 *
 *   TODO: Explain the propety types of embedded objects that are relevant to COSQLiteStore:
 *   Attachment ID, path (inter-persistent root reference)
 *
 * Basic Usage
 * -----------
 *
 * - The basic usage pattern is:
 *
 *    * Create a persistent root with -createPersistentRootWithInitialContents:metadata:,
 *      or -createPersistentRootWithInitialRevision: if a cheap copy is desired.
 *
 *    * Write an embedded object graph as a revision using -writeItemTree:withMetadata:withParentRevisionID:modifiedItems:.
 *
 *    * Set the current version of the persistent root's current version to the newly committed
 *      revision using -setCurrentVersion:forBranch:ofPersistentRoot:updateHead:
 *
 *    * Read back the embedded object graph at an old revision using -itemTreeForRevisionID:
 *
 * - Note that there is no deliberatly no support for copying persistent roots.
 *
 *
 *
 *
 * Garbage collection / deletion semantics
 * ---------------------------------------
 *
 * - Persistent roots are never garbage collected, they must be deleted explicitly by the user. [1]
 *   For convenience, once deleted, they can be undeleted. Typical use case:
 *        - user creates a document, types in it a bit.
 *        - It's a temporary note, so when they're done with it, they delete it.
 *        - The note is moved to the trash. CMD+Z undoes the move to trash.
 *   So by having the not deleted/deleted flag at the store level, we can easily
 *   make "delete" a command-pattern invertible undo action.
 *
 * - There are attachments which are stored separately from the revision data in backing stores,
 *   however from the point of view of data lifetime, it's as if the attachment is part of the revision
 *   data in the backing store.
 *
 * - Branches can be deleted. Like persistent roots, they can be undeleted, and the list of deleted braches
 *   for a persistent root can be queried.  
 *
 * - There is a "finalize deletions" command that the user can invoke on a persistent root, which permanently removes:
 *   * the persistent root, if it is marked as deleted
 *   * branches of the persistent root marked as deleted
 *   * all unreachable revisions in the same backing store as the persistent root
 *
 * - Additionally there is a separate command to delete all unreachable attachments in the store
 *
 * - Over time, the user may want to prune the history of a branch. This is implemented
 *   by moving ahead the 'base' pointer of a branch, and performing a "finalize deletions" command on the
 *   persistent root.
 * 
 * - Since "finalize deletions" actually deletes data and frees disk space, there are the following
 *   side effects:
 *   * Calling -undeletePersistentRoot: will return NO if "finalize deletions" has been performed
 *     since the persistent root was deleted with -deletePersistentRoot:
 *   * Calling -undeleteBranch: will return NO if "finalize deletions" has been performed
 *     since the branch was deleted with -deleteBranch:
 *   * Calling -setCurrentVersion:... will return NO if the revision has been deleted.
 * 
 * Implementation summary
 * ----------------------
 *
 * - COSQLiteStore has one SQLite database which stores the persistent root and branch metadata,
 *   as well as full text indexes and an index of attachment references (for garbage collecting attachments),
 *   and an index of cross-persistent root references (not used for anything internally, but exposed to
 *   users of the class so we can quickly answer questions like "show all references to this persistent root")
 *
 * - Persistent root contents are stored in "backing stores". See COSQLiteStorePersistentRootBackingStore.
 *
 *
 * Concurrency
 * -----------
 *
 * COSQLiteStore is designed to support multiple processes having the same store opening and making concurrent
 * changes. (at the moment it's not tested.)
 *
 * The only pieces of shared mutable state are the persistent root (and branch) metadata (current branch, 
 * current revision), and right now there is no synchronization mechanisim for multiple processes to coordinate
 * making a change... this will be needed.
 *
 * One idea was to add a fromVersion: paramater to -setCurrentVersion:forBranch:...,  and within the transaction, 
 * fail if the current state is not the fromVersion.
 *
 * Footnotes
 * ---------
 *
 * [1] Deletion modes: There are two designs we could have used for persistent root deletion:
 *   - 1. explicit deletion
 *   - 2. garbage collection
 *
 *   In the "explicit deletion" design, which is what we are using, persistent roots are never deleted
 *   unless explicitly removed by the user. In addition, I setteled on a two step deletion, where first
 *   the user calls -deletePersistentRoot:, and then -finalizeDeletionsForPersistentRoot: to permanently delete it.
 *
 *   The garbage collection design has serious problems. I was going to allow the user to designate some
 *   persistent roots as GC roots, which would never be garbage collected, and the rest would be eligible
 *   for collection unless there was a reference to them somehow. This is where the scheme starts to fall apart:
 *
 *   - if "old" references (that exist in old revisions but not in newer) keep a persistent root alive,
 *     then it becomes very difficult to ever delete persistent roots. Suppose you create a temporary
 *     persistent root T, and a reference to it in a long-lived workspace persistent root W.
 *     Later, the reference in W is deleted.
 *     The only way to have T's underlying disk space freed would be to erase all history of W up to the
 *     point where the reference to T was deleted. To fix this we'd have to curcumvent the GC by doing manual deletion,
 *     making the effort of doing GC wasted.
 *
 *  - a possible scheme could be, only references in the current version of all branches of all persistent roots
 *    are counted as keeping other persistent roots alive.
 *    This sceheme has a lot of problems:
 *
 *     * Could lead to accidental deletion if you temporairly revert the workspace W to an old version
 *       and a GC is triggered; then all documents referenced only by W after the point you reveted to
 *       will be permanently deleted.
 *
 *     * Hard to implement efficiently.
 *
 */
@interface COSQLiteStore : NSObject
{
@private
	NSURL *url_;
    ETUUID *_uuid;    
    FMDatabase *db_;
    NSMutableDictionary *backingStores_; // COUUID (backing store UUID => COCQLiteStorePersistentRootBackingStore)
    NSMutableDictionary *backingStoreUUIDForPersistentRootUUID_;
    NSMutableSet *modifiedPersistentRootsUUIDs_;
    
    COStoreTransaction *transaction_;
    dispatch_queue_t queue_;
}

/**
 * Opens an exisiting, or creates a new CoreObject store at the given file:// URL.
 */
- (id)initWithURL: (NSURL*)aURL;

/**
 * Returns the file:// URL the receiver was created with.
 */
- (NSURL*)URL;

@property (strong, readonly, nonatomic) ETUUID *UUID;


/** @taskunit Revision Reading */

/**
 * Read revision metadata for a given revision ID.
 *
 * This data in the store is immutable (except for the case that the revision becomes unreachable and is garbage collected
 * by a call to -finalizeDeletionsForPersistentRoot), and so it could be cached in memory by COSQLiteStore (though isn't currently)
 * 
 * Adding an in-memory cache for this will probably imporant.
 */
- (CORevisionInfo *) revisionInfoForRevisionID: (CORevisionID *)aToken;

/**
 * CORevisionID are not portable across stores (since different stores may
 * store a persistent root under different backing store UUIDs)
 * but a (persistent root UUID, revision UUID) pair is. This method is
 * for converting from that representation back to a CORevisionID.
 */
- (CORevisionID *) revisionIDForRevisionUUID: (ETUUID *)aRevisionUUID
                          persistentRootUUID: (ETUUID *)aPersistentRoot;

/**
 * N.B. This is the only API for discovering divergent revisions
 * (revisions which aren't ancestors of the current revision of a branch)
 */
- (NSArray *)revisionInfosForBranchUUID: (ETUUID *)aBranchUUID
                                options: (COBranchRevisionReadingOptions)options;

/**
 * Returns a delta between the given revision IDs.
 * The delta is uses the granularity of single embedded objects, but not individual properties.
 *
 * This is only useful if the caller has the state of baseRevid in memory.
 * 
 * In the future if we add an internal in-memory revision cache to COSQLiteStore, this may
 * no longer be of much use.
 */
- (COItemGraph *) partialItemGraphFromRevisionID: (CORevisionID *)baseRevid
                                    toRevisionID: (CORevisionID *)finalRevid;

/**
 * Returns the state the embedded object graph at a given revision.
 */
- (COItemGraph *) itemGraphForRevisionID: (CORevisionID *)aToken;

/**
 * Returns the UUID of the root object at the given revision ID
 */
- (ETUUID *) rootObjectUUIDForRevisionID: (CORevisionID *)aToken;

/**
 * Returns the state of a single embedded object at a given revision.
 */
- (COItem *) item: (ETUUID *)anitem atRevisionID: (CORevisionID *)aToken;


/** @taskunit Persistent Root Reading */

/**
 * Only returns non-deleted persistent root UUIDs.
 */
- (NSArray *) persistentRootUUIDs;
- (NSArray *) deletedPersistentRootUUIDs;

/**
 * @return  a snapshot of the state of a persistent root, or nil if
 *          the persistent root does not exist.
 */
- (COPersistentRootInfo *) persistentRootInfoForUUID: (ETUUID *)aUUID;
- (ETUUID *)persistentRootUUIDForBranchUUID: (ETUUID *)aBranchUUID;

/** @taskunit Search. API not final. */

/**
 * @returns an array of CORevisionID
 */
- (NSArray *) revisionIDsMatchingQuery: (NSString *)aQuery;

/**
 * @returns an array of COSearchResult
 */
- (NSArray *) referencesToPersistentRoot: (ETUUID *)aUUID;





/** @taskunit Revision Writing */

/**
 * Writes an embedded object graph as a revision in the store.
 *
 * aParent determines the backing store to write the revision to; must be non-null.
 * modifiedItems is an array of the UUIDs of objects in anItemTree that were either added or changed from their state
 *     in aParent. nil can be passed to indicate that all embedded objects were new/changed. This parameter
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

/**
 * Finalizes the deletion of any unreachable commits (whether due to -setInitialRevision:... moving the initial pointer,
 * or branches being deleted), any deleted branches, or the persistent root itself, as well as all unreachable
 * attachments.
 */
- (BOOL) finalizeDeletionsForPersistentRoot: (ETUUID *)aRoot
                                      error: (NSError **)error;







/** @taskunit Transactions. API not final. */

/**
 * Starts a transaction, purely for improving performance when making a batch of changes.
 * Should not normally be used, except for in batch imports.
 */
- (BOOL) beginTransactionWithError: (NSError **)error;
- (BOOL) commitTransactionWithError: (NSError **)error;
- (BOOL) commitTransactionWithUUID: (ETUUID *)transactionUUID withError: (NSError **)error;
- (BOOL) commitStoreTransaction: (COStoreTransaction *)aTransaction;

@property (readwrite, nonatomic, strong) ETUUID *transactionUUID;

- (void) clearStore;

@end

extern NSString *COStorePersistentRootDidChangeNotification;
extern NSString *kCOPersistentRootUUID;
extern NSString *kCOPersistentRootTransactionUUID;
extern NSString *kCOStoreUUID;
extern NSString *kCOStoreURL;
