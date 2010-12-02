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
/**
 * Creates a new instance of the given entity name (assigning the instance a new UUID)
 * and returns the object. This is the factory method for COObject.
 */
- (id) insertObjectWithEntityName: (NSString*)aFullName;
/**
 * Copies an object from another context into this context.
 * The copy refers to the same underlying Core Object (same UUID)
 */
- (id) insertObject: (COObject*)sourceObject;
/**
 * Creates a copy of a Core Object (assigning it a new UUID), including copying
 * all strongly contained objects (composite properties)
 */
- (id) insertObjectCopy: (COObject*)sourceObject;

- (id) insertObject: (COObject*)sourceObject withRelationshipConsistency: (BOOL)consistency newUUID: (BOOL)newUUID; //Private

- (COObject*) objectWithUUID: (ETUUID*)uuid;


// Committing changes

- (void) commit;
- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription;

// Private

- (void) commitWithMetadata: (NSDictionary*)metadata;
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


@end

