#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COPersistentRoot, COEditingContext, COObjectGraphContext;
@class COSQLiteStore, CORevision, COObject, COGroup, COSmartGroup, COBranch, COError, COPersistentRootInfo, CORevisionID, COPath;
@class COCrossPersistentRootReferenceCache, COUndoStackStore, COEditGroup;

// I'm skeptical that there is ever a legitimate case where code is working
// with an id<COPersistentObjectContext> and doesn't know whether it's an
// editing context or persistent root... but I guess it's harmless to keep for
// now --Eric
/** 
 * Protocol to support managing either persistent roots or inner objects
 * inside an object graph context without knowing the context type in advance.
 *
 * For example, based on -[ETController persistentObjectContext:], a 
 * ETController object can instantiate either persistent roots or inner objects.
 */
@protocol COPersistentObjectContext <NSObject>
@optional
/**
 * See -[NSObject isEditingContext].
 */
- (BOOL)isEditingContext;
/**
 * See -[NSObject isObjectGraphContext].
 */
- (BOOL)isObjectGraphContext;
@required
/**
 * Returns the editing context for the receiver.
 *
 * Either returns self or a parent context.
 *
 * See COEditingContext and -[COPersistentRoot parentContext].
 */
- (COEditingContext *)editingContext;
/**
 * See -[COEditingContext discardAllChanges], -[COPersistentRoot discardAllChanges], 
 * -[COBranch discardAllChanges] and -[COObjectGraphContext discardAllChanges].
 */
- (void)discardAllChanges;
/**
 * See -[COEditingContext hasChanges], -[COPersistentRoot hasChanges], 
 *  -[COBranch hasChanges] and -[COObjectGraphContext hasChanges].
 */
- (BOOL)hasChanges;
@end

/**
 * An editing context exposes a CoreObject store snapshot as a working copy 
 * (in revision control system terminology).
 *
 * It queues changes and when the user requests it, it attempts to commit them 
 * to the store.
 *
 * FIXME: Expand
 *
 * @section Object Equality
 *
 * COEditingContext, COPersistentRoot, COBranch, and COObjectGraphContext
 * do not override -hash or -isEqual:, so instances of these classes are only
 * considered equal to the same instances.
 *
 * These classes form an in-memory view on a database, and the notion
 * of two of these views being equal isn't useful or interesting.
 */
@interface COEditingContext : NSObject <COPersistentObjectContext>
{
	@private
	COSQLiteStore *_store;
	ETModelDescriptionRepository *_modelRepository;
	/** Loaded (or inserted) persistent roots by UUID */
	NSMutableDictionary *_loadedPersistentRoots;
    /** Set of persistent roots pending deletion */
	NSMutableSet *_persistentRootsPendingDeletion;
    /** Set of persistent roots pending undeletion */
	NSMutableSet *_persistentRootsPendingUndeletion;
	COError *_error;
    COCrossPersistentRootReferenceCache *_crossRefCache;     
    /** Undo */
    COUndoStackStore *_undoStackStore;
    BOOL _isRecordingUndo;
    COEditGroup *_currentEditGroup;
    NSString *_undoStackName;
}

/** 
 * @taskunit Creating a new context 
 */

/**
 * Returns a new autoreleased context initialized with the store located at the 
 * given URL.
 *
 * See also -initWithStore: and -[COSQLiteStore initWithURL:].
 */
+ (COEditingContext *)contextWithURL: (NSURL *)aURL;
/**
 * <init />
 * Initializes a context which persists its content in the given store.
 */
- (id)initWithStore: (COSQLiteStore *)store;
/**
 * Initializes the context with no store. 
 * As a result, the context content is not persisted.
 *
 * See also -initWithStore:.
 */
- (id)init;

/** 
 * @taskunit Type Querying 
 */

/**
 * Returns YES.
 *
 * See also -[NSObject isEditingContext].
 */
@property (nonatomic, readonly) BOOL isEditingContext;

/** 
 * @taskunit Editing Context Nesting 
 */

/**
 * Returns self.
 *
 * See also -[COPersistentObjectContext editingContext].
 */
@property (nonatomic, readonly) COEditingContext *editingContext;

/** 
 * @taskunit Accessing All Persistent Roots 
 */

/**
 * Returns all persistent roots in the store (excluding those that are marked as 
 * deleted on disk), plus those pending insertion and undeletion (and minus 
 * those pending deletion).
 */
@property (nonatomic, readonly) NSSet *persistentRoots;
/**
 * Returns persistent roots marked as deleted on disk, excluding those that
 * are pending undeletion.
 */
@property (nonatomic, copy, readonly) NSSet *deletedPersistentRoots;

/** 
 * @taskunit Store and Metamodel Access 
 */

/**
 * Returns the store for which the editing context acts a working copy.
 */
@property (nonatomic, readonly) COSQLiteStore *store;
/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the persistent objects editable in the context.
 */
@property (nonatomic, readonly) ETModelDescriptionRepository *modelRepository;

/** 
 * @taskunit Managing Persistent Roots 
 */

/**
 * Returns the persistent root bound the the given UUID in the store or nil.
 *
 * The editing context retains the returned persistent root.
 */
- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)aUUID;
/**
 * Returns a new persistent root that uses the given root object.
 *
 * The returned persistent root is added to -persistentRootsPendingInsertion 
 * and will be saved to the store on the next commit.
 *
 * The object graph context of the root object must be transient, otherwise 
 * a NSInvalidArgumentException is raised.
 *
 * For a nil root object, raises a NSInvalidArgumentException.
 */
- (COPersistentRoot *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject;
/**
 * Creates a root object of the requested entity and returns a new persistent
 * root using that root object.
 */
- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName;


/**
 * @taskunit Pending Changes 
 */

/**
 * The new persistent roots to be saved in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *persistentRootsPendingInsertion;
/**
 * The persistent roots to be deleted in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *persistentRootsPendingDeletion;
/**
 * The persistent roots to be undeleted in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *persistentRootsPendingUndeletion;

// TODO: updatedPersistentRoots?
// TODO: changedPersistentRoots?

/**
 * Returns whether the context contains uncommitted changes.
 *
 * Persistent root insertions, deletions, and modifications (e.g., changing
 * main branch, deleting branches, adding branches, editing branch metadata,
 * reverting branch to a past revision) all count as uncommitted changes.
 *
 * See also -discardAllChanges.
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
 * -insertedPersistentRoots, -deletedPersistentRoots  will all return empty sets 
 * once the changes have been discarded.
 *
 * See also -hasChanges.
 */
- (void)discardAllChanges;

/** 
 * @taskunit Committing Changes 
 */

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
 * We usually advice to commit a single persistent root at time to prevent 
 * multiple revisions per commit.
 *
 * The description will be visible at the UI level when browsing the history.
 *
 * See -commitWithMetadata:.
 */
- (NSArray *)commitWithType: (NSString *)type
           shortDescription: (NSString *)shortDescription;

/**
 * @taskunit Undo
 */

@property (readwrite, nonatomic, copy) NSString *undoStackName;

/** 
 * @taskunit Framework Private 
 */

/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COPersistentRoot *)insertNewPersistentRootWithRevisionID: (CORevisionID *)aRevid;
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
- (COPersistentRoot *)makePersistentRootWithInfo: (COPersistentRootInfo *)info
                              objectGraphContext: (COObjectGraphContext *)anObjectGraphContext;
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
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (id)crossPersistentRootReferenceWithPath: (COPath *)aPath;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)deletePersistentRoot: (COPersistentRoot *)aPersistentRoot;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)undeletePersistentRoot: (COPersistentRoot *)aPersistentRoot;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COCrossPersistentRootReferenceCache *) crossReferenceCache;

@end


@interface COEditingContext (Debugging)

/** 
 * @taskunit Loaded Objects 
 */

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

/** 
 * @taskunit Pending Changes 
 */

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
 * Returns the union of the inserted and updated objects. See -insertedObjects 
 * and -updatedObjects.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)changedObjects;

@end
