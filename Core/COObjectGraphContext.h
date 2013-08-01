#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COItemGraph.h>

@class ETUUID;
@class COPersistentRoot, COBranch, COObject, CORelationshipCache;
@class COItemGraph, COItem, COSchemaRegistry , COSchema, COEditingContext;

@interface COObjectGraphContext : NSObject <COItemGraph>
{
    ETUUID *rootObjectUUID_;
    NSMutableDictionary *objectsByUUID_;
	id <COItemGraph> _loadingItemGraph;
    
    NSMutableSet *insertedObjects_;
    NSMutableSet *modifiedObjects_;
    
    ETModelDescriptionRepository *modelRepository_;
    
    COBranch *branch_;
    
    NSMapTable *_updatedPropertiesByObject;
}

#pragma mark Creation

- (id) initWithBranch: (COBranch *)aBranch;
- (id) initWithModelRepository: (ETModelDescriptionRepository *)aRepo;

+ (COObjectGraphContext *) objectGraphContext;

+ (COObjectGraphContext *) objectGraphContextWithModelRepository: (ETModelDescriptionRepository *)aRegistry;

#pragma mark Schema

- (ETModelDescriptionRepository *) modelRepository;

- (COBranch *) branch;
- (COPersistentRoot *) persistentRoot;
- (COEditingContext *) editingContext;

#pragma mark begin COItemGraph protocol

- (ETUUID *) rootItemUUID;

/**
 * Returns immutable item
 */
- (COItem *) itemForUUID: (ETUUID *)aUUID;
- (NSArray *) itemUUIDs;

/**
 * Insert or update a set of items. This must leave the object graph
 * in a consistent state.
 */
- (void) insertOrUpdateItems: (NSArray *)items;

#pragma mark end COItemGraph protocol

/**
 * Replaces the editing context.
 *
 * There are 3 kinds of change:
 *  - New objects are inserted
 *  - Removed objects are removed
 *  - Changed objects are updated. (sub-case: identical objects)
 */
- (void) setItemGraph: (id <COItemGraph>)aTree;

/**
 * IDEA:
 * Though COEditingContext implements COItemGraph, this method returns
 * an independent snapshot of the editing context, suitable for passing
 * to a background thread
 */
//- (id<COItemGraph>) itemGraphSnapshot;

- (COObject *) rootObject;
- (void) setRootObject: (COObject *)anObject;

#pragma mark change tracking

/**
 * Returns the set of objects inserted since change tracking was cleared
 */
- (NSSet *) insertedObjects;
/**
 * Returns the set of objects modified since change tracking was cleared
 */
- (NSSet *) updatedObjects;
- (BOOL) isUpdatedObject: (COObject *)anObject;

- (NSSet *) changedObjects;

- (BOOL)hasChanges;

- (void) clearChangeTracking;
- (void) clearChangeTrackingForObject: (COObject *)anObject;

- (NSMapTable *) updatedPropertiesByObject;

#pragma mark adding objects

- (id)insertObjectWithEntityName: (NSString *)aFullName;

// FIXME: I don't think this should be public
- (id)insertObjectWithEntityName: (NSString *)aFullName
                            UUID: (ETUUID *)aUUID;

- (void)registerObject: (COObject *)object;



#pragma mark access

- (COObject *) objectWithUUID: (ETUUID *)aUUID;
- (NSArray *) allObjects;

#pragma mark COObject private

- (void)setBranch: (COBranch *)aBranch;
- (id) objectReferenceWithUUID: (ETUUID *)aUUID;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Declares the object as newly inserted and puts it among the loaded objects.
 *
 * The first registered object becomes the root object.
 */
- (void)registerObject: (COObject *)object;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the persistent root a property value has changed in a COObject class or
 * subclass instance.
 */
- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty;

@end