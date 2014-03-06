/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import "COObjectGraphContext.h"

@interface COObjectGraphContext ()

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Sets the branch owning the object graph.
 */
- (void)setBranch: (COBranch *)aBranch;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)setPersistentRoot: (COPersistentRoot *)aPersistentRoot;
/**
 * This property is only exposed to be used internally by CoreObject.
 *
 * The branch UUID.
 *
 * If the receiver is transient, returns the future branch UUID that will be 
 * used to create the branch in case the object graph context becomes persistent.
 *
 * Supporting a stable UUID for object graph contexts, means transient inner 
 * objects have a stable -[COObject hash] even if they become persistent.
 */
@property (nonatomic, readonly) ETUUID *branchUUID;
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
 * Returns the item graph getting loaded into the object graph context.
 *
 * If no loading involving multiple items is underway, returns nil.
 *
 * See -setItemGraph: and -insertAndUpdateItems:.
 */
- (id <COItemGraph>)loadingItemGraph;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Puts the object among the loaded objects.
 */
- (void)registerObject: (COObject *)object isNew: (BOOL)inserted;
/**
 * Returns the inner objects bound to the given UUIDs in the object graph.
 *
 * See -loadedObjectForUUID:.
 */
- (NSArray *)loadedObjectsForUUIDs: (NSArray *)UUIDs;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the object graph context a property value has changed in a COObject
 * instance.
 */
- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void) removeUnreachableObjects;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (BOOL) isTrackingSpecificBranch;


/** @taskunit Metamodel Access */

/**
 * This method is only exposed to be used internally by CoreObject.
 */
+ (NSString *)entityNameForItem: (COItem *)anItem;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
+ (NSString *)defaultEntityName;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
+ (ETEntityDescription *)descriptionForItem: (COItem *)anItem
				 modelDescriptionRepository: (ETModelDescriptionRepository *)aRepository;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (ETEntityDescription *)descriptionForItem: (COItem *)anItem;

/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COItemGraph *)modifiedItemsSnapshot;


/** @taskunit Garbage collection */

/**
 * Should be called by COBranch at every commit.
 */
- (BOOL) incrementCommitCounterAndCheckIfGCNeeded;

@end
