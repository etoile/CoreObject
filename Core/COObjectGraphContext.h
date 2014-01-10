/*
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
 * This notification is sent by the context during -clearChangeTracking.
 *
 * It will tell you about all possible mutations that can happen to a
 * COObjectGraphContext over its lifetime (inserting objects, updating objects,
 * reverting changes**, reloading a new state).
 *
 *   ** It's not totally clear if this should cause a notification to be sent
 *      or not, since the graph is reverted to the state it was in when the
 *      last COObjectGraphContextObjectsDidChangeNotification was set.
 *      See -[TestObjectGraphContext testNotificationAfterDiscardForPersistentContext]
 */
extern NSString * const COObjectGraphContextObjectsDidChangeNotification;
/**
 * User info dictionary key for COObjectGraphContextObjectsDidChangeNotification.
 * The value is an NSSet of ETUUID objects.
 */
extern NSString * const COInsertedObjectsKey;
/**
 * User info dictionary key for COObjectGraphContextObjectsDidChangeNotification.
 * The value is an NSSet of ETUUID objects.
 */
extern NSString * const COUpdatedObjectsKey;


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
 * COItemGraphEqualToItemGraph(ctx1, ctx2)
 */
@interface COObjectGraphContext : NSObject <COItemGraph, COPersistentObjectContext>
{
	@private
	ETModelDescriptionRepository *_modelDescriptionRepository;
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
 * See also -initWithModelRepository:.
 */
+ (COObjectGraphContext *)objectGraphContextWithModelRepository: (ETModelDescriptionRepository *)aRepo;
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
 * Returns a new transient object graph context using the main model description 
 * repository.
 *
 * See also -[ETModelDescriptionRepository mainRepository].
 */
- (id)init;


/** @taskunit Description */


/**
 * Returns a description detailing the item graph representation (the serialized 
 * representation).
 */
- (NSString *)detailedDescription;


/** @taskunit Type Querying */


/**
 * Returns YES.
 *
 * See also -[NSObject isObjectGraphContext].
 */
@property (nonatomic, readonly) BOOL isObjectGraphContext;


/** @taskunit Metamodel Access */


/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the objects managed by the context.
 */
@property (nonatomic, readonly) ETModelDescriptionRepository *modelDescriptionRepository;


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
 *
 * This marks the corresponding objects as inserted/object.
 * and does not call -clearChangeTracking.
 */
- (void)insertOrUpdateItems: (NSArray *)items;
/**
 * Does the same than -insertOrUpdateItems:, but in addition discard 
 * change tracking (calls -clearChangeTracking).
 */
- (void)setItemGraph: (id <COItemGraph>)aTree;


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
 * root UUID to refer to core objects and never <code>[[self rootObject] UUID]</code>.
 *
 * See also -rootItemUUID.
 */
@property (nonatomic, strong) id rootObject;


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
- (BOOL)hasChanges;
/**
 * If the receiver is owned by a branch, reloads to the current revision, clearing
 * all changes.
 *
 * Otherwise, all loaded objects are discarded (references to these objects become 
 * invalid as a result).
 *
 * See also -clearChangeTracking and -[COBranch reloadAtRevision:].
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
 * framwork users should normally never call this method.
 *
 * TODO: Could be clearer to rename to -markChangesCommitted or -acceptAllChanges
 * because the intent is not about "clearing" but about telling the object graph
 * context that the changes were committed.
 */
- (void)clearChangeTracking;


/** @taskunit Accessing Loaded Objects */


/**
 * All the inner objects loaded in memory.
 *
 * The root object is included among the returned objects.
 *
 * See also -objectWithUUID: and -rootObject.
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


/** @taskunit Debugging */


/**
 * A table listing the properties updated per object since change tracking was
 * cleared.
 *
 * Useful to debug the object changes reported to the context since the last 
 * commit.
 */
@property (nonatomic, readonly) NSDictionary *updatedPropertiesByUUID;

@end
