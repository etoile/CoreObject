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
    
    /**
     * Weak reference
     */
	COEditingContext *__weak _parentContext;
    
    /**
     * State of the persistent root and its branches as loaded from the store.
     * We don't modify this as changes are being staged in-memory (class should be immutable),
     * but it is updaded when we make a commit or read from disk.
     *
     * If nil, this is a newly created persistent root
     */
    COPersistentRootInfo *_savedState;

    /**
     * COBranch objects indexed by ETUUID
     */
    NSMutableDictionary *_branchForUUID;

    /**
     * Used to stage a change to the current branch
     */
    ETUUID *_currentBranchUUID;
    
    /**
     * UUID of branch being edited. Not persistent.
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
 * stores.
 * For now, persistent root replication accross distinct CoreObject stores 
 * is not supported and might never be.
 */
@property (weak, nonatomic, readonly) ETUUID *persistentRootUUID;

/**
 * The persistent root deletion status.
 *
 * If the persistent root is marked as deleted, the deletion is committed to the store
 * on the next editing context commit.
 */
@property (readwrite, nonatomic, getter=isDeleted, setter=setDeleted:) BOOL deleted;

/**
 * The editingBranch is not a persistent value, but is used by 
 * COPersistentRoot methods like -rootObject, -objectGraphContext, etc. as the
 * default object graph presented by the COPersistentRoot.
 *
 * By default, -editingBranch just returns -currentBranch. However, if you
 * call -setEditingBranch: explicitly, then that branch will be used and
 * -editingBranch will no longer track -currentBranch.
 */
@property (nonatomic, readwrite, strong) COBranch *editingBranch;

/**
 * The branch that opens when double-clicking a persistent root to edit it.
 * Also used to resolve inter-persistent root references to this persistent
 * root when no explicit branch. 
 *
 * Changing this value stages it for commit; upon the next -commit,
 * the change is saved to disk and replicated to other applications.
 */
@property (nonatomic, readwrite, strong) COBranch *currentBranch;

@property (weak, nonatomic, readonly) NSSet *branches;

// TODO: Refactor to branchesPendingInsertion, branchesPendingDeletion, branchesPendingUndeletion.
// Add deletedBranches property listing the branches
// that are marked as deleted on disk.
@property (weak, nonatomic, readonly) NSSet *insertedBranches;
@property (weak, nonatomic, readonly) NSSet *deletedBranches;

- (COBranch *)branchForUUID: (ETUUID *)aUUID;


/** @taskunit Editing Context Nesting */


/**
 * The editing context managing the receiver.
 *
 * The parent context makes possible to edit multiple persistent roots 
 * simultaneously and provide an aggregate view on the editing underway.
 *
 * COPersistentRoot objects are instantiated and released by the
 * parent context.
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


/** @taskunit Object Access and Loading */


/** 
 * @taskunit Pending Changes 
 */

/**
 * Returns whether any object has been inserted, deleted or updated since the
 * last commit.
 *
 * See also -changedObjects.
 */
- (BOOL)hasChanges;
- (void)discardAllChanges;


/** @taskunit Convenience */


/**
 * The entry point to navigate the object graph bound to the persistent root.
 *
 * The returned object is COObject class or subclass instance.
 *
 * A root object isn't a core object and doesn't represent a core object either.
 * The persistent root represents the core object. As such, use the persistent
 * root UUID to refer to core objects and never
 * <code>[[self rootObject] UUID]</code>.
 *
 * For now, this object must remain the same in the entire persistent root
 * history including the branches (and derived cheap copies) due to limitations
 * in EtoileUI.
 *
 * Shorthand for [[[self editingBranch] objectGraphContext] rootObject]
 */
@property (nonatomic, strong) id rootObject;

/**
 * Shorthand for [[[self editingBranch] objectGraphContext] objectWithUUID:]
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid;

/**
 * Shortcut for <code>[[self editingBranch] revision]</code>
 */
@property (nonatomic, strong) CORevision *revision;

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
 * Commits the current changes to the store and returns the resulting revision.
 *
 * See -commitWithType:shortDescription: and -commitWithMetadata:.
 */
- (CORevision *)commit;
/**
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
- (CORevision *)commitWithType: (NSString *)type
              shortDescription: (NSString *)shortDescription;

/**
 * Returns a read-only object graph context of the contents of a revision.
 * Tentative API...
 */
- (COObjectGraphContext *) objectGraphContextForPreviewingRevision: (CORevision *)aRevision;

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
