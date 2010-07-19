#import <EtoileFoundation/EtoileFoundation.h>
#import "COStore.h"
#import "COStoreCoordinator.h"
#import "COHistoryGraphNode.h"

@class COObject;
@class COHistoryGraphNode;
@class COObjectGraphDiff;
@class COFetchRequest;
@class COStoreCoordinator;

/**
 * An object context is like a working copy in a revision control system.
 * It is associated with a particlar version of the history graph,
 * knows how to create COObject instances for a given UUID (representing
 * that object in the state it was in 
 */
@interface COObjectContext : NSObject
{
  COHistoryGraphNode *_baseHistoryGraphNode; // history graph node this context was initialized with (based on)
  NSMutableSet *_changedObjectUUIDs;  // UUIDS of objects in this context which have uncommitted changes
  COStoreCoordinator *_storeCoordinator;
  NSMutableDictionary *_instantiatedObjects; // UUID -> COObject mapping
}

// Public

/**
 * Creates a new object context representing the object graph state
 * at the requested history node.
 */
- (id) initWithHistoryGraphNode: (COHistoryGraphNode*)node;

/**
 * Creates a new empty object context. The first commit will create a root
 * node in the store's history graph.
 */
- (id) initWithStoreCoordinator: (COStoreCoordinator*)store;

/**
 * Creates an empty, non-persistent context
 */
- (id) init;

- (void) commit;

- (COStoreCoordinator *) storeCoordinator;

/**
 * Returns the history graph node this context was created with
 */
- (COHistoryGraphNode *) baseHistoryGraphNode;

/**
 * @return whether or not this context has any uncomitted changes
 */
- (BOOL) hasChanges;

/**
 * Returns the object graph diff describing uncommitted changes in the 
 * objects in this context. Could be computed by diffing each object
 * in _changedObjectUUIDs against the base version in _baseHistoryGraphNode
 */
- (COObjectGraphDiff *) changes;
- (BOOL) objectHasChanges: (ETUUID*)uuid;

// Public - accessing objects

- (COObject*) objectForUUID: (ETUUID*)uuid;

@end


@interface COObjectContext (Private)

- (void) markObjectUUIDChanged: (ETUUID*)uuid;
- (void) markObjectUUIDUnchanged: (ETUUID*)uuid;
- (NSArray *) changedObjects;
- (void) recordObject: (COObject*)object forUUID: (ETUUID*)uuid;

@end


/**
 * History related manipulations to the working copy. (to all objects)
 */
@interface COObjectContext (Rollback)

/**
 * Reverts back to the last saved version
 */
- (void) revert;

/**
 * Rolls back this object context to the state it was in at the given revision, discarding all current changes
 */
- (void) rollbackToRevision: (COHistoryGraphNode *)ver;

- (void)selectiveUndoChangesMadeInRevision: (COHistoryGraphNode *)ver;

@end
