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
 * @group Core
 * @abstract An entity object inside a transient or persistent object graph.
 *
 * An COObject instance is described by a metamodel (see -entityDescription) and 
 * owned by an object graph context. The object graph context is usually 
 * owned by a branch if persistent, or standalone if transient. In the latter 
 * case -[COObject branch] and -[COObject persistentRoot] returns nil.
 *
 * From COEditingContext to COObject, there is a owner chain where each element 
 * owns the one just below in the list:
 *
 * <list>
 * <item>COEditingContext</item>
 * <item>COPersistentRoot</item>
 * <item>COBranch</item>
 * <item>COObjectGraphContext</item>
 * </list>
 *
 * @section Initialization
 *
 * A core object can be instantiated by using -initWithObjectGraphContext: or 
 * some other initializer (-init is not supported). The resulting object is 
 * a inner object that belongs to the object graph context.
 *
 * For a transient object graph context, you can later use 
 * -[COEditingContext insertPersistentRootWithRootObject:] to turn an existing 
 * inner object into a root object (the object graph context becoming persistent).
 *
 * You can instantiate also a new persistent root and retrieve its root object 
 * by using -[COEditingContext insertPersistentRootWithEntityName:] or similar 
 * COEditingContext methods.
 *
 * When writing a COObject subclass, -initWithObjectGraphContext can be 
 * overriden to initialize the the subclass properties.<br />
 * The designated initializer rule remains valid in the COObject class hierarchy, 
 * but -initWithObjectGraphContext: must work correctly too (it must never return 
 * nil or a wrongly initialized instance), usually you have to override it to 
 * call the designated initializer.<br />
 * All secondary initializers (inherited or not) must return valid instances or 
 * nil. The easiest way to comply is described below:
 *
 * <list>
 * <item>For additional initializers, call the designated initializer</item>
 * <item>For each new designated initializer, override 
 * -initWithObjectGraphContext: to call it</item>
 * </list>
 *
 * Don't create singletons for COObject subclass in +initialize, because 
 * -[COObject entityDescription] would return nil.
 *
 * For multivalued properties stored in instance variables, you are responsible 
 * to allocate the collections in each COObject subclass designed initializer, 
 * and to release them in -dealloc (or use ARC). If a multivalued property is
 * stored in the variable storage, COObject allocates the collections at 
 * initialization time and releases them at deallocation time (you can access 
 * these collections using -valueForVariableStorageKey: in your subclass 
 * initializers).
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
 *     // return [self valueForVariableStorageKey: @"name"];
 *     return name;
 * }
 *
 * - (void)setName: (NSString *)aName
 * {
 *     [self willChangeValueForProperty: @"name"];
 *     // When no ivar is provided, you can use the variable storage as below
 *     // [self setValue: aName: forVariableStorageKey: @"name"];
 *     name =  aName;
 *     [self didChangeValueForProperty: @"name"];
 * }
 * </example>
 *
 * <strong>Multivalued Accessor Pattern</strong/>
 *
 * The example below is based on a COObject subclass using a<em>names</em> 
 * instance variable. If the value is stored in the variable storage, the 
 * example must be adjusted to use -valueForVariableStorageKey: and 
 * -setValue:forVariableStorageKey:.
 *
 * <example>
 *
 * - (void)names
 * {
 *     // The synthesized accessor would just do the same.
 *     return [names copy];
 * }
 *
 * - (void)addName: (NSString *)aName
 * {
 *     NSArray *insertedObjects = A(aName);
 *     NSIndexSet *insertionIndexes = [NSIndexSet indexSet];
 *
 *     [self willChangeValueForProperty: key
 *	                          atIndexes: insertionIndexes
 *                          withObjects: insertedObjects
 *                         mutationKind: ETCollectionMutationKindInsertion];
 *
 *     // You can update the collection in whatever you want, the synthesized 
 *     // accessors would just use ETCollectionMutation methods.
 *     [names addObject: aName];
 *
 *     [self didChangeValueForProperty: key
 *                           atIndexes: insertionIndexes
 *                         withObjects: insertedObjects
 *                        mutationKind: ETCollectionMutationKindInsertion];
 * }
 *
 * - (void)removeName: (NSString *)aName
 * {
 *     NSArray *removedObjects = A(aName);
 *     NSIndexSet *removalIndexes = [NSIndexSet indexSet];
 *
 *     [self willChangeValueForProperty: key
 *	                          atIndexes: removalIndexes
 *                          withObjects: removedObjects
 *                         mutationKind: ETCollectionMutationKindRemoval];
 *
 *     // You can update the collection in whatever you want, the synthesized 
 *     // accessors would just use ETCollectionMutation methods.
 *     [names removeObject: aName];
 *
 *     [self didChangeValueForProperty: key
 *                           atIndexes: removalIndexes
 *                         withObjects: removedObjects
 *                        mutationKind: ETCollectionMutationKindRemoval];
 * }
 *
 * // Direct setters are rare, but nonetheless it is possible to write one as below...
 * - (void)setNames: (id <ETCollection>)newNames
 * {
 *     NSArray *replacementObjects = A(aName);
 *     // If no indexes are provided, the entire collection is replaced or set.
 *     NSIndexSet *replacementIndexes = [NSIndexSet indexSet];
 *
 *     [self willChangeValueForProperty: key
 *	                          atIndexes: replacementIndexes
 *                          withObjects: replacementObjects
 *                         mutationKind: ETCollectionMutationKindReplacement];
 *
 *     // You can update the collection in whatever you want, the synthesized 
 *     // accessor would just do the same or allocate a custom CoreObject
 *     // primitive collections.
 *     names = [newNames mutableCopy];
 *
 *     [self didChangeValueForProperty: key
 *                           atIndexes: replacementIndexes
 *                         withObjects: replacementObjects
 *                        mutationKind: ETCollectionMutationKindReplacement];
 * }
 * </example>
 *
 * To implement a getter that returns an incoming relationships e.g. parent(s), 
 * just use -valueForVariableStorageKey: (see the -name getter example above).
 *
 * You must never implement incoming relationship setters. 
 *
 * To access incoming relationships when no accessors are available, just 
 * use -valueForProperty: as you would do it for other properties.
 *
 * @section Notifications
 *
 * To better control persistency, -awakeFromDeserialization, -didReload, -willTurnIntoFault
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
 * attribute values have been deserialized, -awakeFromDeserialization is sent to the 
 * object to let it update its state before being used. You can thus override 
 * -awakeFromDeserialization to recreate transient properties, recompute correct property 
 * values based on the deserialized values, etc. But you must not access or 
 * update persistent relationships in -awakeFromDeserialization directly. You can override 
 * -didLoad to manipulate persistent relationships in a such way.<br />
 * Loading an object can result in multiple objects being loaded if some 
 * relationships are unfaulted. For example, an accessor can depend on or alter 
 * a relationship object state (e.g. a parent object in a tree structure). 
 * Although you should avoid to do so, in some cases it cannot be avoided. 
 * To give a more concrete example in EtoileUI, -[ETLayoutItem setView:] uses   
 * -[ETLayoutItemGroup handleAttacheViewOfItem:] to adjust the parent view.<br />
 * For -loadObject:, the loaded object and all the relationships transitively 
 * loaded receive -awakeFromDeserialization, then at the very end -didLoad is called. At 
 * this point, you can be sure the objects are not in a partially 
 * initialized/deserialized state.<br />
 * Don't forget to call the superclass implementation first for both 
 * -awakeFromDeserialization and -didLoad.<br />
 * In addition, navigating a root object history results in -awakeFromDeserialization 
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
 */
@interface COObject : NSObject <COObjectMatching>
{
	@private
	ETEntityDescription *_entityDescription;
	ETUUID *_UUID;
	COObjectGraphContext *__weak _objectGraphContext;
	@protected
	NSMutableDictionary *_variableStorage;
	@private
	/** 
	 * Storage for incoming relationships e.g. parent(s). CoreObject doesn't
	 * allow storing incoming relationships in ivars or variable storage. 
	 */
    CORelationshipCache *_incomingRelationshipCache;
	/**
	 * Stack of old collection values during nested change notifications i.e. 
	 * -willChangeValueForProperty: is called multiple times for the same object.
	 */
	NSMutableArray *_oldValues;
	/**
	 * Dictionary UUIDs by property names. Used by 
	 * -[COObject storeItemFromDictionaryForPropertyDescription:] to recreate 
	 * a COItem representing a keyed multivalued property using the same stable 
	 * UUID accross repeated serializations.
	 */
	NSMutableDictionary *_additionalStoreItemUUIDs;
	BOOL _isPrepared;
}


/** @taskunit Initialization */


/** <init />
 * Initializes and returns object that is owned and managed by the given object 
 * graph context.
 * 
 * During the initialization, the receiver is automatically inserted into
 * the object graph context. As a result, the receiver appears in
 * -[COObjectGraphContext insertedObjects] on return.
 *
 * If the object graph context is transient (not owned by any branch), the
 * returned object is transient, otherwise it is persistent.<br />
 * It is possible to turn a transient object into a persistent one, by making 
 * the object graph context persistent with 
 * -[COEditingContext insertPersistentRootWithRootObject:]. For example:
 *
 * <example>
 * COObjectGraphContext *graphContext = [COObjectGraphContext new];
 * COObject *object = [[COObject alloc] initWithObjectGraphContext: graphContext];
 *
 * [editingContext insertPersistentRootWithRootObject: [graphContext rootObject]];
 * </example>
 *
 * You cannot use -init to create a COObject instance.
 *
 * For a nil context, raises an NSInvalidArgumentException.
 */
- (id)initWithObjectGraphContext: (COObjectGraphContext *)aContext;
/**
 * Initializes and returns an object that uses a custom entity description.
 *
 * For initialization, you should usually just use -initWithObjectGraphContext:.
 *
 * If you have subclassed COObject, in most cases, you want to instantiate 
 * your subclass using the identically named entity description, and 
 * -initWithObjectGraphContext: does just that.
 *
 * For some use cases (e.g. custom object representation or partial object 
 * loading), you might want to use a subentity or parent entity description 
 * rather than the entity description registered for the receiver class in
 * -[COObjectGraphContext modelDescriptionRepository], and this initializer is the only way 
 * to do that.
 *
 * For a subclass, this method results in the subclass designated initializer
 * being called.
 */
- (id)initWithEntityDescription: (ETEntityDescription *)anEntityDesc
             objectGraphContext: (COObjectGraphContext *)aContext;


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
 * Returns the branch when the receiver is persistent, otherwise
 * returns nil.
 */
@property (nonatomic, readonly) COBranch *branch;
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
 * encloses the receiver as an inner object.
 *
 * See also -isRoot.
 */
@property (nonatomic, readonly) id rootObject;
/**
 * Returns whether the receiver is owned by a persistent root.
 *
 * This doesn't mean the object has been saved to the disk yet.
 *
 * When persistent, the receiver has a valid root object and its object 
 * graph context is owned by a branch.
 *
 * See also -persistentRoot.
 */
@property (nonatomic, readonly) BOOL isPersistent;
/** 
 * Returns whether the receiver is a root object that provides access to 
 * other inner objects (in the object graph context).
 *
 * Inner or non-persistent objects returns NO.
 *
 * See also -rootObject.
 */
@property (nonatomic, readonly) BOOL isRoot;

/**
 * Whether it is permissible to make an alias to the receiver when copying
 * an object graph. Default is YES.
 */
@property (nonatomic, readonly) BOOL isShared;

/** @taskunit History Attributes */


/**
 * Return the revision of this object in the branch owning the object graph 
 * context.
 *
 * See also -[COBranch currentRevision].
 */
@property (nonatomic, readonly) CORevision *revision;


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
 * Can be overriden to return a custom string. See 
 * -[COCollection objectForIdentifier:].
 */
@property (nonatomic, readonly) NSString *identifier;
/**
 * Returns -name.
 */
- (NSString *)displayName;
/**
 * Returns the tags attached to the receiver. 
 *
 * The returned collection contains COTag objects.
 */
@property (nonatomic, readonly) NSSet *tags;


/** @taskunit Property-Value Coding */


/**
 * <override-never />
 * Returns the properties declared in the receiver entity description.
 *
 * See also -entityDescription and -persistentPropertyNames.
 */
- (NSArray *)propertyNames;
/**
 * <override-never />
 * Returns the persistent properties declared in the receiver entity description.
 *
 * The returned array contains the property descriptions which replies YES to 
 * -[ETPropertyDescription isPersistent].
 *
 * See also -entityDescription and -propertyNames.
 */
- (NSArray *)persistentPropertyNames;
/**
 * <override-never />
 * Returns the property value.
 *
 * When the property is not declared in the entity description, raises an 
 * NSInvalidArgumentException.
 *
 * See also -setValue:forProperty:.
 */
- (id)valueForProperty: (NSString *)key;
/**
 * <override-never />
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
 * an empty array.
 *
 * The validation is divided in two steps that occurs in the order below:
 *
 * <list>
 * <item><em>Metamodel Validation</em> using -[ETPropertyDescription validateValue:forKey:],  
 * (for relationships, the opposite property is validated too)</item>
 * <item><em>Model Validation</em>, when a method -validate<em>PropertyName</em>: 
 * is implemented (e.g. the method signature must be match 
 * <code>-(ETValidationResult *)validateName</code>).</item>
 * </list>
 *
 * The Model validation scheme doesn't support Key-Value Coding custom 
 * validation methods (e.g. -validateName:error:).
 *
 * See -validateValue:forProperty: and ETValidationResult.
 */
- (NSArray *)validateValue: (id)value forProperty: (NSString *)key;
/**
 * <override-dummy />
 * Validates the receiver when it belongs to the inserted or updated objects in 
 * the commit under way, then returns an error array.
 *
 * By default, returns -validateAllValues result (as an error array).
 *
 * This method must return an empty array on validation success, otherwise it 
 * must return an error array. Each error (usually a COError object) can wrap a 
 * validation result in -[NSError userInfo] under the key kCOValidationResultKey. 
 * For wrapping validation result, you should use 
 * -[COError errorWithValidationResult:].
 *
 * The superclass implementation must be called, then the returned array is 
 * either returned directly, or when validation doesn't succeed locally 
 * combined with the new array through -[NSArray arrayByAddingObjectsFromArray:].
 *
 * <example>
 * NSArray *errors = [COError errorsWithValidationResults: results];
 * 
 * // additionalErrors would contain errors that don't wrap a validation result 
 * // (without a kCOValidationResultKey in their user info)
 * errors = [errors arrayByAddingObjectsFromArray: additionalErrors];
 *
 * return [[super validate] arrayByAddingObjectsFromArray: errors];
 * </example>
 *
 * To know if the receiver is validated for an insertion or an update, pass 
 * the receiver to -[COObjectGraphContext isUpdatedObject:].
 *
 * For objects collected during a GC phase by COObjectGraphContext, no 
 * special validation occurs. You cannot override -validate to cancel a 
 * receiver deletion (you can override -dealloc to react to it though).<br />
 * For cancelling deletions, override -validate to detect invalid object 
 * removals in outgoing relationships (e.g. the receiver is a parent). 
 * For a removed object, if no incoming relationships retains it, the object is 
 * going to be deleted (collected in the next GC phase).
 *
 * See also COError, -[COObjectGraphContext insertedObjects], 
 * -[COObjectGraphContext updatedObjects] and -[COObjectGraphContext changedObjects].
 */
- (NSArray *)validate;
/**
 * Calls -validateValue:forProperty: to validate the value, and returns the 
 * validation result through aValue and anError.
 *
 * This method exists to integrate CoreObject validation with existing Cocoa or 
 * GNUstep programs.<br />
 * For Etoile programs or new projects, you should use -validateValue:forProperty:.
 */
- (BOOL)validateValue: (id *)aValue forKey: (NSString *)key error: (NSError **)anError;


/** @taskunit Direct Access to the Variable Storage */


/**
 * <override-never />
 * Returns a value from the variable storage.
 *
 * Can be used to read a property with no instance variable.
 *
 * This is a low-level method whose use should be restricted to serialization 
 * code and accessors that expose properties with no related instance variable.
 */
- (id)valueForVariableStorageKey: (NSString *)key;
/**
 * <override-never />
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
- (void)setValue: (id)value forVariableStorageKey: (NSString *)key;


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
- (void)willChangeValueForProperty: (NSString *)property
                         atIndexes: (NSIndexSet *)indexes
                       withObjects: (NSArray *)objects
                      mutationKind: (ETCollectionMutationKind)mutationKind;
- (void)didChangeValueForProperty: (NSString *)property
                        atIndexes: (NSIndexSet *)indexes
                      withObjects: (NSArray *)objects
                     mutationKind: (ETCollectionMutationKind)mutationKind;


/** @taskunit Overridable Loading Notifications */


/**
 * <override-dummy />
 * For an object graph context loading (or reloading), tells the receiver that
 * the receiver was just deserialized, and it can recreate additional transient 
 * state.
 *
 * During the loading, each concerned inner object is deserialized and receives 
 * -awakeFromDeserialization in turn (just before deserializing the next object). 
 * The order in which inner objects are deserialized is random. So you should 
 * never access other COObject instances or manipulate persistent relationships 
 * in an overriden implementation.
 *
 * For recreating transient state related to persistent relationships or react 
 * to the object graph loading, you must override -didLoadObjectGraph.
 *
 * The object graph context reuse existing objects (based on their UUID idendity) 
 * accross reloads, so be cautious to reset all transient state in 
 * -awakeFromDeserialization (or adjust it to match the last deserialized state).
 *
 * This method is also called for object graph copies inside the current object 
 * graph context (see COCopier).
 *
 * If you override this method, the superclass implementation must be called 
 * first.
 */
- (void)awakeFromDeserialization;
/**
 * <override-dummy />
 * For an object graph context loading (or reloading), tells the receiver that 
 * all the inner objects, which were not yet loaded or for which a new state was 
 * needed, have been deserialized.
 *
 * You can override this method, to recreate transient state related to 
 * persistent relationships, or react to a partial or entire object graph 
 * loading.
 *
 * Each inner object that has received -awakeFromDeserialization, receives 
 * -didLoadObjectGraph. The root object is always the last to receive 
 * -didLoadObjectGraph (if the root object was loaded or reloaded).
 *
 * Don't forget that you shouldn't expect all inner objects to receive
 * -awakeFromDeserialization and -didLoadObjectGraph during a loading. For a 
 * reloading, the object graph context doesn't discard the existing objects but 
 * reuse them (based on their UUID idendity).<br />
 * For an object graph copy (see COCopier), the object copies receive 
 * -awakeFromDeserialization and -didLoadObjectGraph, but all other inner 
 * objects don't.
 *
 * If you override this method, the superclass implementation must be called 
 * first.
 */
- (void)didLoadObjectGraph;


/** @taskunit Object Equality */


/** 
 * Returns a hash based on the UUID. 
 */
- (NSUInteger)hash;
/**
 * Returns whether anObject is equal to the receiver.
 *
 * Two persistent objects are equal if they share the same UUID (even when the 
 * two object revisions don't match).
 *
 * Use -isTemporallyEqual: to check both UUID and revision match. For example, 
 * when the same object is in use in multiple editing contexts simultaneously.
 */
- (BOOL)isEqual: (id)anObject;
/** 
 * Returns whether anObject saved state is equal the receiver saved state. 
 *
 * Two persistent objects are temporally equal if they share the same UUID and 
 * revision.
 *
 * See also -isEqual:.
 */
- (BOOL)isTemporallyEqual: (id)anObject;


/** @taskunit Object Matching */


/**
 * Returns the receiver put in an array when it matches the query, otherwise 
 * returns an empty array.
 */
- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery;


/** @taskunit Debugging and Description */


/** 
 * Returns a description that includes the receiver properties and their values. 
 *
 * See -detailedDescriptionWithTraversalKey:, and -[NSObject descriptionWithOptions:] 
 * to implement custom detailed descriptions.
 */
- (NSString *)detailedDescription;
/** 
 * Returns a tree description for all the objects encountered while traversing 
 * the given relationship (including the receiver).
 *
 * For each relationship object, the output looks the same than -
 * detailedDescription.
 *
 * You can use this method to print an object graph or tree. The max traversal 
 * depth is 20 levels.
 *
 * See -[NSObject descriptionWithOptions:] to implement custom detailed 
 * descriptions.
 */
- (NSString *)detailedDescriptionWithTraversalKey: (NSString *)aProperty;
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
@property (nonatomic, readonly) NSString *typeDescription;
/**
 * Returns the receiver revision as a string.
 *
 * This is used to present the revision to the user in the UI.
 */
@property (nonatomic, readonly) NSString *revisionDescription;
/** 
 * Returns the receiver tags in a coma separated list.
 *
 * This is used to present -tags to the user in the UI.
 */
@property (nonatomic, readonly) NSString *tagDescription;

@end
