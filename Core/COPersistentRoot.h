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
	COEditingContext *_parentContext;
    
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
}

/** @taskunit Debugging */

/** @taskunit Persistent Root Properties */

/**
 * Returns YES.
 *
 * See also -[NSObject isPersistentRoot].
 */
@property (nonatomic, readonly) BOOL isPersistentRoot;
/**
 * The UUID that is bound to a single persistent root per CoreObject store.
 *
 * Two persistent roots belonging to distinct CoreObject stores cannot use the 
 * same UUID unless they point to the same persistent root replicated accross 
 * stores.
 * For now, persistent root replication accross distinct CoreObject stores 
 * is not supported and might never be.
 */
@property (nonatomic, readonly) ETUUID *persistentRootUUID;

/**
 * The editingBranch is not a persistent value, but is used by 
 * COPersistentRoot methods like -rootObject, -objectGraph, etc. as the
 * default object graph presented by the COPersistentRoot.
 *
 * By default, -editingBranch just returns -currentBranch. However, if you
 * call -setEditingBranch: explicitly, then that branch will be used and
 * -editingBranch will no longer track -currentBranch.
 */
@property (nonatomic, readwrite, retain) COBranch *editingBranch;

/**
 * The branch that opens when double-clicking a persistent root to edit it.
 * Also used to resolve inter-persistent root references to this persistent
 * root when no explicit branch. 
 *
 * Changing this value stages it for commit; upon the next -commit,
 * the change is saved to disk and replicated to other applications.
 */
@property (nonatomic, readwrite, retain) COBranch *currentBranch;

@property (nonatomic, readonly) NSSet *branches;

- (COBranch *)branchForUUID: (ETUUID *)aUUID;

/**
 * Returns the object graph for the edited branch
 */
@property (nonatomic, readonly) COObjectGraphContext *objectGraph;

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
 */
@property (nonatomic, retain) id rootObject;
/**
 * The UUID of the root object.
 *
 * Never returns nil even when -rootObject is nil. This method can query the 
 * store to retrieve the UUID.
 *
 * See also -[COStore rootObjectUUIDForPersistentRootUUID:].
 */
@property (nonatomic, readonly) ETUUID *rootObjectUUID;
/**
 * The persistent root revision.
 *
 * If the persistent root is not yet committed, returns nil for a freshly
 * created persistent root, or returns the parent revision for a persistent
 * root created by copying.
 *
 * This revision applies to the root object and inner objects. See -[COObject revision].
 *
 * The revision is usually equal to 
 * <code>[[self commitTrack] currentNode] revision]</code> but this doesn't hold 
 * in the following cases:
 *
 * <list>
 * <item>A max revision has been set on the parent context (as a result, the 
 * revision is less than or equal to -[COEditingContext maxRevision]).</item>
 * <item>The persistent root is not loaded or has been unloaded (the revision is 
 * nil).</item>
 * </list>
 */
@property (nonatomic, retain) CORevision *revision;
/**
 * The store for which the editing context acts a working copy.
 *
 * The store is the same than the parent context.
 *
 * See also -[COEditingContext store].
 */
@property (nonatomic, readonly) COSQLiteStore *store;

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
@property (nonatomic, readonly) COEditingContext *parentContext;
/**
 * Returns -parentContext.
 *
 * See also -[COPersistentObjectContext editingContext].
 */
@property (nonatomic, readonly) COEditingContext *editingContext;



/** @taskunit Object Access and Loading */

/**
 * Returns the object identified by the UUID, by loading it to the given
 * revision when no instance managed by the receiver is present in memory.
 *
 * When the UUID isn't bound to a persistent object owned by the persistent root,
 * returns nil (unless it is a commit track UUID or another persistent root UUID,
 * but these are special cases discussed in the last paragraphs).
 *
 * For a nil revision, the object is loaded is loaded at its last revision.
 *
 * When the object is a inner object, the last revision is the one that is tied
 * to its root object last revision.
 *
 * When the object is already loaded, and its revision is not the requested
 * revision, raises an invalid argument exception.
 *
 * When the UUID is a persistent root UUID, the root object of the persistent
 * root is returned (the persistent root is loaded if needed).
 *
 * When the UUID is a branch UUID, the persistent root for the branch is looked
 * up. If the persistent root is not available, it is loaded for the requested
 * branch. If the persistent root is already loaded, a branch mismatch is
 * possible between the current branch UUID and the given branch UUID. For a
 * mismatch, an exception is raised, otherwise the root object of the persistent
 * root is returned.<br />
 * For a more detailed discussion about branching issues, see COCommitTrack
 * documentation.
 *
 * See also -loadedObjectForUUID:.
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid;

/**
 * Returns the objects presently managed by the receiver in memory.
 *
 * The returned objects include -insertedObjects.
 *
 * Faults can be included among the returned objects.
 *
 * See also -loadedObjectUUIDs.
 */
- (NSSet *)loadedObjects;
/**
 * Returns the UUIDs of the objects presently managed by the receiver in memory.
 *
 * The returned objects include the inserted object UUIDs.
 *
 * Faults can be count as loaded objects.
 *
 * See also -loadedObjects.
 */
- (NSSet *)loadedObjectUUIDs;
/**
 * Returns the root objects presently managed by the receiver in memory.
 *
 * Faults and inserted objects can be included among the returned objects.
 *
 * The returned objects are a subset of -loadedObjects.
 */
- (NSSet *)loadedRootObjects;
/**
 * Returns the object identified by the UUID if presently loaded in memory.
 *
 * When the object is not loaded, or when there is no persistent object that
 * corresponds to this UUID, returns nil.
 */
- (id)loadedObjectForUUID: (ETUUID *)uuid;

/** @taskunit Pending Changes */

/**
 * Returns the new objects added to the context with -insertObject: and to be
 * added to the store on the next commit.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)insertedObjects;
/**
 * Returns the objects whose properties have been edited in the context and to
 * be updated in the store on the next commit.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)updatedObjects;
/**
 * Returns the UUIDs of the objects updated since the last commit. See -updatedObjects.
 */
- (NSSet *)updatedObjectUUIDs;
/**
 * Returns whether the object has been updated since the last commit. See
 * -updatedObjects.
 *
 * Won't return YES if the object has just been inserted or deleted.
 */
- (BOOL)isUpdatedObject: (COObject *)anObject;
/**
 * Returns the union of the inserted, updated and deleted objects. See
 * -insertedObjects, -updatedObjects and -deletedObjects.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)changedObjects;
/**
 * Returns whether any object has been inserted, deleted or updated since the
 * last commit.
 *
 * See also -changedObjects.
 */
- (BOOL)hasChanges;
/**
 * Discards the uncommitted changes to reset the context to its last commit state.
 *
 * Every object insertion or deletion is cancelled.<br />
 * Every updated property is reverted to its last committed value.
 *
 * -insertedObjects, -updatedObjects, -deletedObjects and -changedObjects will
 * all return empty sets once the changes have been discarded.
 *
 * See also -discardChangesInObject:.
 */
- (void)discardAllChanges;
/**
 * Discards the uncommitted changes in a particular object to restore the state
 * it was in at the last commit.
 *
 * Every updated property in the object is reverted to its last committed value.
 *
 * See also -discardAllChanges:.
 */
- (void)discardChangesInObject: (COObject *)object;

/** @taskunit Object Insertion */

/**
 * Creates a new instance of the given entity name (assigning the instance a new 
 * UUID) and returns the object.
 *
 * The entity name must correspond to the COObject class or a subclass. Thereby
 * returned objects will be COObject class or subclass instances in all cases.
 *
 * This is the factory method for COObject class hierarchy.
 */
- (id)insertObjectWithEntityName: (NSString *)aFullName;


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

/** @taskunit Framework Private */

/**
 * <init />
 * This method is only exposed to be used internally by CoreObject.
 *
 * If info is nil, creates a new persistent root.
 *
 * cheapCopyRevisionID is normally nil, and only set to create a cheap copy.
 * See -[COBranch makeCopyFromRevision:]
 */
- (id) initWithInfo: (COPersistentRootInfo *)info
cheapCopyRevisionID: (CORevisionID *)cheapCopyRevisionID
      parentContext: (COEditingContext *)aCtxt;

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits the current changes to the store with the provided metadatas and
 * returns the resulting revision.
 *
 * The commit procedure is the parent context responsability, the parent context 
 * calls back -saveCommitWithMetadata:.
 */
- (CORevision *)commitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Extracts the current changes, saves them to the store with the provided 
 * metadatas and returns the resulting revision.
 */
- (void) saveCommitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the class that represents a reference to the provided root object
 * argument.
 *
 * Valid reference kinds are COCommitTrack and COPersistentRoot classes.
 *
 * The root object argument must be belong to another persistent root, otherwise
 * NSInvalidArgumentException is raised.
 */
- (Class)referenceClassForRootObject: (COObject *)aRootObject;

- (COPersistentRootInfo *) persistentRootInfo;

- (void) reloadPersistentRootInfo;

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev;

- (BOOL) isPersistentRootCommitted;

@end
