#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COStore.h"

@class COObject;

/**
 * An object context is like a working copy in a revision control system.
 *
 * It queues changes and then attempts to commit them to the store.
 */
@interface COEditingContext : NSObject
{
	COStore *_store;
	CORevision *_revision;
	
	/**
	 * Note: never modify directly; call -markObjectDamaged/-markObjectUndamaged instead.
	 * Otherwise the cached value in COObject won't be updated.
	 */
	NSMutableDictionary *_damagedObjectUUIDs; // UUIDS of objects in this context which have uncommitted changes
	NSMutableDictionary *_instantiatedObjects; // UUID -> COObject mapping
	ETModelDescriptionRepository *_modelRepository;

	NSMutableSet *_insertedObjectUUIDs;
	NSMutableSet *_deletedObjectUUIDs;
}

// Creation

+ (COEditingContext*)contextWithURL: (NSURL*)aURL;

/**
 * Initializes a context which uses a specified revision of a store
 */
- (id)initWithRevision: (CORevision*)aRevision;
/**
 * Initializes a context which uses the current state of the store
 */
- (id)initWithStore: (COStore*)store;
- (COStore*)store;

- (id)init;

// FIXME: Should this copy uncommitted changes?
- (id)copyWithZone: (NSZone*)zone;

// Access

- (ETModelDescriptionRepository*) modelRepository;

- (BOOL) hasChanges;
- (BOOL) objectHasChanges: (ETUUID*)uuid;
- (NSSet*) changedObjectUUIDs;

- (Class) classForEntityDescription: (ETEntityDescription*)desc;
- (id) insertObjectWithEntityName: (NSString*)aFullName;
- (id) insertObject: (COObject*)sourceObject;

- (id) insertObject: (COObject*)sourceObject withRelationshipConsistency: (BOOL)consistency; //Private

- (COObject*) objectWithUUID: (ETUUID*)uuid;


// Committing changes

- (void) commit;
- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription;

// Private

- (uint64_t)currentRevisionNumber;

@end


@interface COEditingContext (PrivateToCOObject)

- (void) markObjectDamaged: (COObject*)obj forProperty: (NSString*)aProperty;
- (void) markObjectUndamaged: (COObject*)obj;
- (void) loadObject: (COObject*)obj;
- (void)loadObject: (COObject*)obj atRevision: (CORevision*)aRevision;

- (COObject*) objectWithUUID: (ETUUID*)uuid entityName: (NSString*)name;

@end



@interface COEditingContext (Rollback)

// Manipulation of the editing context itself - rather than the store

- (void) discardAllChanges;
- (void) discardAllChangesInObject: (COObject*)object;

/*
- (void) rollbackToRevision: (COHistoryNode *)ver;

- (void)selectiveUndoChangesMadeInRevision: (COHistoryNode *)ver;


- (void) commitObjects: (NSArray*)objects;
- (void) rollbackObjects: (NSArray*)objects toRevision: (COHistoryNode *)ver;
- (void) threeWayMergeObjects: (NSArray*)objects withObjects: (NSArray*)otherObjects bases: (NSArray*)bases;
- (void) twoWayMergeObjects: (NSArray*)objects withObjects: (NSArray*)otherObjects;
- (void) selectiveUndoChangesInObjects: (NSArray*)objects madeInRevision: (COHistoryNode *)ver;
*/

@end

