#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COEditingContext;

/**
 * Working copy of an object, owned by an editing context.
 * Relies on the context to resolve fault references to other COObjects.
 *
 * You should use ETUUID's to refer to objects outside of the context
 * of a COEditingContext.
 */
@interface COObject : NSObject <NSCopying>
{
	@package
	ETEntityDescription *_entityDescription;
	ETUUID *_uuid;
	COEditingContext *_context; // weak reference
	COObject *_rootObject; // weak reference
	NSMapTable *_variableStorage;
	BOOL _isIgnoringDamageNotifications;
	BOOL _isIgnoringRelationshipConsistency;
	BOOL _inDescription; // FIXME: remove; only for debugging
}

/** <init />
 * Initializes and returns a non-persistent object.
 *
 * The receiver can be made persistent later, by inserting it into an editing 
 * context with -becomePersistentInContext:rootObject:.<br />
 * Its identity will remain stable once persistency has been enabled, because 
 * this initializer gives a UUID to the object.
 *
 * You should use insertion methods provided by COEditingContext to create 
 * objects that are immediately persistent.
 */
- (id) init;

/** 
 * Makes the receiver persistent by inserting it into the given editing context.
 *
 * If the root object argument is the receiver itself, then the receiver becomes 
 * a root object (or a persistent root from the storage standpoint).
 *
 * Raises an exception if any argument is nil.<br />
 * When the root object is not the receiver or doesn't belong to the editing 
 * context, raises an exception too.
 */
- (void) becomePersistentInContext: (COEditingContext *)aContext 
                        rootObject: (COObject *)aRootObject;
- (id) copyWithZone: (NSZone *)aZone usesModelDescription: (BOOL)usesModelDescription;

/* Attributes */

/** 
 * Returns the UUID that uniquely identifies the persistent object that 
 * corresponds to the receiver.
 *
 * A persistent object has a single instance per editing context.
 */
- (ETUUID *) UUID;
- (ETEntityDescription *) entityDescription;
/** 
 * Returns the editing context when the receiver is persistent, otherwise  
 * returns nil.
 */
- (COEditingContext*) editingContext;
/** 
 * Returns the root object when the receiver is persistent, otherwise returns nil.
 *
 * When the receiver is persistent, returns either self or the root object that 
 * encloses the receiver as an embedded object.
 *
 * See also -isRoot.
 */
- (COObject *) rootObject;
- (BOOL) isFault;
/**
 * Returns whether the receiver is saved on the disk.
 *
 * When persistent, the receiver has both a valid editing context and root object.
 */
- (BOOL) isPersistent;
/** 
 * Returns whether the receiver is a root object that can enclose embedded 
 * objects.
 *
 * Embedded or non-persistent objects returns NO.
 *
 * See also -rootObject.
 */
- (BOOL) isRoot;
- (BOOL) isDamaged;


/* Helper methods based on the metamodel */

/**
 * Returns an array containing all COObjects "strongly contained" by this one.
 * This means objects which are values for "composite" properties.
 */
- (NSArray*)allStronglyContainedObjects;
- (NSArray*)allStronglyContainedObjectsIncludingSelf;

/* Property-value coding */

- (NSArray *) propertyNames;
- (NSArray *) persistentPropertyNames;
- (id) valueForProperty:(NSString *)key;
- (BOOL) setValue:(id)value forProperty:(NSString*)key;

/* Collection mutation methods */

- (void) addObject: (id)object forProperty:(NSString*)key;
- (void) insertObject: (id)object atIndex: (NSUInteger)index forProperty:(NSString*)key;
- (void) removeObject: (id)object forProperty:(NSString*)key;
- (void) removeObject: (id)object atIndex: (NSUInteger)index forProperty:(NSString*)key;

/* Notifications to be called by accessor methods */

/**
 * Tells the receiver that the value of the property (transient or persistent) 
 * is about to change.
 *
 * By default, limited to calling -willChangeValueForKey:.
 *
 * Can be overriden, but the superclass implementation must be called.
 */
- (void)willChangeValueForProperty: (NSString *)key;
/**
 * Tells the receiver that the value of the property (transient or persistent)
 * has changed. 
 *
 * By default, notifies the editing context about the receiver change and 
 * triggers Key-Value-Observing notifications by calling -didChangeValueForKey:.
 *
 * Can be overriden, but the superclass implementation must be called.
 */
- (void)didChangeValueForProperty: (NSString *)key;

/* Overridable Notifications */

- (void) awakeFromInsert;
- (void) awakeFromFetch;
- (void) willTurnIntoFault;
- (void) didTurnIntoFault;

/* NSObject methods */

- (NSString*) description;
- (BOOL) isEqual: (id)otherObject;

@end


@interface COObject (Private)

/** 
 * Returns COObjectFault. 
 */
+ (Class) faultClass;
- (NSError *) unfaultIfNeeded;
- (void) notifyContextOfDamageIfNeededForProperty: (NSString*)prop;
- (void) turnIntoFault;

- (BOOL) isIgnoringRelationshipConsistency;
- (void) setIgnoringRelationshipConsistency: (BOOL)ignore;

@end


@interface COObject (PropertyListImportExport)

- (id)serializedValueForProperty:(NSString *)key;
- (BOOL)setSerializedValue:(id)value forProperty:(NSString*)key;
- (NSDictionary*) propertyListForValue: (id)value;
- (NSDictionary*) referencePropertyList;
- (NSObject *)valueForPropertyList: (NSObject*)plist;

@end


@interface COObject (PrivateToEditingContext)

/**
 * If isFault is NO, the object is initialized as a newly inserted object.
 */
- (id) initWithUUID: (ETUUID*)aUUID 
  entityDescription: (ETEntityDescription*)anEntityDescription
         rootObject: (id)aRootObject
			context: (COEditingContext*)aContext
			isFault: (BOOL)isFault;
/**
 * Used only by -[COEditingContext markObject[Un]damaged]; to update
 * the object's cached damage flag
 */
// - (void) setDamaged: (BOOL)isDamaged;

@end

/*
// FIXME: these are a bit of a mess
@interface COObject (PropertyListImportExport)

- (NSDictionary*) propertyList;
- (NSDictionary*) referencePropertyList;

- (void)unfaultWithData: (NSDictionary*)data;

@end
*/

@interface COObject (Debug)
- (id) roundTripValueForProperty: (NSString *)key;
- (NSString*)detailedDescription;
@end
