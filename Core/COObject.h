/**
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COPersistentRoot, COEditingContext, CORevision, COBranch, COObjectGraphContext;
@class CORelationshipCache, COCrossPersistentRootReferenceCache, COTag;

NS_ASSUME_NONNULL_BEGIN

/**
 * @group Core
 * @abstract A mutable in-memory representation of an inner object in an object
 * graph context (a counterpart to COItem, whose relationships are represented 
 * as Objective-C pointers instead of UUIDs).
 *
 * A COObject instance is a generic model object described by a metamodel (see 
 * -entityDescription), and its lifecycle is managed by a COObjectGraphContext.
 *
 * For a persistent object, a -branch owns the -objectGraphContext.
 *
 * For a transient object, the -objectGraphContext is standalone, -branch and 
 * -persistentRoot return nil.
 *
 * From COEditingContext to COObject, there is a owner chain where each element 
 * owns the one just below in the list:
 *
 * <list>
 * <item>COEditingContext</item>
 * <item>COPersistentRoot</item>
 * <item>COBranch</item>
 * <item>COObjectGraphContext</item>
 * <item>COObject</item>
 * </list>
 *
 * The COObject class itself can represent objects with any entity description,
 * but you can also make subclasses of COObject for a particular entity to get 
 * static type checking.
 * 
 * @section Object Equality
 *
 * COObject inherits NSObject's -hash and -isEqual: methods, so equality is
 * based on pointer comparison.
 *
 * You must never override -hash or -isEqual:. This is a consequence of the fact that
 * we promise it is safe to put a COObject instance in an NSSet and then mutate
 * the COObject.
 *
 * Use -isTemporallyEqual: to check both UUID and revision match. For example,
 * when the same object is in use in multiple editing contexts simultaneously.
 *
 * @section Common Use Cases
 *
 * For an existing persistent root or transient object graph context, 
 * -initWithObjectGraphContext: is used to create additional inner objects. 
 *
 * To navigate the object graph, access or change the state of these objects,
 * -valueForProperty: and -setValue:forProperty: are available. For instances 
 * of COObject subclasses that declare synthesized properties, you should use 
 * these accessors rather than those Property-Value Coding methods.
 *
 * @section Creation
 *
 * A persistent or transient object can be instantiated by using 
 * -initWithObjectGraphContext: or some other initializer (-init is not 
 * supported). The resulting object is a inner object that belongs to the object 
 * graph context.
 *
 * For a transient object graph context, you can later use 
 * -[COEditingContext insertNewPersistentRootWithRootObject:] to turn an existing 
 * inner object into a root object (the object graph context becoming persistent).
 *
 * You can instantiate also a new persistent root and retrieve its root object 
 * by using -[COEditingContext insertNewPersistentRootWithEntityName:] or similar 
 * COEditingContext methods.
 *
 * When writing a COObject subclass, -initWithObjectGraphContext: can be 
 * overriden to initialize the the subclass properties.
 *
 * The designated initializer rule remains valid in the COObject class hierarchy, 
 * but -initWithObjectGraphContext: must work correctly too (it must never return 
 * nil or a wrongly initialized instance), usually you have to override it to 
 * call the designated initializer.
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
 * For the property initialization rules, see Properties section.
 *
 * @section Deletion
 *
 * An inner object is deleted, when it becomes unreachable from the root object 
 * in the -objectGraphContext. 
 *
 * It is never explicitly deleted, instead this object must be removed in a 
 * collection or a relationship, and once this object doesn't belong to any 
 * collection or relationship that can be accessed from the root object, it 
 * is declared as unreachable, and will be deleted by the COObjectGraphContext  
 * garbage collection (usually on a future commit).
 *
 * Persistent relationships cannot be accessed in -dealloc. For discarded 
 * objects, -willDiscard can be overriden to propagate changes related to
 * persistent relationships just before they become invalid.
 *
 * @section Properties
 *
 * By default, COObject stores its properties in a variable storage, similar to 
 * a dictionary. In the rare cases, where the variable storage is too slow, 
 * properties can be stored in instance variables. 
 *
 * In a COObject subclass implementation, the variable storage can be accessed 
 * with -valueForVariableStorageKey: and -setValue:forVariableStorageKey:. You 
 * must not access the properties with these methods from other objects, this 
 * is the same than a direct instance variable access. For reading and writing 
 * properties, you must use accessors (synthesized or hand-written ones), or 
 * -valueForProperty: and -setValue:forProperty: (known as Property-Value 
 * Coding).
 *
 * For multivalued properties stored in instance variables, you are responsible 
 * to allocate the collections in each COObject subclass designed initializer, 
 * and to release them in -dealloc (or use ARC). If a multivalued property is
 * stored in the variable storage, COObject allocates the collections at 
 * initialization time and releases them at deallocation time (you can access 
 * these collections using -valueForVariableStorageKey: in your subclass 
 * initializers).
 *
 * For explanations about accessors, see Writing Accessors section.
 *
 * @section Writing Accessors
 *
 * You can use Property-Value Coding to read and write properties. However 
 * implementing accessors can improve readability, type checking etc. For 
 * most attributes, we have a basic accessor pattern. For Multivalued properties 
 * (relationships or collection-based attributes), the basic accessor pattern 
 * won't work correctly.
 *
 * For a COObject subclass, CoreObject will synthesize attribute accessors at 
 * run-time, if the property is declared <em>@dynamic</em> on the 
 * implementation side. For now, CoreObject doesn't synthesize 
 * collection-compliant accessors (such as Key-Value Coding collection 
 * accessors) beside <em>set</em> and <em>get</em>, all collection mutation 
 * methods must be hand-written based on the Multivalued Accessor Pattern. 
 *
 * Note: For a COObject subclass such as COCollection that holds a single 
 * collection, the subclass can conform to ETCollection and ETCollectionMutation 
 * protocols, and adopt their related traits, in this way no dedicated accessors 
 * need to be implemented.
 *
 * <strong>Basic Accessor Pattern</strong>
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
 * <strong>Multivalued Accessor Pattern</strong>
 *
 * The example below is based on a COObject subclass using a<em>names</em> 
 * instance variable. If the value is stored in the variable storage, the 
 * example must be adjusted to use -valueForVariableStorageKey: and 
 * -setValue:forVariableStorageKey:.
 *
 * <example>
 * - (void)names
 * {
 *     // The synthesized accessor would just do the same.
 *     return [names copy];
 * }
 *
 * - (void)addName: (NSString *)aName
 * {
 *     NSArray *insertedObjects = @[aName];
 *     NSIndexSet *insertionIndexes = [NSIndexSet indexSet];
 *
 *     [self willChangeValueForProperty: key
 *                            atIndexes: insertionIndexes
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
 *     NSArray *removedObjects = @[aName];
 *     NSIndexSet *removalIndexes = [NSIndexSet indexSet];
 *
 *     [self willChangeValueForProperty: key
 *                            atIndexes: removalIndexes
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
 * - (void)setNames: (id &lt;ETCollection&gt;)newNames
 * {
 *     NSArray *replacementObjects = @[aName];
 *     // If no indexes are provided, the entire collection is replaced or set.
 *     NSIndexSet *replacementIndexes = [NSIndexSet indexSet];
 *
 *     [self willChangeValueForProperty: key
 *                            atIndexes: replacementIndexes
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
 * @section Serialization and Metamodel
 *
 * At commit time, all the inner objects in a COObjectGraphContext are 
 * serialized into an intermediate COItem representation with COItemGraph 
 * protocol. 
 *
 * At serialization time, each object is turned into a COItem with 
 * -[COObject storeItem]. At deserialization, a COItem is passed to 
 * -[COObject setStoreItem:] to recreate the object state.
 *
 * All properties declared as persistent (see -[ETPropertyDescription isPersistent]) 
 * in the metamodel are serialized, transient properties are skipped. 
 * For transient properties, COObject don't manage them in any way, but just 
 * ensure their values respect the metamodel constraints (in 
 * -didChangeValueForProperty:). 
 *
 * For persistent properties, COObject supports both relationships to other 
 * inner objects, and attributes that contain primitive objects such as 
 * NSString or NSDate.
 *
 * Both attributes and relationships can be either univalued or multivalued 
 * (to-one or to-many), see -[ETPropertyDescription isMultivalued] in the 
 * metamodel.
 *
 * Relationships can be either undirectional or bidirectional (one-way or two-way). 
 * To create a bidirectional relationships, -[ETPropertyDescription opposite] 
 * must be set on one side. The other side or opposite is the inverse 
 * relationship. For a bidirectional relationship, a single side can be marked 
 * as persistent, the other side must be transient. The persistent side is 
 * known as an outgoing relationship, and the transient side as an incoming 
 * relationship. CoreObject doesn't load incoming relationships into each 
 * COObject, but load them in the relationship cache. This rule doesn't apply 
 * to transient relationships.
 *
 * With metamodel constraints, CoreObject supports several multivalued 
 * relationship variations:
 *
 * <deflist>
 * <term>Keyed Relationship</term><desc>hold in a NSDictionary 
 * – <em>-[ETPropertyDescription isKeyed] == YES in the metamodel</em></desc>
 * <term>Ordered Relationship</term><desc>hold in a NSArray 
 * – <em>-[ETPropertyDescription isOrdered] == YES in the metamodel</em></desc>
 * <term>Unordered Relationship</term><desc>hold in a NSSet 
 * – <em>-[ETPropertyDescription isOrdered] ==  NO in the metamodel</em></desc>
 * </deflist>
 *
 * <deflist>
 * <term>Unidirectional Relationship</term><desc>a one-way relationship 
 * – <em>-[ETPropertyDescription opposite] == nil in the metamodel</em></desc>
 * <term>Bidirectional Relationship</term><desc>a two-way relationship 
 * – <em>-[ETPropertyDescription opposite != nil in the metamodel</em></desc>
 * <term>Composite Relationship</term><desc>a parent/child relationship 
 * – <em>-[[ETPropertyDescription multivalued] is not the same on both side</em></desc>
 * </deflist>
 *
 * A persistent keyed relationship is undirectional, 
 * -[ETPropertyDescription opposite] must be nil.
 *
 * A composite relationsip is just a bidirectional relationship subcase, it 
 * models a tree structure inside the object graph, and in this way, a 
 * composite determines how the object graph is copied. A composite object 
 * (or child object) is copied rather than aliased when the tree structure it 
 * belongs to is copied.
 *
 * With metamodel constraints, CoreObject supports several variations over 
 * attribute collections:
 *
 * <deflist>
 * <term>Keyed Collection</term><desc>hold in a NSDictionary 
 * – <em>-[ETPropertyDescription isKeyed] == YES in the metamodel</em></desc>
 * <term>Ordered Collection</term><desc>hold in a NSArray 
 * – <em>-[ETPropertyDescription isOrdered] == YES in the metamodel</em></desc>
 * <term>Unordered Collection</term><desc>hold in a NSSet 
 * – <em>-[ETPropertyDescription isOrdered] ==  NO in the metamodel</em></desc>
 * </deflist>
 *
 * For relationships or attribute collections, both ordered and unordered, 
 * duplicates are not allowed, and if the same object is inserted twice in a 
 * collection, CoreObject will remove the previous reference to this object in 
 * the collection.
 *
 * A keyed relationship or attribute collection is unordered,  
 * -[ETPropertyDescription isOrdered] must be NO. This restriction applies to 
 * transient properties too currently.
 *
 * Note: If a collection is a relationship or an attribute collection is 
 * controlled by -[ETPropertyDescription type], and whether this entity 
 * description return YES to -[ETEntityDescription isPrimitive]. You can 
 * override -[ETEntityDescription isPrimitive] in a ETEntityDescription 
 * subclass to declare new attribute objects in the metamodel. However 
 * CoreObject will treat all COObject instances as relationships internally, 
 * since CoreObject serialized format has a fixed set of attribute types (see 
 * COType).
 * 
 *
 * @section Object Graph Loading
 *
 * When a persistent root's root object is accessed, the entire object graph 
 * bound to it is loaded (if the root object is not present in memory).
 *
 * When a persistent inner object is loaded, once the attribute values have 
 * been deserialized, -awakeFromDeserialization is sent to the object to let it 
 * update its state before being used. You can thus override 
 * -awakeFromDeserialization to recreate transient properties, recompute 
 * correct property values based on the deserialized values, etc. But you must 
 * not access or update persistent relationships in -awakeFromDeserialization 
 * directly. 
 *
 * You can override -didLoadObjectGraph to manipulate persistent relationships 
 * in a such way. Loading a persistent object usually result in the other inner 
 * objects being loaded, and -didLoadObjectGraph is sent to all the inner 
 * objects once all these objects have been loaded. 
 *
 * Although you should avoid to override -didLoadObjectGraph, in some cases it 
 * cannot be avoided. For example, an accessor can depend on or alter the state 
 * of a relationship (e.g. a parent object in a tree structure). To give a more 
 * concrete example, in EtoileUI -[ETLayoutItem setView:] uses 
 * -[ETLayoutItemGroup handleAttacheViewOfItem:] to adjust the parent view, so 
 * -[ETLayoutItem setView:] cannot be used until the parent item is loaded.
 *
 * @section Model Validation
 *
 * At commit time, all the changed objects are validated with -validate. You can 
 * override this method to implement some custom validation logic per COObject 
 * subclass. By default, the object will be validated with the model validation 
 * logic packaged with the metamodel, -validateAllValues will check each 
 * property value with the validation rules provided by 
 * -[ETPropertyDescription role] and -[ETRoleDescription validateValue:forKey:].
 *
 * Note: -validateAllValues currently doesn't check that the property values 
 * respect the constraints set on their related property descriptions. 
 * For now, CoreObject enforces these metamodel constraints in 
 * -didChangeValueForProperty:.
 */
@interface COObject : NSObject
{
@private
    ETEntityDescription *_entityDescription;
    ETUUID *_UUID;
    COObjectGraphContext *__weak _objectGraphContext;
    NSMutableDictionary *_variableStorage;
    /** 
     * Storage for incoming relationships e.g. parent(s). CoreObject doesn't
     * allow storing incoming relationships in ivars or variable storage. 
     */
    CORelationshipCache *_incomingRelationshipCache;
    /**
     * Stack of nested property names for change notifications i.e.
     * -willChangeValueForProperty: is called multiple times for the same object.
     */
    NSMutableArray *_propertyChangeStack;
    /**
     * Dictionary UUIDs by property names. Used by 
     * -[COObject storeItemFromDictionaryForPropertyDescription:] to recreate 
     * a COItem representing a keyed multivalued property using the same stable 
     * UUID accross repeated serializations.
     */
    NSMutableDictionary *_additionalStoreItemUUIDs;
    BOOL _isPrepared;
    int _skipLoading;
}


/** @taskunit Initialization */


/** <init />
 * Initializes and returns object that is owned and managed by the given object 
 * graph context.
 * 
 * During the initialization, the receiver is automatically inserted into
 * the object graph context. As a result, the receiver appears in
 * -[COObjectGraphContext insertedObjectUUIDs] on return.
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
 * [editingContext insertPersistentRootWithRootObject: graphContext.rootObject];
 * </example>
 *
 * You cannot use -init to create a COObject instance.
 *
 * For a nil context, raises an NSInvalidArgumentException.
 */
- (instancetype)initWithObjectGraphContext: (COObjectGraphContext *)aContext;
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
- (instancetype)initWithEntityDescription: (ETEntityDescription *)anEntityDesc
                       objectGraphContext: (COObjectGraphContext *)aContext;
- (instancetype)initWithEntityDescription: (ETEntityDescription *)anEntityDesc
                                     UUID: (ETUUID *)aUUID
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
@property (nonatomic, readonly, weak, nullable) COBranch *branch;
/**
 * Returns the persistent root when the receiver is persistent, otherwise 
 * returns nil.
 */
@property (nonatomic, readonly, weak, nullable) COPersistentRoot *persistentRoot;
/**
 * Returns the editing context when the receiver is persistent, otherwise
 * returns nil.
 */
@property (nonatomic, readonly, weak, nullable) COEditingContext *editingContext;
/**
 * Returns the object graph context owning the receiver.
 */
@property (nonatomic, readonly, weak) COObjectGraphContext *objectGraphContext;
/** 
 * Returns the root object when the receiver is persistent, otherwise returns nil.
 *
 * When the receiver is persistent, returns either self or the root object that 
 * encloses the receiver as an inner object.
 *
 * See also -isRoot.
 */
@property (nonatomic, readonly, nullable) __kindof COObject *rootObject;
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
 * Return the revision object corresponding to the most recent commit of the
 * branch owning the object graph context.
 *
 * See also -[COBranch currentRevision].
 */
@property (nonatomic, readonly, nullable) CORevision *revision;


/** @taskunit Basic Properties */


/**
 * The object name.
 */
@property (nonatomic, readwrite, copy, nullable) NSString *name;
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
@property (nonatomic, readonly) NSString *displayName;
/**
 * Returns the tags attached to the receiver. 
 *
 * The returned collection contains COTag objects.
 */
@property (nonatomic, readonly) NSSet<COTag *> *tags;


/** @taskunit Property-Value Coding */


/**
 * <override-never />
 * Returns the properties declared in the receiver entity description.
 *
 * See also -entityDescription and -persistentPropertyNames.
 */
@property (nonatomic, readonly) NSArray<NSString *> *propertyNames;
/**
 * <override-never />
 * Returns the persistent properties declared in the receiver entity description.
 *
 * The returned array contains the property descriptions which replies YES to 
 * -[ETPropertyDescription isPersistent].
 *
 * See also -entityDescription and -propertyNames.
 */
@property (nonatomic, readonly) NSArray<NSString *> *persistentPropertyNames;
/**
 * <override-never />
 * Returns the property value.
 *
 * When the property is not declared in the entity description, raises an 
 * NSInvalidArgumentException.
 *
 * See also -setValue:forProperty:.
 */
- (nullable id)valueForProperty: (NSString *)key;
/**
 * <override-never />
 * Sets the property value.
 *
 * When the property is not declared in the entity description, raises an 
 * NSInvalidArgumentException.
 *
 * See also -valueForProperty:.
 */
- (BOOL)setValue: (nullable id)value forProperty: (NSString *)key;


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
- (NSArray<ETValidationResult *> *)validateAllValues;
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
- (NSArray<ETValidationResult *> *)validateValue: (nullable id)value
                                     forProperty: (NSString *)key;
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
 * See also COError, -[COObjectGraphContext insertedObjectUUIDs],
 * -[COObjectGraphContext updatedObjectUUIDs] and 
 * -[COObjectGraphContext changedObjectUUIDs].
 */
- (NSArray<ETValidationResult *> *)validate;
/**
 * Calls -validateValue:forProperty: to validate the value, and returns the 
 * validation result through aValue and anError.
 *
 * This method exists to integrate CoreObject validation with existing Cocoa or 
 * GNUstep programs.<br />
 * For Etoile programs or new projects, you should use -validateValue:forProperty:.
 */
- (BOOL)validateValue: (id _Nullable *_Nonnull)aValue
               forKey: (NSString *)key
                error: (NSError **)anError;


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
- (nullable id)valueForVariableStorageKey: (NSString *)key;
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
 * triggers Key-Value Observing notifications by calling -didChangeValueForKey:.
 *
 * Can be overriden, but the superclass implementation must be called.
 */
- (void)didChangeValueForProperty: (NSString *)key;
/**
 * Tells the receiver that the value of the multivalued property (transient or 
 * persistent) is about to change.
 *
 * By default, limited to calling 
 * -willchangevalueforkey:atindexes:withObjects:mutationkind:.
 *
 * To know more about the arguments, see 
 * -willchangevalueforkey:atindexes:withObjects:mutationkind:.
 *
 * Can be overriden, but the superclass implementation must be called.
 */
- (void)willChangeValueForProperty: (NSString *)property
                         atIndexes: (NSIndexSet *)indexes
                       withObjects: (NSArray *)objects
                      mutationKind: (ETCollectionMutationKind)mutationKind;
/**
 * Tells the receiver that the value of the multivalued property (transient or 
 * persistent) has changed. 
 *
 * By default, notifies the editing context about the receiver change and 
 * triggers Key-Value Observing notifications by calling 
 * -didChangeValueForKey:atIndexes:withObjects:mutationKind:.
 *
 * To know more about the arguments, see 
 * -didChangeValueForKey:atIndexes:withObjects:mutationKind:.
 *
 * Can be overriden, but the superclass implementation must be called.
 */
- (void)didChangeValueForProperty: (NSString *)property
                        atIndexes: (NSIndexSet *)indexes
                      withObjects: (NSArray *)objects
                     mutationKind: (ETCollectionMutationKind)mutationKind;


/** @taskunit Overridable Loading and Discarding Notifications */


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
 * -willLoadObjectGraph or -awakeFromDeserialization (or adjust it to match the 
 * last deserialized state).
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
 * needed, are going to be deserialized.
 *
 * You can override this method, to discard transient state related to
 * persistent relationships. It is better to reset transient state in
 * -awakeFromDeserialization or -didLoadObjectGraph, but time to time some 
 * external transient state might have been put in another persistent object
 * (usually when a persistent relationship to it was established) or some
 * object connected to it. This external transient state needs to be discarded 
 * earlier, otherwise it can become unreachable, in case the persistent 
 * relationships to traverse are updated during the deserialization.
 *
 * An overriden implementation must make no assumptions about
 * -willLoadObjectGraph in other COObject subclasses, because 
 * -willLoadObjectGraph is sent to inner objects in a random order.
 *
 * Each inner object that will receive -awakeFromDeserialization, receives
 * -willLoadObjectGraph first.
 *
 * You must make no assumptions about -willLoadObjectGraph in other subclasses, 
 * because -willLoadObjectGraph is sent to inner objects in a random order.
 *
 * If you override this method, the superclass implementation must be called
 * first.
 *
 * For more details about which inner objects receive -willLoadObjectGraph,
 * see -didLoadObjectGraph.
 */
- (void)willLoadObjectGraph;
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
 * An overriden implementation must make no assumptions about
 * -didLoadObjectGraph in other COObject subclasses, because -didLoadObjectGraph 
 * is sent to inner objects in a random order.
 *
 * Each inner object that has received -willLoadObjectGraph and 
 * -awakeFromDeserialization, receives -didLoadObjectGraph. The root object is 
 * always the last to receive -didLoadObjectGraph (if the root object was loaded 
 * or reloaded).
 *
 * Don't forget that you shouldn't expect all inner objects to receive 
 * -willLoadObjectGraph, -awakeFromDeserialization and -didLoadObjectGraph 
 * during a loading. For a reloading, the object graph context doesn't discard 
 * the existing objects but reuse them (based on their UUID idendity).<br />
 * For an object graph copy (see COCopier), the object copies receive 
 * -willLoadObjectGraph, -awakeFromDeserialization and -didLoadObjectGraph, but 
 * all other inner objects don't.
 *
 * If you override this method, the superclass implementation must be called 
 * first.
 */
- (void)didLoadObjectGraph;
/**
 * <override-dummy />
 * For an object graph context discarding changes, tells the receiver that some 
 * inner objects including the receiver, are going to be discarded.
 *
 * You can override this method, to update transient or external state related
 * to persistent relationships, or tear down complex persistent relationships 
 * explicitly. Persistent relationships cannot be accessed in -dealloc.
 *
 * If you override this method, the superclass implementation must be called
 * last.
 *
 * See -[COObjectGraphContext discardAllChanges] and 
 * COObjectGraphContextWillRelinquishObjectsNotification.
 */
- (void)willDiscard;


/** @taskunit Object Equality */

/** 
 * Returns whether anObject saved state is equal the receiver saved state. 
 *
 * Two persistent objects are temporally equal if they share the same UUID and 
 * revision.
 *
 * See also -isEqual:.
 */
- (BOOL)isTemporallyEqual: (id)anObject;


/** @taskunit Debugging and Description */


/** 
 * Returns a description that includes the receiver properties and their values. 
 *
 * See -detailedDescriptionWithTraversalKey:, and -[NSObject descriptionWithOptions:] 
 * to implement custom detailed descriptions.
 */
@property (nonatomic, readonly) NSString *detailedDescription;
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
 *
 * Can be overriden, but must check -isZombie, and if YES, return a basic 
 * description (limited to -UUID and -entity description), or just call the 
 * superclass description that is expected to comply the present rule.
 */
@property (readonly, copy) NSString *description;
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
@property (nonatomic, readonly, nullable) NSString *revisionDescription;
/** 
 * Returns the receiver tags in a coma separated list.
 *
 * This is used to present -tags to the user in the UI.
 */
@property (nonatomic, readonly) NSString *tagDescription;
/**
 * Returns whether the receiver has been relinquished by the object graph 
 * context (during a GC phase). You might encounter this if your app holds 
 * a strong Objective-C reference to a COObject that is subsequently deleted from an
 * object graph context.
 *
 * This property is only provided for debugging, and should never be used in
 * application logic (a correctly written program will never encounter a
 * zombie object.) See COObjectGraphContextWillRelinquishObjectsNotification.
 *
 * A zombie object is an invalid inner object that must not be used, since 
 * messages that access its state can result in an exception. You are just
 * allowed to call -UUID, -entityDescription and -description on it.
 *
 * See also -objectGraphContext.
 */
@property (nonatomic, readonly) BOOL isZombie;

@end

NS_ASSUME_NONNULL_END
