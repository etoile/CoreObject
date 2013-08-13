#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COItemGraph.h>
#import <CoreObject/COEditingContext.h>

@class COPersistentRoot, COBranch, COObject, CORelationshipCache;
@class COItemGraph, COItem;

extern NSString * const COObjectGraphContextObjectsDidChangeNotification;

/**
 * TODO: Write class description
 *
 *
 * @section Object Equality
 *
 * COObjectGraphContext does not override -hash or -isEqual:, so an
 * object graph context is only considered equal to itself.
 *
 * To compare the contents of two COObjectGraphContext instances you can do:
 * [[ctx rootObject] isDeeplyEqual: [ctx2 rootObject]] (FIXME: That method
 * is not exposed in the header and incomplete)
 */
@interface COObjectGraphContext : NSObject <COItemGraph, COPersistentObjectContext>
{
	@private
	ETModelDescriptionRepository *_modelRepository;
	COBranch *_branch;
    ETUUID *_rootObjectUUID;
	/** Loaded (or inserted) objects by UUID */
    NSMutableDictionary *_loadedObjects;
	/** Item graph exposed during loading (nil once the loading is done) */
	id <COItemGraph> _loadingItemGraph;
    NSMutableSet *_insertedObjects;
    NSMutableSet *_updatedObjects;
    NSMapTable *_updatedPropertiesByObject;
}

/**
 * @taskunit Creation
 */

/**
 * Returns a new autoreleased transient object graph context using the main 
 * model description repository.
 *
 * See -[ETModelDescriptionRepository mainRepository].
 */
+ (COObjectGraphContext *)objectGraphContext;
/**
 * Returns a new autoreleased transient object graph context using the given 
 * model description repository.
 */
+ (COObjectGraphContext *)objectGraphContextWithModelRepository: (ETModelDescriptionRepository *)aRegistry;
/**
 * Initializes a persistent object graph context owned by a branch.
 */
- (id)initWithBranch: (COBranch *)aBranch;
/**
 * Initializes a transient object graph context using the given model 
 * description repository.
 */
- (id)initWithModelRepository: (ETModelDescriptionRepository *)aRepo;

/** 
 * @taskunit Type Querying 
 */

/**
 * Returns YES.
 *
 * See also -[NSObject isObjectGraphContext].
 */
@property (readonly, nonatomic) BOOL isObjectGraphContext;

/**
 * @taskunit Metamodel Access
 */

/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the objects managed by the context.
 */
@property (readonly, nonatomic) ETModelDescriptionRepository *modelRepository;

/**
 * @taskunit Related Persistency Management Objects
 */

/**
 * The branch owning the object graph context.
 *
 * For a transient object graph context, returns nil.
 */
@property (readonly, nonatomic) COBranch *branch;
/**
 * The persistent root owning the branch.
 *
 * For a transient object graph context, returns nil.
 */
@property (readonly, nonatomic)  COPersistentRoot *persistentRoot;
/**
 * The editing context owing the persistent root.
 *
 * For a transient object graph context, returns nil.
 */
@property (readonly, nonatomic) COEditingContext *editingContext;

/**
 * @taskunit Item Graph Protocol 
 */

/**
 * Returns the root object UUID.
 */
- (ETUUID *)rootItemUUID;

/**
 * Returns the immutable item that corresponds to the given inner object UUID.
 */
- (COItem *)itemForUUID: (ETUUID *)aUUID;
/**
 * Returns all the inner object UUIDs.
 */
- (NSArray *)itemUUIDs;
/**
 * Updates the inner object graph to match the given item set.
 *
 * The correspondance between a inner object and an item is decided using 
 * -[COObject UUID] and -[COItem UUID].
 *
 * When there is no inner object for an item UUID, a new inner object with 
 * the same UUID is inserted in the object graph, otherwise the existing inner 
 * object is updated.
 * 
 * This must leave the object graph in a consistent state.
 */
- (void)insertOrUpdateItems: (NSArray *)items;
/**
 * Does the same than -insertOrUpdateItems:, but in addition discard changes and 
 * deleted objects (by running a GC phase).
 */
- (void)setItemGraph: (id <COItemGraph>)aTree;
/**
 * IDEA:
 * Though COEditingContext implements COItemGraph, this method returns
 * an independent snapshot of the editing context, suitable for passing
 * to a background thread
 */
//- (id<COItemGraph>)itemGraphSnapshot;

/**
 * @taskunit Accessing the Root Object
 */

/**
 * The object serving as an entry point in the object graph.
 *
 * For a transient object graph context, can be nil.
 *
 * For a persistent object graph context, a valid root object must be set before 
 * committing it.
 *
 * See also -rootItemUUID.
 */
@property (nonatomic, retain) COObject *rootObject;

/**
 * @taskunit Change Tracking
 */

/**
 * Returns the objects inserted since change tracking was cleared.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSSet *insertedObjects;
/**
 * Returns the objects whose properties have been edited since change tracking 
 * was cleared.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSSet *updatedObjects;
/**
 * Returns whether the object is among the updated objects.
 *
 * See also -updatedObjects.
 */
- (BOOL)isUpdatedObject: (COObject *)anObject;
/**
 * Returns the union of the inserted and updated objects. See -insertedObjects
 * and -updatedObjects.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSSet *changedObjects;
/**
 * Returns whether the context contains uncommitted changes.
 *
 * Inner object insertions and updates all count as uncommitted changes.
 *
 * See also -discardAllChanges.
 */
- (BOOL)hasChanges;
/**
 * Reloads to the current revision.
 *
 * All existing changes are cleared and all loaded objects are discarded
 * (references to these objects become invalid as a result).
 *
 * See also -clearChangeTracking and -[COBranch reloadAtRevision:].
 */
- (void)discardAllChanges;
/**
 * Clears uncommitted object insertions and updates.
 *
 * After calling this method, -hasChanges returns NO.
 */
- (void)clearChangeTracking;
// NOTE: I'm not sure this method is going to be useful. Quentin.
- (void)clearChangeTrackingForObject: (COObject *)anObject;

/**
 * @taskunit Accessing Loaded Objects
 */

/**
 * All the inner objects loaded in memory.
 *
 * The root object is included among the returned objects.
 *
 * See also -objectWithUUID: and -rootObject.
 */
@property (nonatomic, readonly) NSSet *loadedObjects;
/**
 * Returns the inner object bound to the given UUID in the object graph.
 *
 * If the object is not loaded or doesn't exist in the store, returns nil.
 *
 * You shouldn't need to use this method, unless you extend CoreObject API.
 */
- (COObject *)objectWithUUID: (ETUUID *)aUUID;

/** 
 * @taskunit Debugging 
 */

/**
 * A table listing the properties updated per object since change tracking was
 * cleared.
 *
 * Useful to debug the object changes reported to the context since the last 
 * commit.
 */
@property (nonatomic, readonly) NSMapTable *updatedPropertiesByObject;

/**
 * @taskunit Deprecated
 */

/**
 * This method is deprecated, you must now use 
 * -[COObject initWithEntityDecription:objectGraphContext:].
 */
- (id)insertObjectWithEntityName: (NSString *)aFullName;
/**
 * This method is deprecated and private.
 */
- (id)insertObjectWithEntityName: (NSString *)aFullName
                            UUID: (ETUUID *)aUUID;

/**
 * @taskunit Framework Private
 */

/**
 * This method is only exposed to be used internally by CoreObject. 
 *
 * Sets the branch owning the object graph.
 */
- (void)setBranch: (COBranch *)aBranch;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the inner object bound to the given UUID in the object graph.
 *
 * If the object is not loaded yet and a serialized representation exists in 
 * the store for the UUID, returns a new instance.
 *
 * If there is no committed object for the given UUID in the store, returns nil.
 *
 * This method can resolve entity descriptions during an item graph 
 * deserialization without accessing the store.
 */
- (id)objectReferenceWithUUID: (ETUUID *)aUUID;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Puts the object among the loaded objects.
 */
- (void)registerObject: (COObject *)object isNew: (BOOL)inserted;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the object graph context a property value has changed in a COObject 
 * instance.
 */
- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty;

@end
