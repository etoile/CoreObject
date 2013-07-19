#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COPersistentRoot, COEditingContext;
@class COSQLiteStore, CORevision, COObject, COGroup, COSmartGroup, COBranch, COError, COPersistentRootInfo;

// I'm skeptical that there is ever a legitimate case where code is working
// with an id<COPersistentObjectContext> and doesn't know whether it's an
// editing context or persistent root... but I guess it's harmless to keep for
// now --Eric
@protocol COPersistentObjectContext <NSObject>
/**
 * Returns YES when the receiver is an editing context, otherwise returns NO
 * when the receiver is a persistent root.
 *
 * See COEditingContext and COPersistentRoot.
 */
- (BOOL)isEditingContext;
/**
 * Returns the editing context for the receiver.
 *
 * Either returns self or a parent context.
 *
 * See COEditingContext and -[COPersistentRoot parentContext].
 */
- (COEditingContext *)editingContext;
/**
 * See -[COEditingContext discardAllChanges] and -[COPersistentRoot discardAllChanges].
 */
- (void)discardAllChanges;
/**
 * See -[COEditingContext hasChanges] and -[COPersistentRoot hasChanges].
 */
- (BOOL)hasChanges;
@end

/**
 * An editing context exposes a CoreObject store snapshot as a working copy 
 * (in revision control system terminology).
 *
 * It queues changes and when the user requests it, it attempts to commit them 
 * to the store.
 */
@interface COEditingContext : NSObject <COPersistentObjectContext>
{
	@private
	COSQLiteStore *_store;
	ETModelDescriptionRepository *_modelRepository;
	/** Loaded (or inserted) persistent roots by UUID */
	NSMutableDictionary *_loadedPersistentRoots;
    /** Set of persistent roots pending deletion */
	NSMutableSet *_deletedPersistentRoots;
	COError *_error;
}


/** @taskunit Creating a new context */

/**
 * Returns a new autoreleased context initialized with the store located at the 
 * given URL, and with no upper limit on the max revision number.
 *
 * See also -initWithStore: and -[COStore initWithURL:].
 */
+ (COEditingContext *)contextWithURL: (NSURL *)aURL;

/**
 * Initializes a context which persists its content in the given store.
 */
- (id)initWithStore: (COSQLiteStore *)store;

/**
 * Initializes the context with no store. 
 * As a result, the context content is not persisted.
 */
- (id)init;

/** @taskunit Type Querying */

/**
 * Returns YES.
 *
 * See also -[NSObject isEditingContext].
 */
@property (nonatomic, readonly) BOOL isEditingContext;

/** @taskunit Editing Context Nesting */

/**
 * Returns self.
 *
 * See also -[COPersistentObjectContext editingContext].
 */
@property (nonatomic, readonly) COEditingContext *editingContext;

/** @taskunit Special Groups and Libraries */

/**
 * Returns a set of every persistent root in the store, plus those
 * pending commit (and minus those pending deletion).
 */
- (NSSet *)persistentRoots;
/**
 * Returns a group listing the libraries in the store.
 *
 * By default, it contains the libraries listed as methods among
 * COEditingContext(COCommonLibraries).
 */
- (COGroup *)libraryGroup;

/** @taskunit Store and Metamodel Access */

/**
 * Returns the store for which the editing context acts a working copy.
 */
- (COSQLiteStore *)store;

/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the persistent objects editable in the context.
 */
- (ETModelDescriptionRepository *)modelRepository;

/** @taskunit Managing Persistent Roots */

- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)aUUID;
- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName;
/**
 * I'm assuming this is the mechanism for copying an embedded object and creating
 * a new persistent root with that copy as the root object?
 *
 * We will need to clarify exactly how it works... presumable it does a regular
 * metamodel driven copy, potentially copying the entire tree of children
 * belonging to aRootObject
 */
- (COPersistentRoot *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject;

// TODO: Should probably change to take a COPersistentRoot
- (void)deletePersistentRootForRootObject: (COObject *)aRootObject;

/** @taskunit Pending Changes */

@property (nonatomic, copy, readonly) NSSet *insertedPersistentRoots;
@property (nonatomic, copy, readonly) NSSet *deletedPersistentRoots;

// TODO: updatedPersistentRoots?
// TODO: changedPersistentRoots?

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
 * Persistent root insertions, deletions, and modifications (e.g., changing
 * main branch, deleting branches, adding branches, editing branch metadata,
 * reverting branch to a past revision) will be cancelled.
 *
 * All uncommitted embedded object edits in child persistent roots will be
 * cancelled.
 *
 * -insertedPersistentRoots, -deletedPersistentRoots  will
 * all return empty sets once the changes have been discarded.
 */
- (void)discardAllChanges;


/** @taskunit Committing Changes */

// TODO: Change to -commitWithError:
/**
 * Commits the current changes to the store and returns the resulting revisions.
 *
 * A batch commit UUID is added to the metadata of each commit to indicate that
 * the individual persistent root commits were made as a batch.
 *
 * See -commitWithType:shortDescription: and -commitWithMetadata:.
 */
- (NSArray *)commit;
// TODO: Change to -commitWithType:shortDescription:error:
/**
 * Commits the current changes to the store with some basic metadatas and 
 * returns the resulting revisions.
 *
 * A commit involving multiple persistent roots is not atomic (more than a single 
 * revision in the returned array).<br />
 * Each returned revision results from an atomic commit on a single persistent 
 * root.
 *
 * Each root object that belong to -changedObjects results in a new revision.
 * We usually advice to commit a single root object at time to prevent multiple
 * revisions per commit.
 *
 * The description will be visible at the UI level when browsing the history.
 *
 * See -commitWithMetadata:.
 */
- (NSArray *)commitWithType: (NSString *)type
           shortDescription: (NSString *)shortDescription;
// TODO: Remove, shouldn't we follow the regular cocoa pattern like:
// -commitWithMetadata: (NSDictionary *) error: (NSError **)
/** 
 * Returns the last commit error, usually involving one or several validation 
 * issues.
 *
 * When commit methods return a non-empty revision array, the error is nil.
 */
- (NSError *)error;

/** @taskunit Private */

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Instantiates, registers among the loaded persistent roots and returns the 
 * persistent root known by the given UUID.
 * Unlike -persistentRootForUUID:, this method doesn't access the store to 
 * retrieve the main branch UUID, but just use the given commit track UUID.
 *
 * In addition, a past revision can be passed to prevent loading the persistent 
 * root at the latest revision.
 */
- (COPersistentRoot *)makePersistentRootWithInfo: (COPersistentRootInfo *)info;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)didFailValidationWithError: (NSError *)anError;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits the current changes to the store with the provided metadatas and
 * returns the resulting revisions.
 */
- (NSArray *)commitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits some changes to the store with the provided metadatas, and returns
 * the resulting revisions.
 *
 * Changes must belong to the given persistent root subset, otherwise they 
 * won't be committed. -hasChanges can still be YES on return.
 */
- (NSArray *)commitWithMetadata: (NSDictionary *)metadata
	restrictedToPersistentRoots: (NSArray *)persistentRoots;
/**
 * <override-never />
 * Tells the receiver that -[COStore finishCommit] just returned.
 *
 * You shouldn't use this method usually. Commit methods automatically calls
 * this method (for both COEditingContext and COPersistentRoot API).
 *
 * If your code uses -[COStore finishCommit] directly (e.g. in a COTrack
 * subclass), you have to call this method explicitly.
 */
- (void)didCommitRevision: (CORevision *)aRevision;

/** @taskunit Deprecated, to be removed */

// I think we agreed these are an "anti-pattern"

/**
 * Returns the context that should be used when none is provided.
 *
 * Factories that create persistent instances in EtoileUI will use this method.
 * As an example, see -[ETLayoutItemFactory compoundDocument].
 */
+ (COEditingContext *)currentContext;
/**
 * Sets the context that should be used when none is provided.
 *
 * See also +currentContext.
 */
+ (void)setCurrentContext: (COEditingContext *)aCtxt;

@end


@interface COEditingContext (Debugging)

/** @taskunit Object Access and Loading */

/**	 
 * Returns the object identified by the UUID, by loading it to its last revision	 
 * when no instance managed by the receiver is present in memory.	 
 *	 
 * When the UUID doesn't correspond to a persistent object, returns nil.	 
 *	 
 * When the object is a inner object, the last revision is the one that is tied	 
 * to its root object last revision.	 
 *	 
 * See also -[COPersistentRoot objectWithUUID:].	 
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
 * Returns the root objects presently managed by the receiver in memory.
 *
 * Faults and inserted objects can be included among the returned objects.
 *
 * The returned objects are a subset of -loadedObjects.
 */
- (NSSet *)loadedRootObjects;

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
 * Returns whether the object has been updated since the last commit. See
 * -updatedObjects.
 *
 * Won't return YES if the object has just been inserted or deleted.
 */
- (BOOL)isUpdatedObject: (COObject *)anObject;
/**
 * Returns the objects deleted in the context with -deleteObject: and to be
 * deleted in the store on the next commit.
 *
 * After a commit, returns an empty set.
 *
 * Doesn't include newly inserted or deleted objects.
 */
- (NSSet *)deletedObjects;
/**
 * Returns the union of the inserted, updated and deleted objects. See
 * -insertedObjects, -updatedObjects and -deletedObjects.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)changedObjects;

@end
