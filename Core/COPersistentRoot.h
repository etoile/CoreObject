/*
	Copyright (C) 2012 Quentin Mathe
 
	Author:  Quentin Mathe <quentin.mathe@gmail.com>, 
	         Eric Wasylishen <ewasylishen@gmail.com>
	Date:  November 2012
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COEditingContext.h>
#import <CoreObject/COItemGraph.h>

@class COBranch, COObject, CORevision, COSQLiteStore, CORelationshipCache, COPersistentRootInfo, COObjectGraphContext, CORevisionID;

/**
 * Posted when any of the following changes are made to a COPersistentRoot:
 *  - undo/redo
 *  - delete/undelete
 *  - revert
 *  - change branch
 *  - TODO: complete this list
 *
 * But not:
 *  - editing an embedded object
 *
 * The userInfo dictionary is nil. The sender is the affected COPersistentRoot
 * object.
 */
extern NSString * const COPersistentRootDidChangeNotification;

/**
 * A persistent root editing context exposes as a working copy a CoreObject 
 * store snapshot restricted to a single persistent root (see COEditingContext also).
 *
 * It queues changes and when the user requests it, it attempts to commit them
 * to the store.
 *
 * For each new persistent root, CoreObject produces a new UUID triplet based on:
 *
 * <deflist>
 * <item>a persistent root</item>a commit track collection that results in 
 * a history graph describing all the changes made to a document
 * (document has a very loose meaning here)</desc>
 * <item>a commit track</item><desc>the persistent root main branch, more 
 * commit tracks can be created by branching this initial track</desc>
 * <item>a root object</item><desc>the document main object e.g. the top node 
 * of a structed document, a photo object or a contact object</desc>
 * </deflist>
 *
 * Each UUID in this UUID triplet is unique (never reused) accross all 
 * CoreObject stores, unless a persistent root has been replicated accross 
 * stores (not supported for now).<br />
 * Generally speaking, CoreObject constructs (tracks, revisions, objects, 
 * stores etc.) are not allowed to share the same UUID. For the unsupported 
 * replication case, constructs using the same UUID are considered to be 
 * identical (same type and data) but replicated.  
 *
 * A persistent root represents a core object but a root object doesn't (see 
 * -rootObject). As such, use -persistentRootUUID to track core objects. 
 * A root object UUID might appear in multiple persistent roots (e.g. 
 * a persistent root copy will use the same root object UUID than the original 
 * persistent root although both core objects or persistent roots are distinct.<br />
 * From a terminology standpoint, persistent root and core object can be used 
 * interchangeably.
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
     * UUID of branch being edited. Not persistent.
	 *
     * If nil, means use _currentBranchUUID as the editing branch.
     */
    ETUUID *_editingBranchUUID;
    /**
     * Only used when creating a persistent root as a cheap copy.
     */
    CORevisionID *_cheapCopyRevisionID;
    ETUUID *_lastTransactionUUID;
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
/**
 * The persistent root deletion status.
 *
 * If the persistent root is marked as deleted, the deletion is committed to the 
 * store on the next editing context commit.
 */
@property (readwrite, nonatomic, getter=isDeleted, setter=setDeleted:) BOOL deleted;
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


/** @taskunit Accessing Branches */


/**
 * The editingBranch is not a persistent value, but is used by COPersistentRoot 
 * methods like -rootObject, -objectGraphContext, etc. as the default object 
 * graph presented by the persistent root.
 *
 * By default, -editingBranch just returns -currentBranch. However, if you
 * call -setEditingBranch: explicitly, then that branch will be used and
 * -editingBranch will no longer track -currentBranch.
 */
@property (nonatomic, readwrite, strong) COBranch *editingBranch;
/**
 * The branch that opens when double-clicking a persistent root to edit it.
 *
 * Also used to resolve inter-persistent root references to this persistent root 
 * when no explicit branch.
 *
 * Changing this value stages it for commit; upon the next -commit, the change 
 * is saved to disk and replicated to other applications.
 */
@property (nonatomic, readwrite, strong) COBranch *currentBranch;
/**
 * All the branches owned by the persistent root (excluding those that are 
 * marked as deleted on disk), plus those pending insertion and undeletion (and 
 * minus those pending deletion).
 */
@property (weak, nonatomic, readonly) NSSet *branches;
/**
 * All the branches marked as deleted on disk, excluding those that are pending 
 * undeletion.
 *
 * -branchesPendingDeletion are not included in the returned set.
 */
@property (nonatomic, copy, readonly) NSSet *deletedBranches;
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
@property (weak, nonatomic, readonly) COEditingContext *parentContext;
/**
 * Returns -parentContext.
 *
 * See also -[COPersistentObjectContext editingContext].
 */
@property (weak, nonatomic, readonly) COEditingContext *editingContext;


/** @taskunit Pending Changes */


/**
 * The new branches to be saved in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *branchesPendingInsertion;
/**
 * The branche to be deleted in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *branchesPendingDeletion;
/**
 * The branches to be undeleted in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *branchesPendingUndeletion;
/**
 * The branches to be updated in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *branchesPendingUpdate;
/**
 * Returns whether the persistent root contains uncommitted changes.
 *
 * Branch insertions, deletions, undeletions, and modifications (e.g. editing 
 * branch metadata, reverting branch to a past revision) all count as 
 * uncommitted changes.
 *
 * See also -discardAllChanges.
 */
- (BOOL)hasChanges;
/**
 * Discards the uncommitted changes to reset the branch to its last commit state.
 *
 * Branch insertions, deletions, undeletions and modifications (e.g. editing 
 * branch metadata, reverting branch to a past revision) will be cancelled.
 *
 * All uncommitted embedded object edits in the object graphs owned by the 
 * branches will be cancelled.
 *
 * -branchesPendingInsertion, -branchesPendingDeletion, 
 * -branchesPendingUndeletion and -branchesPendingUpdate  will all return empty
 * sets once the changes have been discarded.
 *
 * See also -hasChanges.
 */
- (void)discardAllChanges;


/** @taskunit Convenience */


/**
 * Shorthand for [[[self editingBranch] objectGraphContext] rootObject]
 */
@property (nonatomic, strong) id rootObject;
/**
 * Shorthand for [[[self editingBranch] objectGraphContext] objectWithUUID:]
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid;
/**
 * Shortcut for <code>[[self editingBranch] revision]</code>
 *
 * For a new persistent root, the revision is nil, unless it is a cheap copy. 
 * See -[COBranch makeCopyFromRevision:].
 */
@property (nonatomic, strong) CORevision *currentRevision;
/**
 * Shorthand for [[self editingContext] store]
 */
@property (weak, nonatomic, readonly) COSQLiteStore *store;
/**
 * Returns the object graph for the edited branch
 */
@property (weak, nonatomic, readonly) COObjectGraphContext *objectGraphContext;


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


/** @taskunit Deprecated */


/**
 * Returns YES.
 *
 * See also -[NSObject isPersistentRoot].
 *
 * Reason for deprecating: I don't like NSObject+CoreObject idea, violates tell-don't-ask principle.
 */
@property (nonatomic, readonly) BOOL isPersistentRoot;/**
 * Commits the current changes to the store with some basic metadatas and
 * returns the resulting revision.
 *
 * A commit on a single persistent root is atomic.
 *
 * This method won't commit changes of other persistent roots loaded in the 
 * parent context.
 *
 * The description will be visible at the UI level when browsing the history.
 *
 * See -commitWithMetadata:.
 */
- (BOOL)commitWithType: (NSString *)type
      shortDescription: (NSString *)shortDescription;

@end
