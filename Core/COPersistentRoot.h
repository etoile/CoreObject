/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe
 
	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COEditingContext.h>
#import <CoreObject/COItemGraph.h>
#import <CoreObject/COPersistentObjectContext.h>

@class COBranch, COObject, CORevision, COSQLiteStore, CORelationshipCache, COPersistentRootInfo, COObjectGraphContext;

/**
 * Posted when any changes are committed to this persistent root, including
 * changes committed in another process.
 *
 * The userInfo dictionary is nil. The sender is the affected COPersistentRoot
 * object.
 */
extern NSString * const COPersistentRootDidChangeNotification;

/**
 * @group Core
 * @abstract A persistent root is a versioned sandbox inside a CoreObject store
 * (in DVCS terminology, a persistent root is a repository), which encapsulates
 * an object graph of inner objects and a history graph (DAG) of revisions (which
 * are snapshots of the inner object graph). A persistent root has one
 * or more branches, which are pointers on to the history graph.
 *
 * Considering all of the above parts together, a persistent root represents
 * a document or a top-level object in a CoreObject store.
 *
 * @section Conceptual Model
 *
 * For each new persistent root, CoreObject produces a new UUID triplet based on:
 *
 * <deflist>
 * <term>a persistent root</term><desc>a branch collection that results in
 * a history graph describing all the changes made to a document
 * (document has a very loose meaning here</desc>
 * <term>a branch</term><desc>the persistent root initial branch</desc>
 * <term>a root object</term><desc>the document main object e.g. the top node
 * of a structed document, a photo or contact object</desc>
 * </deflist>
 *
 * The persistent root UUID and branch UUID are unique (never reused) accross all
 * CoreObject stores, unless a persistent root has been replicated accross
 * stores. Two persistent roots can have the same root object UUID when one
 * is a cheap copy of the other.
 * Generally speaking, CoreObject constructs (branches, revisions, objects,
 * stores etc.) are not allowed to share the same UUID. For the unsupported
 * replication case, constructs using the same UUID are considered to be
 * identical (same type and data) but replicated.
 *
 * A persistent root represents a core object but a root object doesn't. 
 * As such, use -[COPersistentRoot UUID] to track core objects.
 * From a terminology standpoint, persistent root and core object can be used
 * interchangeably.
 *
 * FIXME: I think we should just eliminate the term "core object" as it only 
 * makes things more confusing. --Eric
 *
 * @section Common Use Cases
 *
 * The most common use case would be accesesing the object graph through
 * -objectGraphContext (if branches aren't being used by the application).
 *
 * @section Attributes and Metadata
 *
 * The 'metadata' property can be set to a JSON compatible NSDictionary
 * to store arbitrary application metadata. This property is persistent, but
 * not versioned (although metadata changes can will be undone/redone by COUndoTrack,
 * if the commit that changes the metadata is recorded to a track).
 *
 * @section Branches
 *
 * Branches act similarly to git in that a branch is a movable pointer on to the
 * history graph. See COBranch for more detail. 
 *
 * New persistent roots contains just a single branch (see -branches).
 *
 * You can ignore the COBranch API and just use COPersistentRoot to access
 * the object graph (-objectGraphContext).
 *
 * @section Cheap Copies
 *
 * Making a cheap copy of a persistent root creates a new persistent root (with
 * a new UUID) and a single branch (also with a new UUID), however the current revision
 * of the new branch will be set to the revision where the cheap copy was made.
 * The copy is a true copy, in that it can have no observable effect on the source
 * persistent root. However, the fact that it's a cheap copy will be evident in the
 * interconnected history graphs.
 *
 * @section Deletion
 *
 * CoreObject uses an explicit deletion model for Persistent Roots, controlled
 * by the 'deleted' flag. Modifying the flag marks the persistent root as having
 * changes to commit. A persistent root with the 'deleted' flag set on disk is
 * like a file in the trash. It can be undeleted by simply setting the 'deleted'
 * flag to NO and committing that change. 
 *
 * Only when the deleted flag is set to YES (and committed), is it possible for
 * CoreObject to irreversibly delete the underling storage of the persistent root.
 * 
 * Currently, the only way to do this is to call a lower level store API, however
 * this functionality will probably be exposed in COEditingContext at some point.
 */
@interface COPersistentRoot : NSObject <COPersistentObjectContext>
{
	@private
    ETUUID *_UUID;
	COEditingContext *__weak _parentContext;
    /**
     * State of the persistent root and its branches as loaded from the store.
     * We don't modify this as changes are being staged in-memory (class should 
	 * be immutable), but it is updaded when we make a commit or read from disk.
     *
     * If nil, this is a newly created persistent root.
     */
    COPersistentRootInfo *_savedState;
    /**
     * COBranch objects indexed by ETUUID
     */
    NSMutableDictionary *_branchForUUID;
	NSMutableSet *_branchesPendingDeletion;
	NSMutableSet *_branchesPendingUndeletion;
    /**
     * Used to stage a change to the current branch.
     */
    ETUUID *_currentBranchUUID;
    /**
     * Only used when creating a persistent root as a cheap copy.
     */
    ETUUID *_cheapCopyRevisionUUID;
    /**
     * Only used when creating a persistent root as a cheap copy.
     */
    ETUUID *_cheapCopyPersistentRootUUID;
	NSDictionary *_metadata;    
    BOOL _metadataChanged;
    int64_t _lastTransactionID;
	COObjectGraphContext *_currentBranchObjectGraph;
}


/** @taskunit Persistent Root Properties */


/**
 * The UUID that is bound to a single persistent root per CoreObject store.
 *
 * Two persistent roots belonging to distinct CoreObject stores cannot use the 
 * same UUID unless they point to the same persistent root replicated accross 
 * stores.<br />
 * For now, persistent root replication accross distinct CoreObject stores 
 * is used during collaborative editing (there is no public replication API 
 * though).
 */
@property (nonatomic, readonly) ETUUID *UUID;

@property (nonatomic, copy) NSDictionary *metadata;
/**
 * The persistent root deletion status.
 *
 * If the persistent root is marked as deleted, the deletion is committed to the 
 * store on the next editing context commit.
 */
@property (nonatomic, assign, getter=isDeleted) BOOL deleted;
/**
 * The newest revision date among all branches.
 *
 * Changing a branch current revision doesn't alter the returned date. See 
 * -[COBranch currentRevision].
 *
 * See -[COBranch newestRevision] and -[CORevision date].
 */
@property (nonatomic, readonly) NSDate *modificationDate;
/**
 * The first revision date.
 *
 * The first revision is the same accross all branches in a persistent root.
 *
 * See -[COBranch firstRevision] and -[CORevision date].
 */
@property (nonatomic, readonly) NSDate *creationDate;
/**
 * The persistent root this is a copy of, or nil if the receiver is not a copy.
 *
 * See -[COPersistentRoot isCopy].
 */
@property (nonatomic, readonly) COPersistentRoot *parentPersistentRoot;
/**
 * Returns YES if this persistent root is a copy (self.parentPersistentRoot != nil)
 *
 * See -[COBranch isCopy].
 */
@property (nonatomic, readonly) BOOL isCopy;
/**
 * Returns attributes of the persistent root as reported by the store,
 *
 * See COPersistentRootAttributeExportSize, COPersistentRootAttributeUsedSize
 */
@property (nonatomic, readonly) NSDictionary *attributes;


/** @taskunit Accessing Branches */


/**
 * The branch that opens when double-clicking a persistent root to edit it.
 *
 * Also used to resolve inter-persistent root references to this persistent root 
 * when no explicit branch.
 *
 * Changing this value stages it for commit; upon the next -commit, the change 
 * is saved to disk and replicated to other applications.
 */
@property (nonatomic, strong) COBranch *currentBranch;
/**
 * All the branches owned by the persistent root (excluding those that are 
 * marked as deleted on disk), plus those pending insertion and undeletion (and 
 * minus those pending deletion).
 */
@property (nonatomic, readonly) NSSet *branches;
/**
 * All the branches marked as deleted on disk, excluding those that are pending 
 * undeletion.
 *
 * -branchesPendingDeletion are not included in the returned set.
 */
@property (nonatomic, readonly) NSSet *deletedBranches;
/**
 * Returns the branch using the given UUID or nil.
 *
 * The persistent root retains the returned branch.
 *
 * TODO: Document if this method can return branches among deleted branches and 
 * branches pending insertion, deletion and undeletion.
 */
- (COBranch *)branchForUUID: (ETUUID *)aUUID;


/** @taskunit Editing Context Nesting */


/**
 * The editing context managing the receiver.
 *
 * The parent context makes possible to edit multiple persistent roots 
 * simultaneously and provide an aggregate view on the editing underway.
 *
 * COPersistentRoot objects are instantiated and released by the parent context.
 *
 * The parent context is managed by the user.
 */
@property (nonatomic, readonly, weak) COEditingContext *parentContext;
/**
 * Returns -parentContext.
 *
 * See also -[COPersistentObjectContext editingContext].
 */
@property (nonatomic, readonly, weak) COEditingContext *editingContext;


/** @taskunit Pending Changes */


/**
 * The new branches to be saved in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *branchesPendingInsertion;
/**
 * The branche to be deleted in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *branchesPendingDeletion;
/**
 * The branches to be undeleted in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *branchesPendingUndeletion;
/**
 * The branches to be updated in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *branchesPendingUpdate;
/**
 * Returns whether the persistent root contains uncommitted changes.
 *
 * Branch insertions, deletions, undeletions, and modifications (e.g. editing 
 * branch metadata, reverting branch to a past revision) all count as 
 * uncommitted changes.
 *
 * See also -discardAllChanges and -[COBranch hasChanges].
 */
- (BOOL)hasChanges;
/**
 * Discards the uncommitted changes to reset the branch to its last commit state.
 *
 * Branch insertions, deletions, undeletions and modifications (e.g. editing 
 * branch metadata, reverting branch to a past revision) will be cancelled.
 *
 * All uncommitted inner object edits in the object graphs owned by the 
 * branches will be cancelled.
 *
 * -branchesPendingInsertion, -branchesPendingDeletion, 
 * -branchesPendingUndeletion and -branchesPendingUpdate  will all return empty
 * sets once the changes have been discarded.
 *
 * See also -hasChanges and -[COBranch discardAllChanges].
 */
- (void)discardAllChanges;


/** @taskunit Convenience */


/**
 * Shorthand for [[[self currentBranch] objectGraphContext] rootObject]
 */
@property (nonatomic, strong) id rootObject;
/**
 * Shorthand for [[[self currentBranch] objectGraphContext] loadedObjectForUUID:]
 */
- (COObject *)loadedObjectForUUID: (ETUUID *)uuid;
/**
 * Shortcut for <code>[[self currentBranch] currentRevision]</code>
 *
 * For a new persistent root, the revision is nil, unless it is a cheap copy. 
 * See -[COBranch makeCopyFromRevision:].
 */
@property (nonatomic, strong) CORevision *currentRevision;
/**
 * Shortcut for <code>[[self currentBranch] headRevision]</code>
 */
@property (nonatomic, strong) CORevision *headRevision;
/**
 * Shorthand for [[self editingContext] store]
 */
@property (nonatomic, readonly) COSQLiteStore *store;
/**
 * Returns the object graph for the edited branch
 */
@property (nonatomic, readonly) COObjectGraphContext *objectGraphContext;
@property (nonatomic, readonly) NSSet *allObjectGraphContexts;


/** @taskunit Committing Changes */


/** 
 * Commits this persistent root changes to the store, bound to a commit 
 * descriptor identifier along the additional metadatas, and returns whether it
 * succeeds.
 *
 * See -[COEditingContext commitWithIdentifier:metadata:undoTrack:error:].
 */
- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
                    metadata: (NSDictionary *)additionalMetadata
				   undoTrack: (COUndoTrack *)undoTrack
                       error: (NSError **)anError;
/**
 * Commits this persistent root changes to the store and returns whether it 
 * succeeds.
 *
 * You should avoid using this method in release code, it is mainly useful for 
 * debugging and quick development.
 *
 * See -commitWithIdentifier:metadata:undoTrack:error:.
 */
- (BOOL)commit;


/** @taskunit Previewing Old Revision */
 
 
/**
 * Returns a read-only object graph context of the contents of a revision.
 * Tentative API...
 */
- (COObjectGraphContext *)objectGraphContextForPreviewingRevision: (CORevision *)aRevision;


/** @taskunit Description */


/**
 * Returns a short description to summarize the receiver.
 */
- (NSString *)description;
/**
 * Returns a multi-line description including informations about the branches,  
 * deletion status, attached metadata and pending changes.
 */
- (NSString *)detailedDescription;


/** @taskunit Deprecated */


/**
 * Returns YES.
 *
 * See also -[NSObject isPersistentRoot].
 *
 * Reason for deprecating: I don't like NSObject+CoreObject idea, violates tell-don't-ask principle.
 */
@property (nonatomic, readonly) BOOL isPersistentRoot;

@end
