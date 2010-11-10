#import <EtoileFoundation/EtoileFoundation.h>
#import "COEditingContext.h"
#import "COHistoryNode.h"

@class COEditingContext;

/**
 * 'Working copy' of an object.
 * Owned by an Object Context.
 *
 * One UUID can only have one COObject in a given Object Context,
 * but multiple object contexts can exist in a process with their own
 * COObject for a particular UUID.
 *
 * COObjects can only exist in the context of a COObjectContext, becasue
 * they rely on the conxtext to resolve fault references to other COObjects.
 *
 * You should use ETUUID's to refer to objects outside of the context
 * of a COObjectContext.
 *
 * Rules for writing custom accessor methods:
 *  - call willAccessValueForProperty, etc.
 *
 */
@interface COObject : NSObject
{
@private
	BOOL _isFault;
	NSMutableDictionary *_data;
	COEditingContext *_ctx;
	ETUUID *_uuid;
	ETEntityDescription *_description;
}

// Public

- (ETEntityDescription *)modelDescription;
/**
 * Automatic fine-grained copy
 */
- (id)copyWithZone: (NSZone*)zone;

/**
 * Returns an array containing all COObjects "strongly contained" by this one.
 * This means objects which are values for "composite" properties.
 */
- (NSArray*)allStronglyContainedObjects;

/**
 * override: never
 * Creates a new object (generates a new UUID) in the given context.
 */
- (id) initWithContext: (COEditingContext*)ctx;

/**
 * override: never
 * Creates a new object (generates a new UUID) in the given context, with
 * the given entity description.
 */
- (id) initWithModelDescription: (ETEntityDescription*)desc context: (COEditingContext*)ctx;

- (BOOL) isEqual: (id)otherObject;

- (ETUUID*) uuid;
- (COEditingContext*) objectContext;

- (BOOL) isFault;

/**
 * Does nothing, overried in subclasses. Do not call.
 * Called by the framework when a COObject instance is changed by the
 * framework.
 */
- (void) didAwaken;
/**
 * Caled when the object is created. 
 */
- (void) awakeFromCreate;

/* Property-value coding */

- (NSArray *)properties;
- (id) valueForProperty:(NSString *)key;
- (void) setValue:(id)value forProperty:(NSString*)key;

/** @override-never */
- (void)willAccessValueForProperty:(NSString *)key;
- (void)willChangeValueForProperty:(NSString *)key;
- (void)didChangeValueForProperty:(NSString *)key;

- (NSString*)detailedDescription;

@end


@interface COObject (Private)

- (id) initFaultedObjectWithContext: (COEditingContext*)ctx uuid: (ETUUID*)uuid;
- (id) initWithContext: (COEditingContext*)ctx uuid: (ETUUID*)uuid data: (NSDictionary *)data;
- (NSData*)sha1Hash;
- (void) load;
- (void)loadIfNeeded;
- (void) markAsNeedingReload;
- (id)_mutableValueForProperty: (NSString*)key;
- (void) setModified;

@end


/**
 * History related manipulations to the working copy. (to one specific object)
 */
@interface COObject (Rollback)

/**
 * Reverts back to the last saved version
 */
- (void) revert;

/**
 * Commit changes made to jst this object?
 */
- (void) commit;

/**
 * Rolls back this object to the state it was in at the given revision, discarding all current changes
 */
- (void) rollbackToRevision: (COHistoryNode *)ver;

/**
 * Replaces the reciever with the result of doing a three-way merge with it an otherObj,
 * using baseObj as the base revision.
 *
 * Note that otherObj and baseObj will likely be COObject instances represeting the
 * same UUID as the reciever from other (temporary) object contexts
 * constructed just for doing the merge.
 *
 * Note that nothing is committed.
 */
- (void) threeWayMergeWithObject: (COObject*)otherObj base: (COObject *)baseObj;
- (void) twoWayMergeWithObject: (COObject *)otherObj;

- (void) selectiveUndoChangesMadeInRevision: (COHistoryNode *)ver;

@end

// FIXME: these are a bit of a mess
@interface COObject (PropertyListImportExport)

+ (NSArray*) arrayPropertyListForArray: (NSArray *)array;
- (NSDictionary*) propertyList;
- (NSDictionary*) referencePropertyList;

- (NSObject *)parsePropertyList: (NSObject*)plist;
/**
 * This takes a data dictionary from the store and replaces object references
 * with actual (faulted) COObject instances
 */
- (void)unfaultWithData: (NSDictionary*)data;

@end
