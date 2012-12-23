#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COPersistentRoot;
@class COStore, CORevision, COObject, COGroup, COSmartGroup, COCommitTrack, COError;

@protocol COPersistentObjectContext <NSObject>
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
	ETUUID *_uuid;
	COStore *_store;
	int64_t _maxRevisionNumber;
	int64_t _latestRevisionNumber;
	ETModelDescriptionRepository *_modelRepository;
	/** Loaded (or inserted) persistent roots by UUID */
	NSMutableDictionary *_loadedPersistentRoots;
	NSMutableSet *_deletedPersistentRoots;
	COError *_error;
}

/** @taskunit Accessing the current context */

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

/** @taskunit Creating a new context */

/**
 * Returns a new autoreleased context initialized with the store located at the 
 * given URL, and with no upper limit on the max revision number.
 *
 * See also -initWithStore:maxRevisionNumber: and -[COStore initWithURL:].
 */
+ (COEditingContext *)contextWithURL: (NSURL *)aURL;

/**
 * Initializes a context which persists its content in the given store.
 */
- (id)initWithStore: (COStore *)store;

/**
 * <init />
 * Initializes a context which persists its content in the given store, 
 * fixing the maximum revision number that can be loaded of an object.
 *
 * If the store is nil, the context content is not persisted.
 *
 * If maxRevisionNumber is zero, then there is no upper limit on the revision 
 * that can be loaded.
 */
- (id)initWithStore: (COStore *)store maxRevisionNumber: (int64_t)maxRevisionNumber;
/**
 * Initializes the context with no store. 
 * As a result, the context content is not persisted.
 */
- (id)init;

/** @taskunit Special Groups and Libraries */

/**
 * Returns a group listing every core object in the store.
 */
- (COSmartGroup *)mainGroup;
/**
 * Returns a group listing the libraries in the store.
 */
- (COGroup *)libraryGroup;

/** @taskunit Store and Metamodel Access */

/**
 * Returns the store for which the editing context acts a working copy.
 */
- (COStore *)store;
/**
 * Returns the latest revision number which might be the same than the one 
 * returned by -[COStore latestRevisionNumber], when multiple editing contexts 
 * are accessing the store simultaneously.
 */
- (int64_t)latestRevisionNumber;
/**
 * Returns the maximun revision that can be loaded for objects in persistent 
 * roots.
 *
 * If the returned value is zero, there is no upper limit on the revision that
 * can be loaded.
 *
 * By default, returns zero. 
 */
- (int64_t)maxRevisionNumber;
/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the persistent objects editable in the context.
 */
- (ETModelDescriptionRepository *)modelRepository;

/** @taskunit Managing Persistent Roots */

- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)aUUID;
- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName;
- (COPersistentRoot *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject;
- (void)deletePersistentRootForRootObject: (COObject *)aRootObject;

@property (nonatomic, copy, readonly) NSSet *insertedPersistentRoots;
@property (nonatomic, copy, readonly) NSSet *deletedPersistentRoots;

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
 * See also -objectWithUUID:atRevision: and -loadedObjectForUUID:.
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid;
/** 
 * Returns the object identified by the UUID, by loading it to the given 
 * revision when no instance managed by the receiver is present in memory.
 *
 * When the UUID doesn't correspond to a persistent object, returns nil.
 *
 * For a nil revision, the object is loaded is loaded at its last revision.
 *
 * When the object is a inner object, the last revision is the one that is tied  
 * to its root object last revision. 
 *
 * When the object is already loaded, and its revision is not the requested 
 * revision, raises an invalid argument exception.
 *
 * See also -loadedObjectForUUID:. 
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid atRevision: (CORevision *)revision;

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

- (COPersistentRoot *)makePersistentRoot;

/** @taskunit Committing Changes */

/**
 * Commits the current changes to the store and returns the resulting revisions.
 *
 * See -commitWithType:shortDescription: and -commitWithMetadata:.
 */
- (NSArray *)commit;
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
/** 
 * Returns the last commit error, usually involving one or several validation 
 * issues.
 *
 * When commit methods return a non-empty revision array, the error is nil.
 */
- (NSError *)error;

/** @taskunit Legacy */
 
/**
 * This method is deprecated.
 *
 * You must now use -insertNewPersistentRootWithEntityName: and sent -rootObject 
 * to the resulting context to get the same result.
 */
- (id)insertObjectWithEntityName: (NSString *)anEntityName;

/** @taskunit Private */

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the object identified by the UUID, by loading it to the given 
 * revision when no instance managed by the receiver is present in memory, and 
 * initializing it to use the given entity in such a case.
 * 
 * The class bound to the given entity name in the model repository is used to 
 * instantiate the loaded object (if loading is required).
 *
 * This method constraints are covered in -objectWithUUID:atRevision:.
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid 
                  entityName: (NSString *)name 
                  atRevision: (CORevision *)revision;
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
@end

extern NSString *COEditingContextDidCommitNotification;

extern NSString *kCOEditingContextUUIDKey;
extern NSString *kCORevisionNumbersKey;
extern NSString *kCORevisionsKey;
