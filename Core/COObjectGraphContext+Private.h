/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "COObjectGraphContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface COObjectGraphContext ()


/** @taskunit Branch and Persistent Root */


/**
 * Sets the branch owning the object graph.
 */
- (void)setBranch: (COBranch *)aBranch;
- (void)setPersistentRoot: (COPersistentRoot *)aPersistentRoot;
/**
 * The branch UUID.
 *
 * If the receiver is transient, returns the future branch UUID that will be 
 * used to create the branch in case the object graph context becomes persistent.
 *
 * Supporting a stable UUID for object graph contexts, means transient inner 
 * objects have a stable -[COObject hash] even if they become persistent.
 */
@property (nonatomic, readonly) ETUUID *branchUUID;


/** @taskunit Metamodel */


+ (NSString *)defaultEntityName;
+ (ETEntityDescription *)descriptionForItem: (COItem *)anItem
                 modelDescriptionRepository: (ETModelDescriptionRepository *)aRepository;
- (ETEntityDescription *)descriptionForItem: (COItem *)anItem;


/** Creating and Loading Objects */


/**
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
 * Returns the item graph getting loaded into the object graph context.
 *
 * If no loading involving multiple items is underway, returns nil.
 *
 * See -setItemGraph: and -insertAndUpdateItems:.
 */
@property (nonatomic, readonly, strong, nullable) id <COItemGraph> loadingItemGraph;
/**
 * Puts the object among the loaded objects.
 */
- (void)registerObject: (COObject *)object isNew: (BOOL)inserted;
/**
 * Returns the inner objects bound to the given UUIDs in the object graph.
 *
 * See -loadedObjectForUUID:.
 */
- (NSArray<__kindof COObject *> *)loadedObjectsForUUIDs: (NSArray<ETUUID *> *)UUIDs;


/** @taskunit Change Tracking and Snapshot */


/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the object graph context a property value has changed in a COObject
 * instance.
 */
- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty;

@property (nonatomic, readwrite, assign) BOOL ignoresChangeTrackingNotifications;
@property (nonatomic, readonly, strong) COItemGraph *modifiedItemsSnapshot;


/** @taskunit Cross Persistent Root References */


- (void)replaceObject: (nullable COObject *)anObject withObject: (nullable COObject *)aReplacement;

@property (nonatomic, readonly, getter=isTrackingSpecificBranch) BOOL trackingSpecificBranch;


/** @taskunit Garbage collection */


- (void)removeUnreachableObjects;
- (void)discardAllObjects;
/**
 * Should be called by COBranch at every commit.
 */
- (BOOL)incrementCommitCounterAndCheckIfGCNeeded;
/**
 * Perform tasks needed before each commit. (GC, check for cycles in composites)
 */
- (void)doPreCommitChecks;

@end

NS_ASSUME_NONNULL_END
