/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COQuery.h>

@class COEditingContext, CORevision, COCommitTrack;

/**
 * Working copy of an object, owned by an editing context.
 * Relies on the context to resolve fault references to other COObjects.
 *
 * You should use ETUUID's to refer to objects outside of the context
 * of a COEditingContext.
 */
@interface COObject : NSObject <NSCopying, COObjectMatching>
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
	BOOL _isInitialized;
}

/** @taskunit Initialization */

/** <init />
 * Initializes and returns a non-persistent object.
 *
 * The receiver can be made persistent later, by inserting it into an editing 
 * context with -becomePersistentInContext:rootObject:.<br />
 * Its identity will remain stable once persistency has been enabled, because 
 * this initializer gives a UUID to the object.
 *
 * You should use insertion methods provided by COEditingContext to create 
 * objects that are immediately persistent. Take note that these insertion 
 * methods use -init to initialize the object.
 *
 * For the initializer in subclasses, you must never create entity objects that 
 * correspond to relationships with insertion methods provided by 
 * COEditingContext (this ensures your subclasses support both immediate and 
 * late persistency with -becomePersistentInContext:rootObject:). For example, 
 * you must write:
 *
 * <example>
 * - (id)init
 * {
 *     SUPERINIT;
 *     // Don't instantiate the group with -[COEditingContext insertObjectWithEntityName:]
 *     personGroup = [[COGroup alloc] init];
 *     return self;
 * }
 * </example>
 */
- (id)init;

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
- (void)becomePersistentInContext: (COEditingContext *)aContext 
                       rootObject: (COObject *)aRootObject;
- (id)copyWithZone: (NSZone *)aZone usesModelDescription: (BOOL)usesModelDescription;

/** taskunit Persistency Attributes */

/** 
 * Returns the UUID that uniquely identifies the persistent object that 
 * corresponds to the receiver.
 *
 * A persistent object has a single instance per editing context.
 */
- (ETUUID *)UUID;
- (ETEntityDescription *)entityDescription;
/** 
 * Returns the editing context when the receiver is persistent, otherwise  
 * returns nil.
 */
- (COEditingContext *)editingContext;
/** 
 * Returns the root object when the receiver is persistent, otherwise returns nil.
 *
 * When the receiver is persistent, returns either self or the root object that 
 * encloses the receiver as an embedded object.
 *
 * See also -isRoot.
 */
- (COObject *)rootObject;
/**
 * Returns NO when the object is loaded, otherwise returns YES.
 * 
 * When YES is returned, the receiver class is set to +faultClass.
 *
 * You can send a message that COFault doesn't implement to unfault the object 
 * (in other words, load the instance variable values).
 */
- (BOOL)isFault;
/**
 * Returns whether the receiver is saved on the disk.
 *
 * When persistent, the receiver has both a valid editing context and root object.
 */
- (BOOL)isPersistent;
/** 
 * Returns whether the receiver is a root object that can enclose embedded 
 * objects.
 *
 * Embedded or non-persistent objects returns NO.
 *
 * See also -rootObject.
 */
- (BOOL)isRoot;
- (BOOL)isDamaged;

/** @taskunit History Attributes */

/**
 * Return the revision of this object in the editing context.
 */
- (CORevision *)revision;
/**
 * Returns the commit track for this object.
 */
- (COCommitTrack *)commitTrack;

/** @taskunit Contained Objects based on the Metamodel */

/**
 * Returns an array containing all COObjects "strongly contained" by this one.
 * This means objects which are values for "composite" properties.
 */
- (NSArray *)allStronglyContainedObjects;
- (NSArray *)allStronglyContainedObjectsIncludingSelf;
- (NSSet *)allInnerObjectsIncludingSelf;

/** @taskunit Basic Properties */

/**
 * The object name.
 */
@property (nonatomic, retain) NSString *name;

/**
 * <override-dummy />
 * Returns the object identifier.
 *
 * By default, returns -name which can be nil and might not be unique even 
 * within a COCollection content.
 *
 * Can be overriden to return a custom string.
 */
- (NSString *)identifier;
/**
 * Returns the last time the receiver changes were committed.
 *
 * The returned date is the last root object revision date. See -[CORevision date].
 *
 * Can be more recent than the present receiver revision (see -revision).
 */
- (NSDate *)modificationDate;
/**
 * Returns the first time the receiver changes were committed.
 *
 * The returned date is the first root object revision date. See -[CORevision date].
 */
- (NSDate *)creationDate;
/**
 * Returns -name.
 */
- (NSString *)displayName;
/**
 * Returns the groups to which the receiver belongs to.
 *
 * Groups are COGroup or subclass instances.
 *
 * See also -tags.
 */
- (NSArray *)parentGroups;
/**
 * Returns the tags attached to the receiver. 
 *
 * This method returns a -parentGroups subset. Groups which don't belong to 
 * -[COEditingContext tagGroup] are filtered out.
 */
- (NSArray *)tags;

/** @taskunit Property-Value Coding */

/** 
 * Returns the properties declared in the receiver entity description.
 *
 * See also -entityDescription and -persistentPropertyNames.
 */
- (NSArray *)propertyNames;
/** 
 * Returns the persistent properties declared in the receiver entity description.
 *
 * The returned array contains the property descriptions which replies YES to 
 * -[ETPropertyDescription isPersistent].
 *
 * See also -entityDescription and -propertyNames.
 */
- (NSArray *)persistentPropertyNames;
/**
 * Returns the property value.
 *
 * When the property is not declared in the entity description, raises an 
 * NSInvalidArgumentException.
 *
 * See also -setValue:forProperty:.
 */
- (id)valueForProperty: (NSString *)key;
/**
 * Sets the property value.
 *
 * When the property is not declared in the entity description, raises an 
 * NSInvalidArgumentException.
 *
 * See also -valueForProperty:.
 */
- (BOOL)setValue: (id)value forProperty: (NSString *)key;

/** @taskunit Direct Access to the Variable Storage */

/**
 * Returns a value from the variable storage.
 *
 * Can be used to read a property with no instance variable.
 *
 * This is a low-level method whose use should be restricted to serialization 
 * code and accessors that expose properties with no related instance variable.
 */
- (id)primitiveValueForKey: (NSString *)key;
/**
 * Sets a value in the variable storage.
 *
 * Can be used to write a property with no instance variable.
 *
 * This is a low-level method whose use should be restricted to serialization 
 * code and accessors that expose properties with no related instance variable.
 *
 * This method involves no integrity check or relationship consistency update.
 * It won't invoke -willChangeValueForProperty: and -didChangeValueForProperty: 
 * (or -willChangeValueForKey: and -didChangeValueForKey:).
 */
- (void)setPrimitiveValue: (id)value forKey: (NSString *)key;

/** @taskunit Notifications to be called by Accessors */

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

/** @taskunit Collection Mutation with Integrity Check */

/** 
 * Checks the insertion and the object that goes along respect the metamodel 
 * constraints, then calls -insertObject:atIndex:hint: on the collection bound 
 * to the property.<br />
 * Finally if the property is a relationship, this method updates the 
 * relationship consistency.
 *
 * See also ETCollectionMutation and -updateRelationshipConsistencyWithValue:.
 */
- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key;
/** 
 * Checks the insertion and the object that goes along respect the metamodel 
 * constraints, then calls -removeObject:atIndex:hint: on the collection bound 
 * to the property.<br />
 * Finally if the property is a relationship, this method updates the 
 * relationship consistency.
 *
 * See also ETCollectionMutation and -updateRelationshipConsistencyWithValue:. 
 */
- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key;

/** @taskunit Overridable Notifications */

/**
  * A notification that the object was created for the first time.
  * Override this method to perform any initialisation that should be
  * performed the very first time an object is instantiated, such
  * as calculating and setting default values.
  */
- (void)didCreate;
- (void)awakeFromInsert;
- (void)awakeFromFetch;
- (void)willTurnIntoFault;
- (void)didTurnIntoFault;
- (void)didReload;

/** @taskunit Object Equality */

/** Returns a hash based on the UUID. */
- (NSUInteger)hash;
/**
 * Returns whether anObject is equal to the receiver.
 *
 * Two persistent objects are equal if they share the same UUID.<br />
 * For now, returns YES even when the two object revisions don't match (this 
 * is subject to change).
 *
 * Use <code>[a isEqual: b] && ![a isTemporalInstance: b]</code> to check 
 * temporal equality. For example, when the same object is in use in multiple 
 * editing contexts simultaneously.
 *
 * See also -isTemporalInstance:.
 */
- (BOOL)isEqual: (id)anObject;
/** 
 * Returns whether anObject is a temporal instance of the receiver. 
 *
 * Two persistent objects are temporal instances of each other if they share the 
 * same UUID but differ by their revision. 
 *
 * See also -isEqual:.
 */
- (BOOL) isTemporalInstance: (id)anObject;

/** @taskunit Object Matching */

/**
 * Returns the receiver put in an array when it matches the query, otherwise 
 * returns an empty array.
 */
- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery;

/** @taskunit Debugging and Description */

/** 
 * Serializes the property value into the CoreObject serialized representation, 
 * then unserialize it back into a value that can be passed 
 * -setSerializedValue:forProperty:.
 *
 * The property value is retrieved with -serializedValueForProperty:.
 */
- (id)roundTripValueForProperty: (NSString *)key;
/** 
 * Returns a description that includes the receiver properties and their values. 
 */
- (NSString *)detailedDescription;
/** 
 * Returns a short description to summarize the receiver. 
 */
- (NSString *)description;
/**
 * Returns a short and human-readable description of the receiver type.
 *
 * This is used to present the type to the user in the UI.<br />
 * As such, the returned string must be localized.
 *
 * By default, returns the entity localized description, 
 * -[ETEntityDescription setLocalizedDescription:] can be used to customize 
 * the description. See -entityDescription to access the entity.
 * 
 * You can override the method to return a custom description too. For example, 
 * a COPhoto subclass could return the UTI description bound to the image it 
 * encapsulates: <code>[[[self image] UTI] typeDescription]</code>.
 *
 * This method doesn't return the receiver UTI description e.g. 
 * <em>Core Object</em>, it is more accurate but not simple enough to be 
 * presented to the user. 
 */
- (NSString *)typeDescription;
/** 
 * Returns the receiver tags in a coma separated list.
 *
 * This is used to present -tags to the user in the UI.
 */
- (NSString *)tagDescription;

/** @taskunit Private */

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * If isFault is NO, the object is initialized as a newly inserted object.
 */
- (id)initWithUUID: (ETUUID *)aUUID 
 entityDescription: (ETEntityDescription *)anEntityDescription
        rootObject: (id)aRootObject
           context: (COEditingContext *)aContext
           isFault: (BOOL)isFault;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns COObjectFault. 
 */
+ (Class)faultClass;
/**
 * This method is only exposed to be used internally by CoreObject.
 * See -[COFault unfaultIfNeeded].
 */
- (NSError *)unfaultIfNeeded;
/**
 * <override-never />
 * This method is only exposed to be used internally by CoreObject.
 *
 * Turns the receiver back into a fault, if previously loaded.
 *
 * Will release the variable storage values but not the instance variable values.
 *
 * This method invokes -willTurnIntoFault and -didTurnIntoFault which can be 
 * overriden in subclasses. For example, to release some instance variables.
 *
 * On return, the receiver class has been set to +faultClass.
 */
- (void)turnIntoFault;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns whether the receiver should skip the actions to ensure the 
 * relationship consistency based on the metamodel.
 *
 * Usually in reaction to changes, various checks and updates occur to ensure 
 * the metamodel constraints remain valid.
 *
 * See also -setIgnoringRelationshipConsistency:.
 */
- (BOOL)isIgnoringRelationshipConsistency;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Sets whether the receiver should skip the actions to ensure relationship 
 * consistency based on the metamodel.
 *
 * Usually in reaction to changes, various checks and updates occur to ensure 
 * the metamodel constraints remain valid.
 *
 * To tolerate inconsistent state that might occur temporarily while editing 
 * the object graph, can be set to YES. The code where the inconsistent state 
 * occur should be bracketed by as below:
 *
 * <example>
 * [self setIgnoringRelationshipConsistency: YES];
 * // some changes
 * [self setIgnoringRelationshipConsistency: NO];
 * </example>
 */
- (void)setIgnoringRelationshipConsistency: (BOOL)ignore;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Checks and updates the relationship consistency based on the metamodel to 
 * ensure the object graph remains valid with the new value.
 */
- (void)updateRelationshipConsistencyWithValue: (id)value forProperty: (NSString *)key;
/**
 *
 */
- (id)serializedValueForProperty: (NSString *)key;
/**
 * 
 */
- (void)setSerializedValue: (id)value forProperty: (NSString *)key;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns a CoreObject serialized representation by serializing into a plist 
 * the value that was retrieved with -serializedValueForProperty:.
 */
- (NSDictionary *)propertyListForValue: (id)value;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns a marker to track or index the receiver in the CoreObject serialized 
 * representation.
 *
 * Every time a COObject or subclass instance is in relationship with the 
 * receiver, at serialization time -referencePropertyList is used to encode the 
 * relationship in the CoreObject serialized representation.
 */
- (NSDictionary *)referencePropertyList;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns a value that can be passed to -setSerializedValue:forProperty: by 
 * deserializing a CoreObject serialized representation (the plist).
 */
- (NSObject *)valueForPropertyList: (NSObject *)plist;

@end
