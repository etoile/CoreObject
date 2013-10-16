/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

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
	COBranch *__weak _branch;
    ETUUID *_rootObjectUUID;
	/** Loaded (or inserted) objects by UUID */
    NSMutableDictionary *_loadedObjects;
	/** Item graph exposed during loading (nil once the loading is done) */
	id <COItemGraph> _loadingItemGraph;
    NSMutableSet *_insertedObjects;
    NSMutableSet *_updatedObjects;
    NSMapTable *_updatedPropertiesByObject;
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
 * Returns a new transient object graph context using the main model description 
 * repository.
 *
 * See also -[ETModelDescriptionRepository mainRepository].
 */
- (id)init;


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
@property (nonatomic, readonly) ETModelDescriptionRepository *modelRepository;


/** @taskunit Related Persistency Management Objects */


/**
 * The branch owning the object graph context.
 *
 * For a transient object graph context, returns nil.
 */
@property (nonatomic, readonly) COBranch *branch;
/**
 * The persistent root owning the branch.
 *
 * For a transient object graph context, returns nil.
 */
@property (nonatomic, readonly)  COPersistentRoot *persistentRoot;
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
 */
- (void)insertOrUpdateItems: (NSArray *)items;
/**
 * Does the same than -insertOrUpdateItems:, but in addition discard changes and 
 * deleted objects (by running a GC phase).
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


/** @taskunit Accessing Loaded Objects */


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


/** @taskunit Debugging */


/**
 * A table listing the properties updated per object since change tracking was
 * cleared.
 *
 * Useful to debug the object changes reported to the context since the last 
 * commit.
 */
@property (nonatomic, readonly) NSMapTable *updatedPropertiesByObject;

@end
