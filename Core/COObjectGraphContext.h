/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COItemGraph.h>
#import <CoreObject/COEditingContext.h>

@class COPersistentRoot, COBranch, COObject, CORelationshipCache;
@class COItemGraph, COItem;

/**
 * Posted during -[COObjectGraphContext acceptAllChanges].
 *
 * This notifcation will tell you about all possible mutations that can happen 
 * to a COObjectGraphContext over its lifetime (inserting objects, updating 
 * objects, reverting changes**, reloading a new state).
 *
 * The userInfo dictionary contains the following keys:
 *
 * <deflist>
 * <term>COInsertedObjectsKey</term><desc>the inserted object UUIDs</desc>
 * <term>COUpdatedObjectsKey</term><desc>the updated object UUIDs</desc>
 * </deflist>
 *
 *   ** It's not totally clear if this should cause a notification to be sent
 *      or not, since the graph is reverted to the state it was in when the
 *      last COObjectGraphContextObjectsDidChangeNotification was set.
 *      See -[TestObjectGraphContext testNotificationAfterDiscardForPersistentContext]
 *
 * TODO: Rename to DidAcceptChangesNotification
 *
 * See also COObjectGraphContextWillRelinquishObjectsNotification.
 */
extern NSString * const COObjectGraphContextObjectsDidChangeNotification;
/**
 * User info dictionary key for COObjectGraphContextObjectsDidChangeNotification.
 *
 * The value is an NSSet of ETUUID objects.
 */
extern NSString * const COInsertedObjectsKey;
/**
 * User info dictionary key for COObjectGraphContextObjectsDidChangeNotification.
 *
 * The value is an NSSet of ETUUID objects.
 */
extern NSString * const COUpdatedObjectsKey;

/**
 * Posted when a garbage collection phase is run by COObjectGraphContext.
 *
 * This notification will tell you about the objects to be relinquished 
 * by the object graph context, under the key CORelinquishedObjectsKey.
 *
 * You must use it to discard all non-persistent references hold on these 
 * objects, just before these references become invalid. For example, 
 * UI controllers must usually observe this notification.
 *
 * Object graph context changes reported by 
 * COObjectGraphContextDidChangeNotification can result in objects to be 
 * relinquished, on the next garbage collection phase.
 */
extern NSString * const COObjectGraphContextWillRelinquishObjectsNotification;
/**
 * User info dictionary key for COObjectGraphContextWillRelinquishObjectsNotification.
 *
 * The value is a NSArray of COObjects.
 *
 * The relinquished objects are objects to be released by the object graph 
 * context, during a garbage collection phase, because they are not referenced 
 * in a persistent relationship for the current state.
 */
extern NSString * const CORelinquishedObjectsKey;

extern NSString * const COObjectGraphContextBeginBatchChangeNotification;
extern NSString * const COObjectGraphContextEndBatchChangeNotification;

/**
 * @group Core
 * @abstract 
 * An object graph that manages COObject instances (COObject instances can only 
 * exist inside a COObjectGraphContext). 
 *
 * @section Conceptual Model
 *
 * An object graph context is usually persistent (-branch is not nil), it 
 * manages the objects that represent the current branch state in memory, 
 * and tracks their changes between commits.
 *
 * It tracks which objects in the object graph have been modified, which is 
 * what allows CoreObject to commit deltas instead of writing a fullsnapshot 
 * of every object in the object graph on every commit.
 *
 * All the objects that belong to an object graph are called inner objects 
 * (including the root object), while objects in other object graphs are outer 
 * objects. A reference to an outer object is a cross-persistent root reference.
 * For a more in-depth discussion, see Cross Persistent References section in 
 * COPersistentRoot.
 *
 * @section Common Use Cases
 *
 * The most common use case would be to check whether the object graph contains 
 * changes with -hasChanges, and more rarely to revert to the last committed 
 * state with -discardAllChanges e.g. when the user cancels some input in a 
 * dialog.
 *
 * You rarely need to interact directly with COObjectGraphContext API, but 
 * object graph contexts are passed to COObject initializers to tell the new 
 * object to which context it belongs, see -[COObject initWithObjectGraphContext:].
 *
 * @section Item Graph Representation
 *
 * COObjectGraphContext implements the COItemGraph protocol which allows 
 * viewing the COObjectGraphContext in a semi-serialized form (as a set of 
 * COItem objects), as well as the -setItemGraph: method which allows 
 * deserializing a given graph of COItems (reusing existing COObject instances 
 * if possible).
 *
 * @section Transient Object Graph 
 *
 * To manage transient COObject instances, transient object graphs not bound to 
 * a branch or persistent root can be  created. You can use them to hold an 
 * object graph state easily recreated in code (at  launch time or on demand) 
 * without depending on an entire CoreObject stack (an editing context, a 
 * store etc.).
 *
 * With COItemGraph protocol, COObject instances can be moved or copied 
 * accross persistent and transient object graphs. 
 *
 * In CoreObject, outer references (accross persistent object graphs) must 
 * point to a root object. Between a persistent and a transient object graph, 
 * this limit doesn't hold, you can refer to multiple objects and not just the 
 * root object (the root object is optional in a transient object graph). 
 *
 * If a transient COObject refers to a persistent one, there is no need to 
 * observe COObjectGraphContextWillRelinquishObjectsNotification, since the 
 * relationship cache will automatically update the references.
 *
 * A transient object graph can be turned into a persistent one with 
 * -[COEditingContext insertNewPersistentRootWithRootObject:], where the 
 * argument is an arbitrary object from the transient object graph.
 *
 * @section Creation and Deletion
 *
 * Persistent object graph contexts are usually created indirectly, each time a 
 * persistent root or branch is created, and their object graph is accessed. 
 * For example, with -[COPersistentRoot objectGraphContext] and 
 * -[COBranch objectGraphContext].
 *
 * To create transient object graphs, use -init, 
 * -initWithModelDescriptionRepository:, or +objectGraphContext.
 *
 * A persistent object graph is deleted in the store, when the branch that owns 
 * it is deleted (see -[COBranch setDeleted:]). For transient object graphs, 
 * all their content is lost when they are deallocated.
 *
 * @section Object Equality
 *
 * COObjectGraphContext does not override -hash or -isEqual:, so an
 * object graph context is only considered equal to itself.
 *
 * To compare the contents of two COObjectGraphContext instances you can do:
 * COItemGraphEqualToItemGraph(ctx1, ctx2).
 *
 * See also Object Equality section in COEditingContext.
 */
@interface COObjectGraphContext : NSObject <COItemGraph, COPersistentObjectContext>
{
	@private
	ETModelDescriptionRepository *_modelDescriptionRepository;
	Class _migrationDriverClass;
	COBranch *__weak _branch;
	COPersistentRoot *__weak _persistentRoot;
	ETUUID *_futureBranchUUID;
    ETUUID *_rootObjectUUID;
	/** Loaded (or inserted) objects by UUID */
    NSMutableDictionary *_loadedObjects;
	/** Item graph exposed during loading (nil once the loading is done) */
	id <COItemGraph> _loadingItemGraph;
	NSMutableDictionary *_objectsByAdditionalItemUUIDs;
    NSMutableSet *_insertedObjectUUIDs;
    NSMutableSet *_updatedObjectUUIDs;
    NSMutableDictionary *_updatedPropertiesByUUID;
	/** How many commits have been done since last garbage collection */
	uint64_t _numberOfCommitsSinceLastGC;
	int _ignoresChangeTrackingNotifications;
}


/** @taskunit Creation */


/**
 * Returns a new autoreleased transient object graph context using the main 
 * model description repository.
 *
 * See also -[ETModelDescriptionRepository mainRepository] and -init.
 */
+ (COObjectGraphContext *)objectGraphContext;
/**
 * Returns a new autoreleased transient object graph context using the given 
 * model description repository.
 *
 * See also -initWithModelDescriptionRepository:.
 */
+ (COObjectGraphContext *)objectGraphContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)aRepo;
/**
 * Initializes a persistent object graph context owned by a branch.
 */
- (instancetype)initWithBranch: (COBranch *)aBranch;
/**
 * Initializes a transient object graph context using the given model
 * description repository and migration driver.
 *
 * To register your metamodel in the model description repository, see
 * -[COEditingContext initWithStore:modelDescriptionRepository:]. This 
 * initializer attempts to register COObject subclasses in the same way.
 *
 * If you intend to pass the object graph to 
 * -[COEditingContext insertNewPersistentRootWithRootObject:], the repository 
 * must be the same than the one used by the editing context.
 *
 * For a nil model description repository, raises a NSInvalidArgumentException.
 *
 * For a migration driver class that is neither nil nor a subclass of 
 * COSchemaMigrationDriver, raises a NSInvalidArgumentException.
 */
- (instancetype)initWithModelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
                    migrationDriverClass: (Class)aDriverClass;
/**
 * Returns a new transient object graph context using the main model description 
 * repository.
 *
 * See also -[ETModelDescriptionRepository mainRepository].
 */
- (instancetype)init;


/** @taskunit Description */


/**
 * Returns a short description to summarize the receiver.
 */
@property (readonly, copy) NSString *description;
/**
 * Returns a description detailing the item graph representation (the serialized 
 * representation).
 */
@property (nonatomic, readonly) NSString *detailedDescription;


/** @taskunit Type Querying */


/**
 * Returns YES.
 *
 * See also -[NSObject isObjectGraphContext].
 */
@property (nonatomic, readonly) BOOL isObjectGraphContext;


/** @taskunit Metamodel Access and Migration Support */


/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the objects managed by the context.
 */
@property (nonatomic, readonly) ETModelDescriptionRepository *modelDescriptionRepository;
/**
 * The migration driver used to migrate items to the latest package versions.
 *
 * For more details, see -[COEditingContext migrationDriverClass].
 */
@property (nonatomic, readonly) Class migrationDriverClass;


/** @taskunit Related Persistency Management Objects */


/**
 * The branch owning the object graph context.
 *
 * For a transient object graph context, returns nil.
 */
@property (nonatomic, readonly, weak) COBranch *branch;
/**
 * The persistent root owning the branch.
 *
 * For a transient object graph context, returns nil.
 */
@property (nonatomic, readonly, weak)  COPersistentRoot *persistentRoot;
/**
 * The editing context owing the persistent root.
 *
 * For a transient object graph context, returns nil.
 */
@property (nonatomic, readonly) COEditingContext *editingContext;


/** @taskunit Item Graph Protocol */


/**
 * Returns the root object UUID.
 */
@property (nonatomic, readonly, strong) ETUUID *rootItemUUID;
/**
 * Returns the immutable item that corresponds to the given inner object UUID.
 */
- (COItem *)itemForUUID: (ETUUID *)aUUID;
/**
 * Returns all the inner object UUIDs.
 */
@property (nonatomic, readonly) NSArray *itemUUIDs;
/**
 * Returns the immutable items that corresponds to the inner objects.
 *
 * The returned item count is the same than -itemUUIDs.
 */
@property (nonatomic, readonly) NSArray *items;
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
 *
 * This marks the corresponding objects as inserted/object.
 * and does not call -acceptAllChanges.
 *
 * For a nil argument, raises a NSInvalidArgumentException.
 */
- (void)insertOrUpdateItems: (NSArray *)items;
/**
 * Does the same than -insertOrUpdateItems:, but in addition discards  
 * change tracking (calls -acceptAllChanges).
 *
 * Only loads objects from aTree reachable from a depth-first search starting 
 * at the root object.
 *
 * As a special case, if both the receiver and aTree have a nil root object, 
 * loads all objects from aTree. If <code>aTree.rootItemUUID</code> is not nil, 
 * it must match -rootItemUUID, otherwise a NSInvalidArgumentException is raised.
 *
 * For a nil argument, raises a NSInvalidArgumentException.
 *
 * FIXME: Document more corner cases (what causes exceptions to be thrown)
 */
- (void)setItemGraph: (id <COItemGraph>)aTree;


/** @taskunit Loading Status */


@property (nonatomic, readonly, getter=isLoading) BOOL loading;


/** @taskunit Accessing the Root Object */


/**
 * The object serving as an entry point in the object graph.
 *
 * The returned object is COObject class or subclass instance.
 *
 * For a transient object graph context, can be nil.
 *
 * For a persistent object graph context, a valid root object must be set before 
 * committing it.
 *
 * This object UUID must remain the same in the entire persistent root history 
 * including the branches (and derived cheap copies). This is enforced in the store
 * as well as in this property - it is a "set-once" property. An exception will
 * be raised if the caller attempts to set it to something else.
 *
 * The root object doesn't represent the core object. As such, use the persistent
 * root UUID to refer to core objects and never <code>[self.rootObject UUID]</code>.
 *
 * See also -rootItemUUID.
 */
@property (nonatomic, readwrite, strong) id rootObject;


/** @taskunit Change Tracking */


/**
 * Returns the object UUIDs inserted since change tracking was cleared.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSSet *insertedObjectUUIDs;
/**
 * Returns the object UUIDs whose properties have been edited since change tracking
 * was cleared.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSSet *updatedObjectUUIDs;
/**
 * Returns whether the object is among the updated objects.
 *
 * See also -updatedObjects.
 */
- (BOOL)isUpdatedObject: (COObject *)anObject;
/**
 * Returns the union of the inserted and updated objects. See -insertedObjectUUIDs
 * and -updatedObjectUUIDs.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSSet *changedObjectUUIDs;
/**
 * Returns whether the context contains uncommitted changes.
 *
 * Inner object insertions and updates all count as uncommitted changes.
 *
 * See also -discardAllChanges.
 */
@property (nonatomic, readonly) BOOL hasChanges;
/**
 * If the receiver is owned by a branch, reloads to the current revision, clearing
 * all changes.
 *
 * Otherwise, all loaded objects are discarded (references to these objects become 
 * invalid as a result).
 *
 * See also -acceptAllChanges and -[COBranch reloadAtRevision:].
 */
- (void)discardAllChanges;
/**
 * Conceptually, ends the current transaction and begins a new one.
 *
 * To be exact, this clears the record of inserted and updated objects so the
 * current state of the object graph is regarded as pristine. 
 * It's the caller's responsibility to have actually saved the changes somewhere
 * before calling this (this is taken care of by COBranch.)
 *
 * This method sends the COObjectGraphContextObjectsDidChangeNotification.
 *
 * After calling this method, -hasChanges returns NO.
 *
 * This method is semi-private; it is part of the API used by COBranch and
 * framework users should normally never call this method.
 */
- (void)acceptAllChanges;


/** @taskunit Accessing Loaded Objects */


/**
 * All the inner objects loaded in memory.
 *
 * The root object is included among the returned objects.
 *
 * See also -loadedObjectForUUID: and -rootObject.
 */
@property (nonatomic, readonly) NSArray *loadedObjects;
/**
 * Returns the inner object bound to the given UUID in the object graph.
 *
 * If the object is not loaded or doesn't exist in the store, returns nil.
 *
 * You shouldn't need to use this method, unless you extend CoreObject API.
 */
- (id)loadedObjectForUUID: (ETUUID *)aUUID;

@end
