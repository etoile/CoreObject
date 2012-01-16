#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COStore, CORevision, COObject, COGroup, COSmartGroup, COCommitTrack;

/**
 * An object context is like a working copy in a revision control system.
 *
 * It queues changes and then attempts to commit them to the store.
 */
@interface COEditingContext : NSObject
{
	@private
	COStore *_store;
	int64_t _maxRevisionNumber;

	ETModelDescriptionRepository *_modelRepository;

	/**
	 * UUID of root object -> revision
	 */
	NSMutableDictionary *_rootObjectRevisions;
	/**
	 * UUID of root object -> commit track
	 */
	NSMutableDictionary *_rootObjectCommitTracks;

	/** 
	 * UUID -> loaded or inserted object
	 */
	NSMutableDictionary *_instantiatedObjects;
	NSMutableSet *_insertedObjects;
	NSMutableSet *_deletedObjects;
	/**
	 * Updated object -> array of updated properties
	 *
	 * New entries must be inserted with -markObjectUpdated:forProperty:.
	 */
	NSMapTable *_updatedPropertiesByObject; 
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
 * Returns the model description repository, which holds the metamodel that 
 * describes all the persistent objects editable in the context.
 */
- (ETModelDescriptionRepository *)modelRepository;
/**
 * Returns the class bound to the entity description in the model repository.
 */
- (Class)classForEntityDescription: (ETEntityDescription *)desc;

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
 * Faults can be included among the returned objects.
 */
- (NSSet *)loadedObjects;
/**
 * Returns the root objects presently managed by the receiver in memory.
 *
 * Faults can be included among the returned objects.
 *
 * The returned objects are a subset of -loadedObjects.
 */
- (NSSet *)loadedRootObjects;
/** Returns the object identified by the UUID if presently loaded in memory. 
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

/** @taskunit Object Insertion */

/**
 * Creates a new instance of the given entity name (assigning the instance a new UUID)
 * and returns the object.
 *
 * The new instance is a root object.
 *
 * See also -insertObjectWithEntityName:rootObject:.
 */
- (id)insertObjectWithEntityName: (NSString *)aFullName;
/**
 * Creates a new instance of the given entity name (assigning the instance a new UUID)
 * under the specified root object and returns the object. 
 *
 * The entity name must correspond to the COObject class or a subclass. Thereby 
 * returned objects will be COObject class or subclass instances in all cases.
 *
 * When rootObject is nil, the new instance is a root object.
 * 
 * This is the factory method for COObject class hierarchy.
 */
- (id)insertObjectWithEntityName: (NSString *)aFullName rootObject: (COObject *)rootObject;
/**
 * Creates a new instance of the given class (assigning the instance a new UUID)
 * and returns the object.
 *
 * When rootObject is nil, the new instance is a root object.
 *
 * See also -insertObjectWithEntityName:rootObject:.
 */
- (id)insertObjectWithClass: (Class)aClass rootObject: (COObject *)rootObject;
/**
 * Copies an object from another context into this context.
 *
 * The copy refers to the same underlying persistent object (same UUID).
 */
- (id)insertObject: (COObject *)sourceObject;
/**
 * Creates a copy of an object (assigning it a new UUID), including copying
 * all strongly contained objects (composite properties).
 */
- (id)insertObjectCopy: (COObject *)sourceObject;

/** @taskunit Object Deletion */

/**
 * Schedules the object to be deleted both in memory and in store on the next 
 * commit.
 */
- (void)deleteObject: (COObject *)anObject;

/** @taskunit Committing Changes */

/**
 * Commits the current changes to the store.
 */
- (void)commit;
/**
 * Commits the current changes to the store with some basic metadatas.
 *
 * The descriptions will be visible at the UI level when browsing the history.
 */
- (void)commitWithType: (NSString *)type
      shortDescription: (NSString *)shortDescription
       longDescription: (NSString *)longDescription;

/** @taskunit Private */

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Inserts the object into the context by checking the relationship consistency 
 * if requested.
 *
 * When the object is not yet persistent, it is inserted into the context and 
 * the new UUID hint is ignored.
 *
 * When the object is already persistent, based on the new UUID hint, the new 
 * object inserted into the context will be: 
 *
 * <deflist>
 * <item>newUUID is YES</item><desc>a copy (new instance and UUID)</desc>
 * <item>newUUID is NO</item><desc>a new context-relative instance (new 
 * instance but same UUID)</desc>
 * </deflist>
 *
 * For a persistent object, multiples instance can exist in the same process, 
 * one per editing context.
 *
 * You can pass an object that belongs to another context to this method.
 */
- (id)insertObject: (COObject *)sourceObject withRelationshipConsistency: (BOOL)consistency newUUID: (BOOL)newUUID;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits the current changes to the store with the provided metadatas.
 */
- (void)commitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the context a property value has changed in a COObject class or 
 * subclass instance.
 */
- (void)markObjectUpdated: (COObject *)obj forProperty: (NSString *)aProperty;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the revision of the root object that owns the object.
 *
 * When a root object is passed rather than a inner object, returns its revision 
 * as you would expect it.
 */
- (CORevision *)revisionForObject: (COObject *)object;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the commit track bound to the root object that owns the object.
 */
- (COCommitTrack *)trackWithObject: (COObject *)object;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Loads the object at its last revision.
 *
 * For a inner object, its last revision is its root object last revision.
 */
- (void)loadObject: (COObject *)obj;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Reloads the root object and its inner objects at a new revision.
 */
- (void)reloadRootObjectTree: (COObject *)object
                  atRevision: (CORevision *)revision;
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
@end

extern NSString *COEditingContextDidCommitNotification;

extern NSString *kCORevisionNumbersKey;
extern NSString *kCORevisionsKey;
