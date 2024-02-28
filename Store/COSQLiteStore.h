/**
    Copyright (C) 2012 Eric Wasylishen

    Date:  November 2012
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@protocol COItemGraph;
@class ETUUID;
@class COItem, CORevisionInfo, COItemGraph, COBranchInfo, COPersistentRootInfo;
@class FMDatabase, COStoreTransaction;

NS_ASSUME_NONNULL_BEGIN

typedef COItemGraph *_Nonnull (^COMigrationHandler)(COItemGraph *oldItemGraph, int64_t oldVersion, int64_t newVersion);

#define BACKING_STORES_SHARE_SAME_SQLITE_DB 1

typedef NS_OPTIONS(NSUInteger, COBranchRevisionReadingOptions)
{
    /**
     * Return revisions between the branch's initial revision and head revision, inclusive
     */
    COBranchRevisionReadingDefault = 0,
    /**
     * Return all parent revisions of the branch's head revision, including those in
     * parent branches, as well as those in parent persistent roots.
     *
     * Revisions on branches merged into the branch, or on branches merged into
     * parent branches are not included.
     */
    COBranchRevisionReadingParentBranches = 2,
    /**
     * Finds the revisions which have the same branch UUID as the one being queried,
     * but are located on anonymous/implicit branches.
     *
     * These divergent revisions are usually created by undo/redo actions.
     *
     * Although no branch creation was requested, a divergent revision sequence
     * form a "branch" in the history graph, this is why we call these branches implicit or anonymous.
     *
     * If combined with COBranchRevisionReadingParentBranches, also includes divergent
     * revisions belonging to the parent of the branch being queried, and its parent, etc.
     *
     * See "lost head" example in COSQLiteStore documentation.
     */
    COBranchRevisionReadingDivergentRevisions = 4
};

/**
 * Semi-private notification name posted by COSQLiteStore. Only intended for
 * use by COEditingContext or clients using COSQLiteStore directly.
 */
extern NSString *const COStorePersistentRootsDidChangeNotification;

/* userInfo dictionary keys for COStorePersistentRootsDidChangeNotification */

extern NSString *const kCOStorePersistentRootTransactionIDs;
/**
 * The persistent root UUIDs inserted with the last commit.
 */
extern NSString *const kCOStoreInsertedPersistentRoots;
/**
 * The persistent root UUIDs deleted with the last commit.
 */
extern NSString *const kCOStoreDeletedPersistentRoots;
/**
 * The persistent root UUIDs compacted with -compactHistory: or
 * -finalizeDeletionsForPersistentRoot:error:.
 *
 * These persistent roots don't appear in kCOStorePersistentRootTransactionIDs.
 * Transaction IDs are not needed, since persistent root histories are
 * compacted by looking at the store state).
 *
 * Can include persistent roots which have not been compacted (but were just 
 * candidates for compaction).
 */
extern NSString *const kCOStoreCompactedPersistentRoots;
/**
 * The persistent root UUIDs finalized with -compactHistory: or
 * -finalizeDeletionsForPersistentRoot:error:.
 *
 * These persistent roots don't appear in kCOStorePersistentRootTransactionIDs 
 * Transaction IDs are not needed, since we look at the deletion status in store 
 * to decide whether we can finalize the persistent roots. Moreover the 
 * transaction ID that exist per persistent root erased with the finalization.
 */
extern NSString *const kCOStoreFinalizedPersistentRoots;
extern NSString *const kCOStoreUUID;
extern NSString *const kCOStoreURL;

/**
 * Size in bytes that this persistent root would occupy if exported,
 * including all history.
 */
extern NSString *const COPersistentRootAttributeExportSize;
/**
 * Size in bytes used by this persistent root, including all history.
 * For cheap copies, this excludes the size of the parent (will
 * currently just return 0).
 */
extern NSString *const COPersistentRootAttributeUsedSize;

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
 *   _inner objects_, along with one designated as the _root inner object_. The designation
 *   of _root inner object_ is for users' convenience; the intent is that this object is what
 *   the persistent root represents. Note that the root inner object does not have the same UUID
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
 *   TODO: Explain the propety types of inner objects that are relevant to COSQLiteStore:
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
 *    * Write an inner object graph as a revision using -writeItemTree:withMetadata:withParentRevisionID:modifiedItems:.
 *
 *    * Set the current version of the persistent root's current version to the newly committed
 *      revision using -setCurrentVersion:forBranch:ofPersistentRoot:updateHead:
 *
 *    * Read back the inner object graph at an old revision using -itemTreeForRevisionID:
 *
 * - Note that there is no deliberatly no support for copying persistent roots.
 *
 *
 * Garbage collection / deletion semantics
 * ---------------------------------------
 *
 * - Persistent roots are never garbage collected, they must be deleted explicitly by the user. 
 *   See Footnotes section for the motivations for this design.
 *   For convenience, once deleted, they can be undeleted until the "finalize deletions" operation
 *   is run on that persistent root. To implement this, persistent roots have a "deleted" flag,
 *   and this flag can be switched between true and false with no side-effects until "finalize deletions"
 *   is called.
 *
 *   Typical user experience:
 *
 *        - User creates a document, types in it a bit.
 *        - It's a temporary note, so when they're done with it, they delete it.
 *        - The deleted flag is set to YES (analogous to the document being in the trash).
 *          CMD+Z undoes the move to trash and sets the 'deleted' flag to NO.
 *
 *   So by having the not deleted/deleted flag at the store level, we can easily
 *   make "delete" a command-pattern invertible undo action.
 *
 * - Branches follow the same pattern as persistent roots: branches are not garbage collected;
 *   they have a "deleted" flag which is explictly toggled - with the caveat that, because branches are
 *   owned by persistent roots, when a persietent root deletion is made permanent
 *   by "finalize deletions", all of its branches are also permanently deleted
 *   (regardless of the setting of the 'deleted' flag on each branch).
 *
 * - Revisions _are_ garbage collected (unlike persistent roots and branches).
 *   The garbage collection works by treating all _head revisions_ of all existing branches 
 *   (i.e., branches that have not yet been permanently deleted from the stoer) as
 *   GC roots, and the living revisions are found by tracing the 'parent' and 'merge parent'
 *   links of revisions. All revisions unreachable in this way are deleted. (Note this is
 *   more or less the same model as git).
 *
 *   The revision GC is currently triggered by the same "finalize deletions" method that makes explicit
 *   persistent root and branch deletions permanent, but it could be triggered as a separate step.
 *
 * - You can draw a graph of object ownership like this:
 *
 *                             1               *                 *             *
 *      Persistent Root        ---------------->     Branch      -------------->   Revision
 *
 *       (No owner)                          (Owned by Persistent Root)         (Owned by the set of branches
 *                                                                               that can reach this revision by
 *                                                                               following parent or merge parent
 *                                                                            pointers, starting at the branch head.
 *                                                                           Note that this set is not fixed for a 
 *                                                                            evision and can change over time.)
 *
 *   (Only deleted explicitly             (Deleted explicitly at user's       (Garbage collected if the set of
 *    at the user's request)                request, and also when owner        owners described above is empty at
 *                                                  is deleted)                   the time when the GC is run)
 *
 *
 * - Note: Revisions have a "branchUUID" attribute. This is used as metadata and has no role in the
 *   GC/deletion semantics.
 *
 * - Implementation detail: store attachments are also garbage collected, but unlike the other aspects
 *   of CoreObject's deletion semantics, this is completely hidden from the user. You can think of
 *   the attachment being stored directly in item graph for each revision
 *
 * - Pseudocode for finalize deletions:
 *
 *   function finalizeDeletions(persistentRoot):
 *       if persistentRoot's deleted flag is set to true then:
 *           permanently erase the persistent root object from the database
 *           as well as all of its branches.
 *           # Note that the revisions are unaffected, unless the garbage collection
 *           # that runs later decides they can be deleted.
 *       else:
 *           for each branch of persistentRoot:
 *               if branch's deleted flag is set to true then:
 *                   permanently erase the branch object from the database
 *               end if
 *           end for
 *       end if
 *
 *       garbage-collect unreachable revisions
 *       garbage-collect unreachable attachments
 *   end function
 *
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
 *   the user calls -deletePersistentRoot: (which can be undone), and then -finalizeDeletionsForPersistentRoot: to permanently delete it.
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
    BOOL _enforcesSchemaVersion;
    FMDatabase *db_;
    NSMutableDictionary *backingStores_; // COUUID (backing store UUID => COCQLiteStorePersistentRootBackingStore)
    NSMutableDictionary *backingStoreUUIDForPersistentRootUUID_;

    dispatch_queue_t queue_;
    dispatch_semaphore_t _commitLock;
    NSUInteger _maxNumberOfDeltaCommits;
}

/**
 * Opens an exisiting, or creates a new CoreObject store at the given file:// URL.
 */
- (instancetype)initWithURL: (NSURL *)aURL
      enforcesSchemaVersion: (BOOL)enforcesSchemaVersion NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL: (NSURL *)aURL;
- (instancetype)init NS_UNAVAILABLE;

/**
 * Returns the file:// URL the receiver was created with.
 */
@property (nonatomic, readonly, strong) NSURL *URL;
@property (nonatomic, readonly, strong) ETUUID *UUID;
/**
 * The schema version after the last run migration with -migrateRevisionsToVersion:withHandler:.
 *
 * If no migration has been run, the schema version is 0.
 *
 * You can write revisions with a higher schema version, but not with a lower one. As a result,
 * CORevisionInfo.schemaVersion is always equal or greater than COSQLiteStore.schemaVersion.
 *
 * If you want to only write revisions with the same schema version than the store, then set
 * enforcesSchemaVersion to YES. In this case, -commitStoreTransaction: fails and returns NO, when
 * COStoreTransaction.schemaVersion is more recent than the store schema version.
 */
@property (nonatomic, readonly) int64_t schemaVersion;
/**
 * Whether transactions handed to -commitStoreTransaction: must use the same schema version than
 * the store.
 *
 * By default, returns NO and allows to write revisions with higher schema versions than the store.
 */
@property (nonatomic, readwrite) BOOL enforcesSchemaVersion;


/** @taskunit Revision Reading */


/**
 * Read revision metadata for a given revision ID.
 *
 * This data in the store is immutable (except for the case that the revision becomes unreachable and is garbage collected
 * by a call to -finalizeDeletionsForPersistentRoot), and so it could be cached in memory by COSQLiteStore (though isn't currently)
 * 
 * Adding an in-memory cache for this will probably imporant.
 */
- (nullable CORevisionInfo *)revisionInfoForRevisionUUID: (ETUUID *)aRevision
                                      persistentRootUUID: (ETUUID *)aPersistentRoot;
/**
 * N.B. This is the only API for discovering divergent revisions
 * (revisions which aren't ancestors of the current revision of a branch).
 * 
 * Nil is returned when no backing store can be found for the branch UUID.
 *
 * NOTE: Unstable API
 */
- (nullable NSArray<CORevisionInfo *> *)revisionInfosForBranchUUID: (ETUUID *)aBranchUUID
                                                           options: (COBranchRevisionReadingOptions)options;
/**
 * Returns all revision infos of the backing store where the given persistent
 * root is stored.
 * 
 * Nil is returned when no backing store can be found for the persistent root UUID.
 *
 * NOTE: Unstable API
 */
- (nullable NSArray<CORevisionInfo *> *)revisionInfosForBackingStoreOfPersistentRootUUID: (ETUUID *)aPersistentRoot;
/**
 * Returns a delta between the given revision IDs.
 * The delta is uses the granularity of single inner objects, but not individual properties.
 *
 * This is only useful if the caller has the state of baseRevid in memory.
 * 
 * In the future if we add an internal in-memory revision cache to COSQLiteStore, this may
 * no longer be of much use.
 */
- (nullable COItemGraph *)partialItemGraphFromRevisionUUID: (ETUUID *)baseRevid
                                            toRevisionUUID: (ETUUID *)finalRevid
                                            persistentRoot: (ETUUID *)aPersistentRoot;
/**
 * Returns the state the inner object graph at a given revision.
 */
- (nullable COItemGraph *)itemGraphForRevisionUUID: (ETUUID *)aRevisionUUID
                                    persistentRoot: (ETUUID *)aPersistentRoot;
/**
 * Returns the UUID of the root object of the given persistent root.
 */
- (nullable ETUUID *)rootObjectUUIDForPersistentRoot: (ETUUID *)aPersistentRoot;


/** @taskunit Persistent Root Reading */


/**
 * Only returns non-deleted persistent root UUIDs.
 */
@property (nonatomic, readonly) NSArray<ETUUID *> *persistentRootUUIDs;
@property (nonatomic, readonly) NSArray<ETUUID *> *deletedPersistentRootUUIDs;

/**
 * @return  a snapshot of the state of a persistent root, or nil if
 *          the persistent root does not exist.
 */
- (nullable COPersistentRootInfo *)persistentRootInfoForUUID: (nullable ETUUID *)aUUID;
- (nullable ETUUID *)persistentRootUUIDForBranchUUID: (ETUUID *)aBranchUUID;


/** @taskunit Migrating Schema */


- (BOOL)migrateRevisionsToVersion: (int64_t)newVersion withHandler: (COMigrationHandler)handler;


/** @taskunit Search. API not final. */


/**
 * @returns an array of COSearchResult
 */
- (NSArray *)searchResultsForQuery: (NSString *)aQuery;
/**
 * @returns an array of COSearchResult
 */
- (NSArray *)referencesToPersistentRoot: (ETUUID *)aUUID;
/**
 * Finalizes the deletion of any unreachable commits (whether due to -setInitialRevision:... moving the initial pointer,
 * or branches being deleted), any deleted branches, or the persistent root itself, as well as all unreachable
 * attachments.
 *
 * NOTE: This method is still under development
 */
- (BOOL)finalizeDeletionsForPersistentRoot: (ETUUID *)aRoot
                                     error: (NSError **)error;
/**
 * Compacts the database by rebuilding it.
 *
 * This shrinks the database file size unlike -compactHistory:.
 *
 * This operation is slow and will block the database until the method returns.
 * You should usually call it in a background thread and present an 
 * indeterminate progress bar at the UI level.
 *
 * For some background about running a vacuum operation, see:
 *
 * <list>
 * <item>https://blogs.gnome.org/jnelson/2015/01/06/sqlite-vacuum-and-auto_vacuum/</item>
 * <item>https://wiki.mozilla.org/Firefox/Projects/Places_Vacuum</item>
 * </list>
 */
- (BOOL)vacuum;
/**
 * Returns statistics about the database pages.
 *
 * The returned dictionary includes three keys (corresponding to specific SQLite
 * PRAGMA arguments):
 *
 * <deflist>
 * <term>freelist_count</term><desc>number of unused pages</desc>
 * <term>page_count</term><desc>number of all pages (used and unused)</desc>
 * <term>page_size</term><desc>page size (with page_size * page_count being 
 * equal to the database file size)</desc>
 * </deflist>
 *
 * These infos can be used to decide when to compact and vacuum the store.
 */
@property (nonatomic, readonly) NSDictionary *pageStatistics;


/** @taskunit Transactions */


- (BOOL)commitStoreTransaction: (COStoreTransaction *)aTransaction;
- (void)clearStore;


/** @taskunit Attributes */


/**
 * Returns a dictionary of attributes describing the persistent root
 * such as COPersistentRootAttributeExportSize and COPersistentRootAttributeUsedSize
 */
- (nullable NSDictionary *)attributesForPersistentRootWithUUID: (ETUUID *)aUUID;


/** @taskunit Description */


/**
 * Returns a short description to summarize the receiver.
 */
@property (readonly, copy) NSString *description;
/**
 * Returns a multi-line description listing all the backing stores and their 
 * revisions.
 */
@property (nonatomic, readonly) NSString *detailedDescription;

@end

NS_ASSUME_NONNULL_END
