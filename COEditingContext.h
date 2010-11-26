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
	
	/**
	 * Note: never modify directly; call -markObjectDamaged/-markObjectUndamaged instead.
	 * Otherwise the cached value in COObject won't be updated.
	 */
	NSMutableSet *_damagedObjectUUIDs; // UUIDS of objects in this context which have uncommitted changes
	NSMutableDictionary *_instantiatedObjects; // UUID -> COObject mapping
	NSMutableDictionary *_commitUUIDForObject; // Object UUID -> Commit UUID mapping
	ETModelDescriptionRepository *_modelRepository;

	NSMutableDictionary *_tipNodeForObjectUUIDOnBranchWithUUID;
	NSMutableDictionary *_currentNodeForObjectUUIDOnBranchWithUUID;
	NSMutableDictionary *_currentBranchForObjectUUID;
	NSMutableSet *_insertedObjectUUIDs;
	NSMutableSet *_deletedObjectUUIDs;
}

// Creation

+ (COEditingContext*)contextWithURL: (NSURL*)aURL;

- (id)initWithStore: (COStore*)store;
- (COStore*)store;

//- (id)initWithStore: (COStore *)store historyTrack: (COHistoryTrack*)historyTrack;

- (id)init;

// Access

- (ETModelDescriptionRepository*) modelRepository;

- (BOOL) hasChanges;
- (BOOL) objectHasChanges: (ETUUID*)uuid;
- (NSSet*) changedObjectUUIDs;

- (Class) classForEntityDescription: (ETEntityDescription*)desc;
- (id) insertObjectWithEntityName: (NSString*)aFullName;

- (COObject*) objectWithUUID: (ETUUID*)uuid;


// Committing changes

- (void) commit;
- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription;

@end


@interface COEditingContext (PrivateToCOObject)

- (void) markObjectDamaged: (COObject*)obj;
- (void) markObjectUndamaged: (COObject*)obj;
- (void) loadObject: (COObject*)obj;
- (void) loadObject: (COObject*)obj atCommit: (COCommit*)aCommit;

- (COObject*) objectWithUUID: (ETUUID*)uuid entityName: (NSString*)name;

@end


@interface COEditingContext (PrivateToCOHistoryTrack)

// Queuing changes to the mutable part of the store (Private - use COHistoryTrack)

- (ETUUID*) namedBranchForObjectUUID: (ETUUID*)obj;
- (void) setNamedBranch: (ETUUID*)branch forObjectUUID: (ETUUID*)obj;

// same as the next pair but uses the context's current branch for that object
- (ETUUID*)currentCommitForObjectUUID: (ETUUID*)object;
- (void) setCurrentCommit: (ETUUID*)commit forObjectUUID: (ETUUID*)object;

- (ETUUID*)currentCommitForObjectUUID: (ETUUID*)object onBranch: (ETUUID*)branch;
- (void) setCurrentCommit: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;

- (ETUUID*)tipForObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;
- (void) setTip: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;

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

