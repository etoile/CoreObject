/**
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
 * an object graph of inner objects and a history graph (DAG) of revisions 
 * (which are snapshots of the inner object graph). A persistent root has one 
 * or more branches, which are pointers on to the history graph.
 *
 * Considering all of the above parts together, a persistent root represents
 * a document or a top-level object in a CoreObject store.
 *
 * @section Conceptual Model
 *
 * For each new persistent root, CoreObject produces a new UUID triplet based 
 * on: 
 *
 * <deflist>
 * <term>a persistent root</term><desc>a branch collection that results in
 * a history graph describing all the changes made to a document
 * (document has a very loose meaning here)</desc>
 * <term>a branch</term><desc>the persistent root initial branch</desc>
 * <term>a root object</term><desc>the document main object e.g. the top node
 * of a structed document, a photo or contact object</desc>
 * </deflist>
 *
 * The persistent root UUID and branch UUID are unique (never reused) accross 
 * all CoreObject stores, unless a persistent root has been replicated accross 
 * stores.
 *
 * Generally speaking, CoreObject constructs (branches, revisions, objects,
 * stores etc.) are not allowed to share the same UUID. For the replication 
 * case, constructs using the same UUID are considered to be identical (same 
 * type and data) but replicated. For now, replication support is restricted 
 * to collaborative editing (the synchronization protocol is discussed in 
 * COSynchronizerClient).
 *
 * For each persistent root, the root object UUID is reused accross branches.
 * For a persistent root cheap copy, the root object UUID of the parent 
 * persistent root is reused. As such, use -[COPersistentRoot UUID] to track 
 * top-level objects in the CoreObject store.
 *
 * @section Common Use Cases
 *
 * The most common use case would be accesssing the object graph through
 * -objectGraphContext (if branches aren't being used by the application).
 *
 * @section Attributes and Metadata
 *
 * The -metadata property can be set to a JSON compatible NSDictionary to store 
 * arbitrary application metadata. This property is persistent, but not 
 * versioned (although metadata changes can will be undone/redone by 
 * COUndoTrack, if the commit that changes the metadata is recorded to an  
 * undo track).
 *
 * @section Branches
 *
 * Branches act similarly to git in that a branch is a movable pointer on to 
 * the history graph. See COBranch for more detail. 
 *
 * New persistent roots contains just a single branch (see -branches).
 *
 * You can ignore the COBranch API and just use COPersistentRoot to access the 
 * object graph with -objectGraphContext.
 *
 * -objectGraphContext represents a dynamically tracked current branch, that 
 * presents another content, every time -currentBranch is set to another branch.
 *
 * @section Creation
 *
 * Persistent roots are never instantiated directly, but can be created with 
 * -[COEditingContext insertNewPersistentRootWithRootObject:] or 
 * -[COEditingContext insertNewPersistentRootWithEntityName:]. A persistent 
 * root doesn't become persistent until it gets committed to the store. 
 *
 * You can access uncommitted persistent roots or recreate previously committed 
 * ones, through -[COEditingContext persistentRootForUUID:] or 
 * -[COEditingContext persistentRoots].
 *
 * @section Cheap Copies
 *
 * Making a cheap copy of a persistent root creates a new persistent root (with
 * a new UUID) and a single branch (also with a new UUID), however the current 
 * revision of the new branch will be set to the revision where the cheap copy 
 * was made. See -[COBranch makePersistentRootCopyFromRevision:] or 
 * -[COBranch makePersistentRootCopy].
 *
 * The copy is a true copy, in that it can have no observable effect on the 
 * source persistent root. However, the fact that it's a cheap copy will be 
 * evident in the interconnected history graphs.
 *
 * @section Deletion
 *
 * CoreObject uses an explicit deletion model for Persistent Roots, controlled
 * by the -deleted flag. Modifying the flag marks the persistent root as having
 * changes to commit. A persistent root with the -deleted flag set on disk is
 * like a file in the trash. It can be undeleted by simply setting the -deleted 
 * flag to NO and committing that change. 
 *
 * Only when the deleted flag is set to YES (and committed), is it possible for
 * CoreObject to irreversibly delete the underlying storage of the persistent 
 * root.
 * 
 * Currently, the only way to do this is to call a lower level store API, however
 * this functionality will probably be exposed in COEditingContext at some point.
 *
 * @section Cross Persistent Root References
 *
 * CoreObject supports to create references to other root objects accross 
 * persistent roots:
 *
 * <list>
 * <item>unidirectional references to a specific branch (can be any branch 
 * including the current branch)</item>
 * <item>bidirectional references accross two dynamically tracked current 
 * branches</item>
 * </list>
 *
 * For creating dynamically tracked references to a -currentBranch, -rootObject 
 * must be used as the object being referred from another persistent root. For 
 * bidirectional references, the relationship cache will ensure the consistency 
 * is maintained even in case the current branch is changed on either side.
 *
 * For creating references to a specific branch, the root object being referred 
 * from another persistent root, can be any root object, except  
 * -[COPersistentRoot rootObject]. You would usually use -branches, 
 * -branchForUUID: or -currentBranch to get a specific branch, then access its 
 * root object. 
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
/**
 * The metadata in JSON format attached to the persistent root.
 *
 * Any changes to the metadata is saved on the next persistent root commit.
 *
 * You must never overwrite any existing metadata set by CoreObject.
 */
@property (nonatomic, readwrite, copy) NSDictionary *metadata;
/**
 * The persistent root deletion status.
 *
 * If the persistent root is marked as deleted, the deletion is committed to the 
 * store on the next editing context commit.
 *
 * If set to YES for an uncommitted branch, the branch isn't staged for 
 * deletion, but immediately discarded. As a result, a deleted uncommitted 
 * branch cannot be undeleted.
 *
 * TODO: Document the current branch deletion behavior (either on -currentBranch 
 * or in -branches for the current branch UUID). If supported, we should  
 * explain how a new current branch is picked.
 */
@property (nonatomic, assign, getter=isDeleted) BOOL deleted;
/**
 * The newest head revision date among all branches.
 *
 * Changing a branch current revision doesn't alter the returned date. See 
 * -[COBranch currentRevision].
 *
 * See -[COBranch headRevision] and -[CORevision date].
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
 * Returns YES if this persistent root is a copy (-parentPersistentRoot != nil).
 *
 * See -[COBranch isCopy].
 */
@property (nonatomic, readonly) BOOL isCopy;
/**
 * Returns attributes of the persistent root as reported by the store.
 *
 * See COPersistentRootAttributeExportSize, COPersistentRootAttributeUsedSize.
 */
@property (nonatomic, readonly) NSDictionary *attributes;
/**
 * The user-facing name of the persistent root. This property is provided for
 * convenience; it is implemented on top of the metadata property.
 *
 * Because it's stored in the metadata dictionary, changes to the name are visible
 * across all revisions and branches.
 *
 * You could also store a document name in
 * the root object's -name property (see -[COObject name]), which would have the
 * expected consequences: changing the name would cause a new revision to be committed, 
 * old revisions would still use the old name, and different branches could have different names
 * for the document.
 *
 * TODO: Rename to -displayName or -label to emphasize that this is the user-facing name?
 */
@property (nonatomic, readwrite, copy) NSString *name;

/** @taskunit Accessing Branches */


/**
 * The branch that opens when double-clicking a persistent root to edit it.
 *
 * Also used to resolve inter-persistent root references to this persistent root 
 * when no explicit branch is provided.
 *
 * Changing this value stages it for commit; upon the next persistent root 
 * commit, the change is saved to disk and replicated to other applications.
 *
 * TODO: Document the deletion behavior for [self.currentBranch setDeleted: YES]. 
 */
@property (nonatomic, strong) COBranch *currentBranch;
/**
 * All the branches owned by the persistent root (excluding those that are 
 * marked as deleted on disk), plus those pending insertion and undeletion (and 
 * minus those pending deletion).
 *
 * The returned branches never contains the -currentBranch object, but contains 
 * another current branch instance (both instances use the same UUID).
 */
@property (nonatomic, readonly) NSSet *branches;
/**
 * All the branches marked as deleted on disk, excluding those that are pending 
 * undeletion, plus those pending deletion.
 *
 * TODO: Document if the current branch UUID can appear among the returned 
 * branches.
 */
@property (nonatomic, readonly) NSSet *deletedBranches;
/**
 * Returns the branch using the given UUID or nil.
 *
 * The persistent root retains the returned branch.
 *
 * This method can return the same branches than -branches and -deletedBranches 
 * (including those pending deletion and undeletion), but the loading is 
 * restricted to the requested branch.
 *
 * For the current branch UUID, never returns the -currentBranch object, but a 
 * distinct current branch instance (both instances use the same UUID).
 *
 * See also -setDeleted:.
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
@property (nonatomic, readonly) BOOL hasChanges;
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
/**
 * Returns whether the persistent root's editing context has relinquished
 * control over this object. If YES, this instance can no longer be used
 * and calling any methods may throw an exception
 */
@property (nonatomic, readonly) BOOL isZombie;


/** @taskunit Convenience */


/**
 * Shorthand for <code>self.objectGraphContext.rootObject</code>.
 *
 * You can use this root object to create a cross persistent reference that 
 * dynamically tracks the current branch. If the receiver's current branch is
 * changed, this object is updated in-place to reflect the new current branch.
 * By extension, if there are cross-persistent root references in other persistent
 * roots to this root object, the branch switch is immediately visible through those
 * references.
 *
 * If you use <code>self.currentBranch.rootObject</code> or
 * <code>otherBranch.rootObject</code>, the cross persistent root reference
 * in another persistent root will track a specific branch. For example, even 
 * if the current branch changes in the receiver, the other persistent root 
 * will continue to refer to the root object of the previous current branch.
 */
@property (nonatomic, strong) id rootObject;
/**
 * Shorthand for <code>[self.objectGraphContext loadedObjectForUUID:]</code>.
 */
- (COObject *)loadedObjectForUUID: (ETUUID *)uuid;
/**
 * Shortcut for <code>self.currentBranch.currentRevision</code>.
 *
 * For a new persistent root, the revision is nil, unless it is a cheap copy. 
 * See -[COBranch makeCopyFromRevision:].
 */
@property (nonatomic, strong) CORevision *currentRevision;
/**
 * Shortcut for <code>self.currentBranch.headRevision</code>.
 */
@property (nonatomic, strong) CORevision *headRevision;
/**
 * Shorthand for <code>self.editingContext.store</code>.
 */
@property (nonatomic, readonly) COSQLiteStore *store;
/**
 * Returns the object graph that dynamically tracks the -currentBranch.
 *
 * This object graph context is not the same than 
 * <code>self.currentBranch.objectGraphContext</code>, although its content
 * is the same (their item graphs are equal). For the same inner object UUID, 
 * both use distinct inner object instances.
 *
 * When -setCurrentBranch: is called, this object graph content changes. It is 
 * updated with -[COObjectGraphContext setItemGraph:], to present the same 
 * content than self.currentBranch.objectGraphContext.
 *
 * This object graph context and <code>self.currentBranch.objectGraphContext</code>
 * are kept in sync at commit time. There is a one-way update, so both are not 
 * allowed to contain changes, otherwise an assertion occurs at commit time.
 * If -objectGraphContext or <code>self.currentBranch.objectGraphContext</code>
 * contains some changes, a commit must be done, to start making changes to its 
 * counterpart.
 *
 * See also -allObjectGraphContexts and -rootObject (for cross persistent root 
 * references).
 */
@property (nonatomic, readonly) COObjectGraphContext *objectGraphContext;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the object graphs for the -branches (if they have been instantiated),
 * plus the object graph that dynamically tracks the -currentBranch (see -objectGraphContext).
 */
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
                       error: (COError **)anError;
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
 *
 * Tentative API...
 */
- (COObjectGraphContext *)objectGraphContextForPreviewingRevision: (CORevision *)aRevision;


/** @taskunit Description */


/**
 * Returns a short description to summarize the receiver.
 */
@property (nonatomic, readonly, copy) NSString *description;
/**
 * Returns a multi-line description including informations about the branches,  
 * deletion status, attached metadata and pending changes.
 */
@property (nonatomic, readonly) NSString *detailedDescription;


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
