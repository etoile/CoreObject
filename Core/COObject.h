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

@class COPersistentRoot, COEditingContext, CORevision, COBranch, CORelationshipCache, COObjectGraphContext, COCrossPersistentRootReferenceCache;

/**
 * Working copy of an object, owned by an editing context.
 * Relies on the context to resolve fault references to other COObjects.
 *
 * You should use ETUUID's to refer to objects outside of the context
 * of a COEditingContext.
 *
 * @section Initialization
 *
 * A core object can be instantiated in one or two steps by using respectively:
 *
 * <list>
 * <item>-[COEditingContext insertObjectWithEntityName:] or similar 
 * COEditingContext methods</item>
 * <item>-init and -becomePersistentInContext:</item>
 * </list>
 *
 * In both cases, -init is used to initialize the object.<br />
 * With -insertObjectWithEntityName:, the object becomes persistent immediately.
 * However in the second case, the object doesn't become persistent until 
 * -becomePersistentInContext: is called. You can use this approach
 * to instantiate transient objects or to mix transient and persistent instances.
 *
 * When writing a COObject subclass, -init can be overriden to initialize the 
 * the subclass properties. See the example in -init documentation.<br />
 * The designated initializer rule remains valid in a COObject class hierarchy, 
 * but -init must work correctly too (it must not return nil or a wrongly 
 * initialized instance), usually you have to override it to call the designated 
 * initializer. And secondary initializers must return valid instances or nil. 
 *
 * Don't create singletons for COObject subclass in +initialize, because 
 * -[COObject entityDescription] would return nil.
 *
 * For multivalued properties stored in instance variables, you are responsible 
 * to allocate the collections in each COObject subclass designed initializer, 
 * and to release them in -dealloc. If a multivalued property is stored in the 
 * the variable storage, COObject allocates the collections at initialization 
 * time and releases them at deallocation time (you can access these collections 
 * using -primitiveValueForKey: in your subclass initializers).
 *
 * @section Persistency
 *
 * Whan an object becomes persistent, you invoke 
 * -becomePersistentInContext: or the editing context does it.
 * Hence -becomePersistentInContext: can be overriden to udpate   
 * or initialize properties at persistency time. For example, 
 * -becomePersistentInContext: can be propagated to the instance
 * relationships to transively turn a transient object graph into a persistent 
 * one.
 *
 * @section Writing Accessors
 *
 * You can use Property-Value Coding to read and write properties. However 
 * implementing accessors can improve readability, type checking etc. For 
 * most attributes, we have a basic accessor pattern. For Multivalued properties 
 * (relationships or collection-based attributes), the basic accessor pattern 
 * won't work correctly.
 *
 * <strong>Basic Accessor Pattern</strong/>
 *
 * <example>
 * - (void)name
 * {
 *     // When no ivar is provided, you can use the variable storage as below
 *     // return [self primitiveValueForKey: @"name"];
 *     return name;
 * }
 *
 * - (void)setName: (NSString *)aName
 * {
 *     [self willChangeValueForProperty: @"name"];
 *     // When no ivar is provided, you can use the variable storage as below
 *     // [self setPrimitiveValue: aName: forKey: @"name"];
 *     name =  aName;
 *     [self didChangeValueForProperty: @"name"];
 * }
 * </example>
 *
 * <strong>Multivalued Accessor Pattern</strong/>
 *
 * The example below is based on a COObject subclass using a<em>names</em> 
 * instance variable. If the value is stored in the variable storage, the 
 * example must be adjusted to use -primitiveValueForKey: and 
 * -setPrimitiveValue:forKey:.<br />
 * -removeObject:atIndex:hint:forProperty: and 
 * -insertObject:atIndex:hint:forProperty: use the instance variable whose 
 * name matches the property (based on Key-Value Coding ivar search rules), or 
 * resort the variable storage when there is no matching ivar.
 *
 * <example>
 *
 * - (void)names
 * {
 *     return names;
 * }
 *
 * - (void)addName: (NSString *)aName
 * {
 *     [self insertObject: aName: atIndex: ETUndeterminedIndex hint: nil forProperty: @"names"];
 * }
 *
 * - (void)removeName: (NSString *)aName
 * {
 *     [self removeObject: aName: atIndex: ETUndeterminedIndex hint: nil forProperty: @"names"];
 * }
 *
 * // Direct setters are rare, but nonetheless it is possible to write one as below...
 * - (void)setNames: (id <ETCollection>)newNames
 * {
 *     id oldCollection = [[names mutableCopy] autorelease];
 *     [self willChangeValueForProperty: @"names"];
 *     names =  newNames;
 *     [self didChangeValueForProperty: @"names" oldValue: oldCollection];
 * }
 * </example>
 *
 * @section Notifications
 *
 * To better control persistency, -awakeFromFetch, -didReload, -willTurnIntoFault
 *
 * @section Serialization
 *
 * @section Faulting and Reloading
 *
 * When a core object not present in memory but exists in the store, 
 * -[COEditingContext objectWithUUID:] uses -[COEditingContext loadObject:] to 
 * bring the object back in memory. All the attribute values are immediately 
 * brought back, however relationships are not loaded immediately. For example, 
 * if a relationship consists of multiple objects that belong to an array, 
 * CoreObject doesn't load the real objects missing in memory, but put a COFault 
 * object in the array for each real object not yet loaded.<br /> 
 * Faults are core objects whose state remain unitialized until a message is 
 * sent to them.
 *
 * Each fault has the same UUID than the core object it stands for. As a result, 
 * when requesting multiple times the same object not present in memory, 
 * the same fault instance is returned every time by 
 * -[COEditingContext objectWithUUID:].
 *
 * When an object that was previously a fault is loaded, then once the 
 * attribute values have been deserialized, -awakeFromFetch is sent to the 
 * object to let it update its state before being used. You can thus override 
 * -awakeFromFetch to recreate transient properties, recompute correct property 
 * values based on the deserialized values, etc. But you must not access or 
 * update persistent relationships in -awakeFromFetch directly. You can override 
 * -didLoad to manipulate persistent relationships in a such way.<br />
 * Loading an object can result in multiple objects being loaded if some 
 * relationships are unfaulted. For example, an accessor can depend on or alter 
 * a relationship object state (e.g. a parent object in a tree structure). 
 * Although you should avoid to do so, in some cases it cannot be avoided. 
 * To give a more concrete example in EtoileUI, -[ETLayoutItem setView:] uses   
 * -[ETLayoutItemGroup handleAttacheViewOfItem:] to adjust the parent view.<br />
 * For -loadObject:, the loaded object and all the relationships transitively 
 * loaded receive -awakeFromFetch, then at the very end -didLoad is called. At 
 * this point, you can be sure the objects are not in a partially 
 * initialized/deserialized state.<br />
 * Don't forget to call the superclass implementation first for both 
 * -awakeFromFetch and -didLoad.<br />
 * In addition, navigating a root object history results in -awakeFromFetch 
 * being sent to each object loaded to a new revision in the object graph (not 
 * yet the case), rather being turned back into a fault. When every object in 
 * the object graph has been reloaded or turned back into fault, -didReload is 
 * sent to the root object.
 *
 * For various reasons such as memory usage or root objects being reloaded to  
 * some revision, core objects can be turned back into faults (not yet supported).
 * Before unloading an object, -willTurnIntoFault is called on it, then the 
 * object is unloaded (property values are released and reset to a null value), 
 * in the end COFault becomes its class and the resulting fault receives 
 * the message -didTurnIntoFault.
 *
 * Property access TODO: 
 * -valueForProperty: is overridden in a special case (ETLayoutItem).
 * We need a special property getter that can never be overridden and has
 * very precise behaviour:
 * 1. call custom getter, if any
 * 2. access variable storage.
 */
@interface COObject : NSObject <NSCopying, COObjectMatching>
{
	@private
	ETEntityDescription *_entityDescription;
	ETUUID *_UUID;
	COObjectGraphContext *__weak _objectGraphContext; // weak reference
	@protected
	NSMutableDictionary *_variableStorage;
	/** Cache for inverse or incoming relationships e.g. parent(s) */
    CORelationshipCache *_relationshipCache;
    NSMutableDictionary *_relationshipsAsCOPathOrETUUID;
	@private
	BOOL _inDescription; // FIXME: remove; only for debugging
	BOOL _isInitialized;
}

/** @taskunit Initialization */

/** <init />
 * Initializes and returns a non-persistent object.
 *
 * The receiver can be made persistent later, by inserting it into an editing 
 * context with -becomePersistentInContext:.<br />
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
 * late persistency with -becomePersistentInContext:). For example,
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
- (id)initWithObjectGraphContext: (COObjectGraphContext *)aContext;
/**
 * Initializes and returns a non-persistent object that uses a custom entity 
 * description.
 *
 * See -init.
 */
- (id)initWithEntityDescription: (ETEntityDescription *)anEntityDesc;

- (id)copyWithZone: (NSZone *)aZone usesModelDescription: (BOOL)usesModelDescription;

/** @taskunit Persistency Attributes */

/** 
 * Returns the UUID that uniquely identifies the persistent object that 
 * corresponds to the receiver.
 *
 * A persistent object has a single instance per editing context.
 */
@property (nonatomic, readonly) ETUUID *UUID;
/**
 * Returns the metamodel that declares all the object properties (persistent and 
 * transient).
 *
 * See also -propertyNames and -persistentPropertyNames.
 */
@property (nonatomic, readonly) ETEntityDescription *entityDescription;
/** 
 * Returns the persistent root when the receiver is persistent, otherwise 
 * returns nil.
 */
@property (nonatomic, readonly) COPersistentRoot *persistentRoot;
/**
 * Returns the object graph context owning the receiver.
 */
@property (nonatomic, readonly) COObjectGraphContext *objectGraphContext;
/** 
 * Returns the root object when the receiver is persistent, otherwise returns nil.
 *
 * When the receiver is persistent, returns either self or the root object that 
 * encloses the receiver as an embedded object.
 *
 * See also -isRoot.
 */
@property (nonatomic, readonly) id rootObject;
/**
 * Returns whether the receiver is saved on the disk.
 *
 * When persistent, the receiver has both a valid editing context and root object.
 */
@property (nonatomic, readonly) BOOL isPersistent;
/** 
 * Returns whether the receiver is a root object that can enclose embedded 
 * objects.
 *
 * Embedded or non-persistent objects returns NO.
 *
 * See also -rootObject.
 */
@property (nonatomic, readonly) BOOL isRoot;

/** @taskunit History Attributes */

/**
 * Return the revision of this object in the branch owning the object graph 
 * context.
 *
 * See also -[COBranch currentRevision].
 */
- (CORevision *)revision;

/** @taskunit Contained Objects based on the Metamodel */

/**
 * Returns an array containing all COObjects "strongly contained" by this one.
 * This means objects which are values for "composite" properties.
 */
- (NSArray *)allStronglyContainedObjects;
- (NSArray*)embeddedOrReferencedObjects;

/** @taskunit Basic Properties */

/**
 * The object name.
 */
@property (nonatomic, strong) NSString *name;

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
 * The returned date is the last current branch revision date. See -[CORevision date].
 *
 * The current branch is -[COPersistentRoot commitTrack].
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

/** @taskunit Validation */

/**
 * Validates every persistent property, then returns a validation result array.
 *
 * Valid results are not included in the returned array.
 *
 * When the entity description includes persistent properties, transient objects 
 * are validatable too.
 *
 * See -validateValue:forProperty: and ETValidationResult.
 */
- (NSArray *)validateAllValues;
/**
 * Validates the proposed value against the property, then returns a validation 
 * result array.
 *
 * Valid results are not included in the returned array. On success, returns 
 * an emtpy array.
 *
 * The validation is divided in two steps that occurs in the order below:
 *
 * <list>
 * <item>Metamodel validation using -[ETPropertyDescription validateValue:forKey:],  
 * (for relationships, the opposite property is validated too)</item>
 * <item>Custom validation when a method validate<em>PropertyName</em>: returning 
 * validation result is implemented (this validation scheme is not the same one 
 * that the Key-Value Coding one)</item>
 * </list>
 *
 * See -validateValue:forProperty: and ETValidationResult.
 */
- (NSArray *)validateValue: (id)value forProperty: (NSString *)key;
/**
 * <override-dummy />
 * Validates the receiver when it belongs to the inserted objects in the commit 
 * underway.
 *
 * By default, returns nil.
 *
 * Because this method is invoked at commit time, you can be sure that 
 * -becomePersistentInContext: was called previously.
 *
 * This method must return nil on validation success, otherwise it must return 
 * suberrors (or a single error) that include their validation results in the 
 * user info under the key kCOValidationResultKey.
 *
 * The superclass implementation must be called, then the returned error is 
 * either returned directly, or when validation doesn't succeed locally 
 * combined with the new errors through +[NSError errorWithErrors:].
 *
 * See also -[COEditingContext insertedObjects] and example in -validateForUpdate.
 */
- (NSError *)validateForInsert;
/**
 * <override-dummy />
 * Validates the receiver when it belongs to the updated objects in the commit 
 * under way. 
 *
 * By default, returns nil.
 *
 * Will be invoked when the receiver property values have been changed since 
 * the last commit.
 *
 * This method must return nil on validation success, otherwise it must return 
 * suberrors (or a single error) that include their validation results in the 
 * user info under the key kCOValidationResultKey.
 *
 * The superclass implementation must be called, then the returned error is 
 * either returned directly, or when validation doesn't succeed locally 
 * combined with the new errors through +[NSError errorWithErrors:].
 *
 * <example>return [[super validateForUpdate] errorWithErrors: [NSError errorsWithValidationResults: results]];</example>
 *
 * See also -[COEditingContext updatedObjects].
 */
- (NSError *)validateForUpdate;
/**
 * <override-dummy />
 * Validates the receiver when it belongs to the deleted objects in the commit 
 * underway.
 *
 * By default, returns nil.
 *
 * This method must return nil on validation success, otherwise it must return 
 * suberrors (or a single error) that include their validation results in the 
 * user info under the key kCOValidationResultKey.
 *
 * The superclass implementation must be called, then the returned error is 
 * either returned directly, or when validation doesn't succeed locally 
 * combined with the new errors through +[NSError errorWithErrors:].
 *
 * See also -[COEditingContext deletedObjects] and example in -validateForUpdate.
 */
- (NSError *)validateForDelete;
/**
 * Calls -validateValue:forProperty: to validate the value, and returns the 
 * validation result through aValue and anError.
 *
 * This method exists to integrate CoreObject validation with existing Cocoa or 
 * GNUstep programs.<br />
 * For Etoile programs or new projects, you should use -validateValue:forProperty:.
 */
- (BOOL)validateValue:(id *)aValue forKey:(NSString *)key error:(NSError **)anError;

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
- (void)didChangeValueForProperty: (NSString *)key oldValue: (id)oldValue;

/** @taskunit Collection Mutation with Integrity Check */

/** 
 * Checks the insertion and the object that goes along respect the metamodel 
 * constraints, then calls -insertObject:atIndex:hint: on the collection bound 
 * to the property.<br />
 * Finally if the property is a relationship, this method updates the 
 * relationship consistency.
 *
 * See also ETCollectionMutation.
 */
- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key;
/** 
 * Checks the insertion and the object that goes along respect the metamodel 
 * constraints, then calls -removeObject:atIndex:hint: on the collection bound 
 * to the property.<br />
 * Finally if the property is a relationship, this method updates the 
 * relationship consistency.
 *
 * See also ETCollectionMutation. 
 */
- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key;

/** @taskunit Overridable Notifications */

- (void)awakeFromFetch;
- (void)willLoad;
- (void)didLoad;
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
- (BOOL)isTemporalInstance: (id)anObject;

/** @taskunit Object Matching */

/**
 * Returns the receiver put in an array when it matches the query, otherwise 
 * returns an empty array.
 */
- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery;

/** @taskunit Debugging and Description */

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
 * Returns the receiver revision number as a string.
 *
 * This is used to present the revision to the user in the UI.
 */
- (NSString *)revisionDescription;

/** 
 * Returns the receiver tags in a coma separated list.
 *
 * This is used to present -tags to the user in the UI.
 */
- (NSString *)tagDescription;

@end
