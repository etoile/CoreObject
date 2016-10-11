/*
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COObject.h"
#import "COError.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COObject+RelationshipCache.h"
#import "COObject+Private.h"
#import "COCrossPersistentRootDeadRelationshipCache.h"
#import "COPrimitiveCollection.h"
#import "CORelationshipCache.h"
#import "COTag.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COPath.h"
#import "COSerialization.h"
#import "COEditingContext+Private.h"
#import "COAttachmentID.h"
#include <objc/runtime.h>

@interface NSObject ()
+ (NSString *)packageName;
@end

@interface COObject (COSerializationPrivate)
+ (void)initializeSerialization;
@end

@interface CONotFoundMarker : NSObject
@end

@implementation CONotFoundMarker
@end


@implementation COObject

@synthesize UUID = _UUID, entityDescription = _entityDescription, objectGraphContext = _objectGraphContext;

static CONotFoundMarker *notFoundMarker = nil;
static NSNull *cachedNSNull = nil;

+ (void)initialize
{
    if (self != [COObject class])
        return;

    notFoundMarker = [CONotFoundMarker new];
    cachedNSNull = [NSNull null];

    [self initializeSerialization];
}

#if (TARGET_OS_IPHONE)
/**
 * To support iOS 7, CoreObject is compiled as a static library, this means we
 * have no CoreObject bundle (the bundle containing all CoreObject classes being
 * the compiled application).
 */
+ (NSString *) packageName
{
    if ([[self className] hasPrefix: @"CO"])
    {
        return @"org.etoile-project.CoreObject";
    }
    return [super packageName];
}
#endif

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *object = [self newBasicEntityDescription];

    // For subclasses that don't override -newEntityDescription, we must not add the 
    // property descriptions that we will inherit through the parent
    if (![object.name isEqual: [COObject className]])
        return object;

    ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COObject"
                                   description: @"Core Object"
                              supertypeStrings: @[]
                                      typeTags: @{}];
    ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

    [object setLocalizedDescription: _(@"Basic Object")];

    /* Persistency Attributes (subset) */

    ETPropertyDescription *UUID =
        [ETPropertyDescription descriptionWithName: @"UUID" typeName: @"ETUUID"];
    [UUID setReadOnly: YES];
    ETPropertyDescription *isPersistent =
        [ETPropertyDescription descriptionWithName: @"isPersistent" typeName: @"BOOL"];
    isPersistent.derived = YES;
    ETPropertyDescription *isRoot =
        [ETPropertyDescription descriptionWithName: @"isRoot" typeName: @"BOOL"];
    isRoot.derived = YES;
    ETPropertyDescription *isShared =
        [ETPropertyDescription descriptionWithName: @"isShared" typeName: @"BOOL"];
    [isShared setReadOnly: YES];

    /* Basic Properties */

    ETPropertyDescription *name =
        [ETPropertyDescription descriptionWithName: @"name" typeName: @"NSString"];
    ETPropertyDescription *identifier =
        [ETPropertyDescription descriptionWithName: @"identifier" typeName: @"NSString"];
    ETPropertyDescription *tags =
        [ETPropertyDescription descriptionWithName: @"tags" typeName: @"COTag"];
    tags.multivalued = YES;
    tags.derived = YES;

    // TODO: Move these properties to EtoileFoundation (by adding a NSObject
    // entity description) or just use -basicPropertyNames in
    //-[COObject propertyNames]... See -[NSObject propertyNames] and remove
    // some properties in -basicPropertyNames (e.g. hash or superclass).

#if TARGET_OS_IPHONE
    NSString *imageType = @"UIImage";
#else
    NSString *imageType = @"NSImage";
#endif

#ifndef GNUSTEP
    // FIXME: We don't link NSImage on GNUstep because AppKit won't work
    ETPropertyDescription *icon =
        [ETPropertyDescription descriptionWithName: @"icon" typeName: imageType];
#endif
    ETPropertyDescription *displayName =
        [ETPropertyDescription descriptionWithName: @"displayName" typeName: @"NSString"];
    displayName.displayName = _(@"Name");

    /* Description Properties */

    ETPropertyDescription *revisionDescription =
        [ETPropertyDescription descriptionWithName: @"revisionDescription" typeName: @"NSString"];
    revisionDescription.displayName = _(@"Version");
    ETPropertyDescription *tagDescription =
        [ETPropertyDescription descriptionWithName: @"tagDescription" typeName: @"NSString"];
    tagDescription.displayName = _(@"Tags");
    ETPropertyDescription *typeDescription =
        [ETPropertyDescription descriptionWithName: @"typeDescription" typeName: @"NSString"];
    typeDescription.displayName = _(@"Type");

    NSArray *transientProperties = @[UUID, isPersistent, isRoot, identifier, displayName,
                                     revisionDescription, tagDescription, typeDescription, tags];
#ifndef GNUSTEP
    transientProperties = [transientProperties arrayByAddingObject: icon];
#endif
    NSArray *persistentProperties = @[isShared, name];
    NSArray *properties =
        [transientProperties arrayByAddingObjectsFromArray: persistentProperties];

    [[[properties arrayByRemovingObject: name] mappedCollection] setReadOnly: YES];
    [[persistentProperties mappedCollection] setPersistent: YES];

    object.propertyDescriptions = properties;

    return object;
}

#pragma mark - Initialization

- (Class)coreObjectCollectionClassForPropertyDescription: (ETPropertyDescription *)propDesc
{
    NSParameterAssert(propDesc.multivalued);

    if (propDesc.keyed)
    {
        // NOTE: Could be better to return nil in the assertion case, and move
        // the assertion in methods calling -collectionClassForPropertyDescription:.
        NSAssert1(!propDesc.ordered || !propDesc.persistent,
                  @"Persistent keyed collection %@ cannot be ordered.", propDesc);
        return [COMutableDictionary class];
    }
    else
    {
        if (propDesc.isPersistentRelationship)
        {
            return (propDesc.ordered ? [COUnsafeRetainedMutableArray class] : [COUnsafeRetainedMutableSet class]);
        }
        else
        {
            return (propDesc.ordered ? [COMutableArray class] : [COMutableSet class]);
        }
    }
}

- (Class)collectionClassForPropertyDescription: (ETPropertyDescription *)propDesc
{
    NSParameterAssert(propDesc.multivalued);

    if (propDesc.keyed)
    {
        // NOTE: Could be better to return nil in the assertion case, and move
        // the assertion in methods calling -collectionClassForPropertyDescription:.
        NSAssert1(!propDesc.ordered || !propDesc.persistent,
                  @"Persistent keyed collection %@ cannot be ordered.", propDesc);
        return [NSDictionary class];
    }
    else
    {
        return (propDesc.ordered ? [NSArray class] : [NSSet class]);
    }
}

- (id)newCollectionForPropertyDescription: (ETPropertyDescription *)propDesc
{
    if (propDesc.persistent)
    {
        Class collectionClass = [self coreObjectCollectionClassForPropertyDescription: propDesc];
        return [collectionClass new];
    }
    else
    {
        Class proposedClass = [self collectionClassForPropertyDescription: propDesc];
        Class collectionClass = [proposedClass mutableClass];
        return [collectionClass new];
    }
}

- (NSMutableDictionary *)newVariableStorage
{
    NSMutableDictionary *variableStorage = [[NSMutableDictionary alloc] initWithCapacity: 20];

    for (ETPropertyDescription *propDesc in self.entityDescription.allPropertyDescriptions)
    {
        if (!propDesc.multivalued || propDesc.derived)
            continue;

        id value = nil;
        const BOOL ivarExists = ETGetInstanceVariableValueForKey(self, &value, propDesc.name);

        if (ivarExists)
            continue;

        id collection = [self newCollectionForPropertyDescription: propDesc];

        variableStorage[propDesc.name] = collection;
    }

    return variableStorage;
}

- (void)validateEntityDescription: (ETEntityDescription *)anEntityDescription
     inModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    Class entityClass = [repo classForEntityDescription: anEntityDescription];

    if (![entityClass isSubclassOfClass: [self class]]
        && ![[self class] isSubclassOfClass: entityClass])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"There is mismatch between the entity description %@ and the class "
                                "%@. For this entity description, the class must be a %@ class, "
                                "subclass or superclass.",
                            anEntityDescription.fullName,
                            self.className,
                            NSStringFromClass(entityClass)];
    }

    if (![anEntityDescription isKindOfEntity: [repo descriptionForName: @"COObject"]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"The COObject class only supports entitiy descriptions that are "
                                "subentities of COObject, but %@ is not.",
                            anEntityDescription.fullName];
    }
}

- (NSArray *)keyedPersistentPropertyDescriptions
{
    NSArray *propertyDescs = _entityDescription.allPersistentPropertyDescriptions;
    NSMutableArray *keyedPropertyDescs = [NSMutableArray new];

    for (ETPropertyDescription *propertyDesc in propertyDescs)
    {
        if (propertyDesc.keyed)
        {
            [keyedPropertyDescs addObject: propertyDesc];
        }
    }

    return keyedPropertyDescs;
}

- (NSMutableDictionary *)newAdditionalStoreItemUUIDs: (BOOL)isDeserialization
{
    NSMutableDictionary *storeItemUUIDs = [NSMutableDictionary new];

    for (ETPropertyDescription *propertyDesc in [self keyedPersistentPropertyDescriptions])
    {
        storeItemUUIDs[propertyDesc.name] = (isDeserialization ? cachedNSNull : [ETUUID UUID]);
    }
    return storeItemUUIDs;
}

- (NSDictionary *)additionalStoreItemUUIDs
{
    return _additionalStoreItemUUIDs;
}

- (id)prepareWithUUID: (ETUUID *)aUUID
    entityDescription: (ETEntityDescription *)anEntityDescription
   objectGraphContext: (COObjectGraphContext *)aContext
                isNew: (BOOL)inserted
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(anEntityDescription);
    NILARG_EXCEPTION_TEST(aContext);
    INVALIDARG_EXCEPTION_TEST(aContext, [aContext isKindOfClass: [COObjectGraphContext class]]);

    [self validateEntityDescription: anEntityDescription
       inModelDescriptionRepository: aContext.modelDescriptionRepository];

    [anEntityDescription makeFrozen];

    SUPERINIT;

    _UUID = aUUID;
    _entityDescription = anEntityDescription;
    _objectGraphContext = aContext;
    _isPrepared = YES;
    _variableStorage = [self newVariableStorage];
    _incomingRelationshipCache = [[CORelationshipCache alloc] initWithOwner: self];
    _propertyChangeStack = [NSMutableArray new];
    _additionalStoreItemUUIDs = [self newAdditionalStoreItemUUIDs: !inserted];

    [_objectGraphContext registerObject: self isNew: inserted];

    return self;
}

- (instancetype)initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
    /* We execute overriden initializer implementations e.g. 
       -[ETShape initWithBezierPath:objectGraphContext:], until reaching the 
       topmost COObject designed initializer (aka -[COObject initWithGraphContext:]), 
       where we return immediately when the basic initialization is done 
       (this happens when -initWithEntityDescription:objectGraphContext: is used). */
    if (_isPrepared)
        return self;

    NILARG_EXCEPTION_TEST(aContext);

    ETModelDescriptionRepository *repo = aContext.modelDescriptionRepository;
    return [self prepareWithUUID: [ETUUID UUID]
               entityDescription: [repo entityDescriptionForClass: [self class]]
              objectGraphContext: aContext
                           isNew: YES];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (instancetype)init
{
    return [self initWithObjectGraphContext: nil];
}

#pragma clang diagnostic pop

- (instancetype)initWithEntityDescription: (ETEntityDescription *)anEntityDesc
                       objectGraphContext: (COObjectGraphContext *)aContext
{
    return [self initWithEntityDescription: anEntityDesc
                                      UUID: [ETUUID UUID]
                        objectGraphContext: aContext];
}

- (instancetype)initWithEntityDescription: (ETEntityDescription *)anEntityDesc
                                     UUID: (ETUUID *)aUUID
                       objectGraphContext: (COObjectGraphContext *)aContext
{
    self = [self prepareWithUUID: aUUID
               entityDescription: anEntityDesc
              objectGraphContext: aContext
                           isNew: YES];

    /* For subclasses that override the designated initializer */
    return [self initWithObjectGraphContext: aContext];
}

#pragma mark - Persistency Attributes

- (COBranch *)branch
{
    return _objectGraphContext.branch;
}

- (COPersistentRoot *)persistentRoot
{
    return _objectGraphContext.persistentRoot;
}

- (COEditingContext *)editingContext
{
    return _objectGraphContext.editingContext;
}

- (id)rootObject
{
    return _objectGraphContext.rootObject;
}

- (BOOL)isRoot
{
    return (self.rootObject == self);
}

- (BOOL)isShared
{
    return YES;
}

- (CORevision *)revision
{
    return _objectGraphContext.branch.currentRevision;
}

- (BOOL)isPersistent
{
    return (self.persistentRoot != nil);
}

#pragma mark - Zombie Status

- (BOOL)isZombie
{
    return _variableStorage == nil;
}

- (void)checkNotZombie
{
    if (self.isZombie)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"You are attempting to access a property's variable storage of a "
                                "COObject instance that has been detached from its COObjectGraphContext. "
                                "This should only happen due to buggy application code that hangs "
                                "on to COObject pointers after they are no longer valid."];
    }
}

- (void)makeZombie
{
    _variableStorage = nil;
}

#pragma mark - Basic Properties

- (NSString *)displayName
{
    return self.name;
}

- (NSString *)name
{
    return [self valueForVariableStorageKey: @"name"];
}

- (NSString *)identifier
{
    return self.name;
}

- (void)setName: (NSString *)aName
{
    [self willChangeValueForProperty: @"name"];
    [self setValue: aName forVariableStorageKey: @"name"];
    [self didChangeValueForProperty: @"name"];
}

- (NSSet *)tags
{
    return [self valueForVariableStorageKey: @"tags"];
}

#pragma mark - Property-Value Coding

- (NSSet *)observableKeyPaths
{
    return S(@"isPersistent", @"name", @"displayName", @"tags",
             @"revisionDescription", @"tagDescription");
}

- (NSArray *)propertyNames
{
    return self.entityDescription.allPropertyDescriptionNames;
}

- (NSArray *)persistentPropertyNames
{
    return (id)[[self.entityDescription.allPersistentPropertyDescriptions mappedCollection] name];
}

- (SEL)getterForKey: (NSString *)key useIsPrefix: (BOOL)useIsPrefix
{
    NSString *getterName = nil;

    if (useIsPrefix)
    {
        getterName = [NSString stringWithFormat: @"is%@", [key stringByCapitalizingFirstLetter]];
    }
    else
    {
        getterName = [NSString stringWithFormat: @"%@", key];
    }
    return NSSelectorFromString(getterName);
}

- (SEL)setterForKey: (NSString *)key
{
    NSString *setterName =
        [NSString stringWithFormat: @"set%@:", [key stringByCapitalizingFirstLetter]];
    return NSSelectorFromString(setterName);
}

- (void)disableLoading
{
    _skipLoading++;
}

- (void)enableLoading
{
    _skipLoading--;
    ETAssert(_skipLoading >= 0);
}

- (BOOL)isLoadingEnabled
{
    return _skipLoading == 0;
}

- (id)valueForProperty: (NSString *)key shouldLoad: (BOOL)shouldLoad
{
    if (![self.propertyNames containsObject: key])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Tried to get value for invalid property %@", key];
        return nil;
    }

    /* We call the getter directly if implemented */

    if ([self respondsToSelector: [self getterForKey: key useIsPrefix: NO]]
        || [self respondsToSelector: [self getterForKey: key useIsPrefix: YES]])
    {
        if (!shouldLoad)
        {
            [self disableLoading];
        }

        // NOTE: Don't use -performSelector:withObject: because it doesn't
        // support unboxing scalar values as Key-Value Coding does.
        id result = [self valueForKey: key];

        if (!shouldLoad)
        {
            [self enableLoading];
        }

        return result;
    }

    /* Otherwise access ivar or variable storage */

    return [self valueForStorageKey: key shouldLoad: shouldLoad];
}

- (id)valueForProperty: (NSString *)key
{
    return [self valueForProperty: key shouldLoad: YES];
}

- (BOOL)isCoreObjectValue: (id)value
{
    return ([value isKindOfClass: [COObject class]]
            || [value isKindOfClass: [COAttachmentID class]]
            || isSerializablePrimitiveValue(value)
            || isSerializableScalarValue(value)
            || value == nil);
}

- (BOOL)isEditingContextValidForObject: (COObject *)value
{
    if (value != nil && ![value isKindOfClass: [COObject class]])
    {
        // This can happen in -testNullDisallowedInCollection which leaves [NSNull null] instances
        // in a collection.
        return NO;
    }

    COEditingContext *valueEditingContext = value.persistentRoot.editingContext;
    COEditingContext *currentEditingContext = self.persistentRoot.editingContext;
    const BOOL involvesTransientObject = (valueEditingContext == nil || currentEditingContext == nil);

    return (involvesTransientObject || valueEditingContext == currentEditingContext);
}

- (BOOL)isObjectGraphContextValidForObject: (COObject *)value
                       propertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (value == nil)
        return YES;

    const BOOL isSameObjectGraphContext = (value.objectGraphContext == self.objectGraphContext);
    const BOOL isEqualPersistentRootUUID = [value.persistentRoot.UUID isEqual: self.persistentRoot.UUID];

    if (propertyDesc.isComposite || propertyDesc.isContainer)
    {
        /* Composite and container are relationship opposite in the metamodel */
        COObject *parent = (propertyDesc.isComposite ? self : value);
        COObject *child = (propertyDesc.isComposite ? value : self);
        const BOOL involvesTransientParent = (parent.persistentRoot == nil);
        const BOOL involvesTransientChild = (child.persistentRoot == nil);

        /* For a composite/container relationship, parent and child can't be 
           references accross object graph contexts (or persistent roots), 
           unless the parent object graph context is transient. */
        return isSameObjectGraphContext
               || (involvesTransientParent && !involvesTransientChild)
               || (involvesTransientParent && involvesTransientChild);
    }
    else
    {
        /* For a non-composite relationship, it is illegal to mix objects 
           between the object graphs (i.e. branches) belonging to the same 
           persistent root. In other words, references accross object graph 
           contexts must point to a different persistent root (or transient 
           object graph context). */
        return isSameObjectGraphContext || !isEqualPersistentRootUUID;
    }
}

/**
 * Counterpart to -validateEditingContextForNewValue:propertyDescription:, but it only validates
 * a single value being added to a multivalued property, rather than the whole collection.
 */
- (void)validateEditingContextForNewCollectionValue: (id)value
                                propertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (!propertyDesc.isPersistentRelationship)
        return;

    ETAssert(propertyDesc.multivalued);
    ETAssert([self isEditingContextValidForObject: value]);
}

- (void)validateEditingContextForNewValue: (id)value
                      propertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (!propertyDesc.isPersistentRelationship)
        return;

    if ([value isPrimitiveCollection])
    {
        ETAssert(propertyDesc.multivalued);

        for (COObject *object in [value objectEnumerator])
        {
            ETAssert([self isEditingContextValidForObject: object]);
        }
    }
    else
    {
        BOOL isDeadRef = [value isKindOfClass: [COPath class]];

        ETAssert(isDeadRef || [self isEditingContextValidForObject: (COObject *)value]);
    }
}

/**
 * Counterpart to -validateObjectGraphContextForNewValue:propertyDescription:, but it only validates
 * a single value being added to a multivalued property, rather than the whole collection.
 */
- (void)validateObjectGraphContextForNewCollectionValue: (id)value
                                    propertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (!propertyDesc.isPersistentRelationship)
        return;

    ETAssert(propertyDesc.multivalued);

    ETAssert([self isObjectGraphContextValidForObject: value
                                  propertyDescription: propertyDesc]);
}

- (void)validateObjectGraphContextForNewValue: (id)value
                          propertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (!propertyDesc.isPersistentRelationship)
        return;

    if ([value isPrimitiveCollection])
    {
        ETAssert(propertyDesc.multivalued);

        for (COObject *object in [value objectEnumerator])
        {
            ETAssert([self isObjectGraphContextValidForObject: object
                                          propertyDescription: propertyDesc]);
        }
    }
    else
    {
        const BOOL isDeadRef = [value isKindOfClass: [COPath class]];

        ETAssert(isDeadRef || [self isObjectGraphContextValidForObject: (COObject *)value
                                                   propertyDescription: propertyDesc]);
    }
}

- (BOOL)setValue: (id)value forProperty: (NSString *)key
{
    if (![self.propertyNames containsObject: key])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Tried to set value for invalid property %@", key];
        return NO;
    }

    /* We call the setter directly if implemented */

    if ([self respondsToSelector: [self setterForKey: key]])
    {
        // NOTE: Don't use -performSelector:withObject: because it doesn't
        // support unboxing scalar values as Key-Value Coding does.
        [self setValue: value forKey: key];
        return YES;
    }

    /* Otherwise update ivar or variable storage (relationship caches, object 
       graph context and observer objects are notified) */

    [self willChangeValueForProperty: key];
    [self setValue: value forStorageKey: key];
    [self didChangeValueForProperty: key];

    return YES;
}

+ (BOOL)automaticallyNotifiesObserversForKey: (NSString *)key
{
    ETEntityDescription *desc = [[ETModelDescriptionRepository mainRepository] entityDescriptionForClass: self];
    NSArray *propertyNames = desc.allPropertyDescriptionNames;

    if ([propertyNames containsObject: key])
    {
        return NO; // i.e., COObject's implementation notifies the KVO system for this key
    }
    return YES;
}

#pragma mark - Validation

- (NSArray *)validateAllValues
{
    NSMutableArray *results = [NSMutableArray array];

    // TODO: We might want to coalesce bidirectional relationships validation results
    for (NSString *key in self.persistentPropertyNames)
    {
        [results addObjectsFromArray: [self validateValue: [self valueForProperty: key shouldLoad: NO]
                                              forProperty: key]];
    }

    return results;
}

- (ETValidationResult *)validateValueUsingMetamodel: (id)value forProperty: (NSString *)key
{
    ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
    ETPropertyDescription *opposite = propertyDesc.opposite;
    ETValidationResult *oppositeResult = nil;

    if (opposite != nil)
    {
        NSString *oppositeKey = opposite.name;
        id oppositeValue = [value valueForProperty: oppositeKey];

        oppositeResult = [opposite validateValue: oppositeValue forKey: oppositeKey];
    }

    ETValidationResult *result = [propertyDesc validateValue: value forKey: key];
    // TODO: [result setOppositeResult: oppositeResult];

    return result;
}

- (ETValidationResult *)validateValueUsingModel: (id)value forProperty: (NSString *)property
{
    const char *key = property.UTF8String;
    const size_t keyLength = strlen(key);
    const char *prefix = "validate";
    const size_t prefixLength = strlen(prefix);
    char validator[prefixLength + keyLength + 2];

    memcpy(validator, prefix, prefixLength);
    memcpy(validator + prefixLength, key, keyLength);

    validator[prefixLength] = toupper(key[0]);
    validator[prefixLength + keyLength] = ':';
    validator[prefixLength + keyLength + 1] = '\0';
    assert(validator[prefixLength + keyLength + 1] == '\0');

    SEL keySelector = sel_getUid(validator);

    if (![self respondsToSelector: keySelector])
        return [ETValidationResult validResult: value];

    return [self performSelector: keySelector withObject: value];
}

// TODO: Would be cleaner to return an aggregate validation result
- (NSArray *)validateValue: (id)value forProperty: (NSString *)key
{
    ETValidationResult *metamodelResult =
        [self validateValueUsingMetamodel: value forProperty: key];
    ETValidationResult *modelResult =
        [self validateValueUsingModel: value forProperty: key];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity: 2];

    if (!metamodelResult.isValid)
    {
        [results addObject: metamodelResult];
    }
    if (!modelResult.isValid)
    {
        [results addObject: modelResult];
    }
    return results;
}

- (NSArray *)validate
{
    return [COError errorsWithValidationResults: [self validateAllValues]];
}

- (BOOL)validateValue: (id *)aValue forKey: (NSString *)key error: (NSError **)anError
{
    NSParameterAssert(aValue != NULL);
    NSArray *results = [self validateValue: *aValue forProperty: key];

    if (results.count == 1 && [results.firstObject isValid])
        return YES;

    *aValue = [((ETValidationResult *)results.lastObject) value];
    if (anError != NULL)
    {
        *anError = [COError errorWithValidationResults: results];
    }
    return NO;
}

#pragma mark - Direct Access to Property Storage

- (BOOL)isIncomingRelationship: (ETPropertyDescription *)propDesc
{
    if (propDesc.opposite != nil && propDesc.persistent && propDesc.opposite.persistent)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"For %@, %@ and its opposite are both declared as persistent. For a "
                                "persistent relationship, CoreObject requires a single side to be "
                                "declared as persistent.", self, propDesc];
    }

    return (!propDesc.persistent && nil != propDesc.opposite && propDesc.opposite.persistent);
}

/**
 * Can return incoming relationships, although they are not stored in the 
 * variable storage. This allows -valueForStorageKey: and -valueForProperty: to 
 * both return incoming relationships.
 */
- (id)valueForVariableStorageKey: (NSString *)key
                  notFoundMarker: (id)aNotFoundMarker
                      shouldLoad: (BOOL)shouldLoad
{
    // NOTE: This is just a debugging aid, and the check is only placed
    // here because -valueForVariableStorageKey: is a commonly called method.
    [self checkNotZombie];

    ETPropertyDescription *propDesc = [_entityDescription propertyDescriptionForName: key];

    // NOTE: In CoreObject, incoming relationships (e.g. parent(s)) are stored 
    // in an incoming relationship cache per object and not persisted, unlike
    // outgoing relationships (e.g. children).
    //
    // For the relationship cache API, parent(s) = referringObject(s) and self = target
    if ([self isIncomingRelationship: propDesc])
    {
        if (propDesc.multivalued)
        {
            return [_incomingRelationshipCache referringObjectsForPropertyInTarget: key];
        }
        return [_incomingRelationshipCache referringObjectForPropertyInTarget: key];
    }

    id value = _variableStorage[key];

    // If the value is a collection, try to load all of the cross persistent root references
    if (self.loadingEnabled && shouldLoad && [self isCoreObjectCollection: value])
    {
        [self replaceReferencesWithLoadedObjectsForKey: key collection: value];
    }

    // Convert value stored in variable storage to a form we can return to the user
    if (value == nil)
    {
        return aNotFoundMarker;
    }
    else if (value == cachedNSNull)
    {
        return nil;
    }
    else if ([value isKindOfClass: [COWeakRef class]])
    {
        return ((COWeakRef *)value)->_object;
    }
    else if ([value isKindOfClass: [COPath class]])
    {
        if (self.loadingEnabled && shouldLoad)
        {
            return [self.editingContext crossPersistentRootReferenceWithPath: value
                                                                  shouldLoad: YES];
        }
        return nil;
    }

    return value;
}

- (id)valueForVariableStorageKey: (NSString *)key
{
    return [self valueForVariableStorageKey: key notFoundMarker: nil shouldLoad: YES];
}

- (BOOL)isCoreObjectCollection: (id)aCollection
{
    return [aCollection conformsToProtocol: @protocol(COPrimitiveCollection)];
}

/**
 * The collection to be updated is either:
 *
 * - a COMutableArray/Set/Dictionary, when the property is persistent
 * - a NSMutableArray/Set/Dictionary, when the property is transient.
 *
 * Note: the returned collection class must be identical to the first collection 
 * argument.
 */
- (id)replaceContentOfCollection: (id)collection
                  withCollection: (id)content
             propertyDescription: (ETPropertyDescription *)propDesc
{
    NSParameterAssert(collection != nil);

    /* At deserialization, we receive primitive collections containing dead
       references we don't want to lost.
       Collection content setter such as -[COMutableArray setArray:] ignores all
       dead references that could exist in the collection passed in argument.

       We also return a copy in case someone later update the property with a
       COPrimitiveCollection that wasn't instantiated by the receiver (we could 
       bypass this step during the deserialization as an optimization). */
    if ([self isCoreObjectCollection: content])
    {
        /* This is unreachable because the calling code checks
           ![self isCoreObjectCollection: content] before calling this method. */
        ETAssertUnreachable();
        return [content copy];
    }

    if ([self isCoreObjectCollection: collection])
    {
        [collection beginMutation];
    }

    if (propDesc.keyed)
    {
        [(NSMutableDictionary *)collection setDictionary: content];
    }
    else if (propDesc.ordered)
    {
        // FIXME: Remove this copy hack to ensure KVO doesn't report a old value
        // identical to the new one.

        // NOTE: This mess is because -copy on a COPrimitiveCollection preserves
        // the number of -beginMutation calls, and we want the copy
        // to go back to being immutable once we are finished modifying it.
        if ([self isCoreObjectCollection: collection])
        {
            collection = [collection copy];
        }
        else
        {
            collection = [collection mutableCopy];
        }
        [(NSMutableArray *)collection setArray: content];
    }
    else
    {
        [(NSMutableSet *)collection setSet: content];
    }

    if ([self isCoreObjectCollection: collection])
    {
        [collection endMutation];
    }

    return collection;
}

/**
 * Avoiding copies for core object primitive collections (e.g. 
 * COMutableDictionary) is a special optimization to prevent allocating new 
 * persistent relationship collections during 
 * -replaceReferencesToObjectIdenticalTo:withObject: (not sure we really need it).
 */
- (void)setValue: (id)aValue forVariableStorageKey: (NSString *)key
{
    // TODO: Raise an exception on an attempt to set an outgoing relationship
    // (or may be in -setValue:forStorageKey:).
    ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
    id storageValue;

    // Convert user value to the form we store it in the variable storage

    if (aValue == nil)
    {
        storageValue = cachedNSNull;
    }
    else if ([aValue isKindOfClass: [COObject class]])
    {
        storageValue = [[COWeakRef alloc] initWithObject: aValue];
    }
    else if (propertyDesc.multivalued && ![self isCoreObjectCollection: aValue])
    {
        storageValue = _variableStorage[key];
        storageValue = [self replaceContentOfCollection: storageValue
                                         withCollection: aValue
                                    propertyDescription: propertyDesc];
    }
    else
    {
        // TODO: In debugging mode, we could check the class of the value
        // is permitted
        // TODO: Once EtoileUI is migrated to serialization transformers,
        // replace [self isCoreObjectValue: aValue] by propertyDesc.persistent
        // (Also, remember it will affect COSerialization's value transformer support,
        // since if a value transformer is in use you can have random NSObjects in the
        // variable storage --Eric)
        storageValue = ([self isCoreObjectValue: aValue] ? [aValue copy] : aValue);
    }

    _variableStorage[key] = storageValue;
}

- (id)valueForUndefinedKey: (NSString *)key
{
    return [self valueForVariableStorageKey: key];
}

- (void)setValue: (id)value forUndefinedKey: (NSString *)key
{
    [self willChangeValueForProperty: key];
    [self setValue: value forVariableStorageKey: key];
    [self didChangeValueForProperty: key];
}

- (id)valueForStorageKey: (NSString *)key shouldLoad: (BOOL)shouldLoad
{
    id value = [self valueForVariableStorageKey: key
                                 notFoundMarker: notFoundMarker
                                     shouldLoad: shouldLoad];

    if (value == notFoundMarker)
    {
        ETGetInstanceVariableValueForKey(self, &value, key);
    }
    return (value == notFoundMarker ? nil : value);
}

- (id)valueForStorageKey: (NSString *)key
{
    return [self valueForStorageKey: key shouldLoad: YES];
}

- (id)serializableValueForStorageKey: (NSString *)key
{
    // NOTE: This is just a debugging aid, and the check is only placed
    // here because -valueForVariableStorageKey: is a commonly called method.
    [self checkNotZombie];

    id value = _variableStorage[key];

    // Convert value stored in variable storage to a form we can return to the user
    if (value == nil)
    {
        ETGetInstanceVariableValueForKey(self, &value, key);
    }
    else if (value == cachedNSNull)
    {
        return nil;
    }
    else if ([value isKindOfClass: [COWeakRef class]])
    {
        return ((COWeakRef *)value)->_object;
    }

    return value;
}

- (void)setValue: (id)value forStorageKey: (NSString *)key
{
    if (!ETSetInstanceVariableValueForKey(self, value, key))
    {
        [self setValue: value forVariableStorageKey: key];
    }

}

#pragma mark - Notifications to be called by Accessors

- (void)pushProperty: (NSString *)key
{
    [_propertyChangeStack addObject: key];
}

/**
 * Slow path
 */
- (void)commonWillChangeValueForProperty: (NSString *)key
{
    ETPropertyDescription *propertyDesc =
        [_entityDescription propertyDescriptionForName: key];
    id oldValue = [self serializableValueForStorageKey: key];

    [self pushProperty: key];
    if ([self isCoreObjectCollection: oldValue])
    {
        [(id <COPrimitiveCollection>)oldValue beginMutation];
    }

    // Used to be done in -commonDidChangeValueForProperty: when we kept a snapshot
    // of the old collection during an update.

    // Clears cached relationships for all children in the relationship.
    // They will be recreated for the new children in -commonDidChangeValueForProperty:
    [self removeCachedOutgoingRelationshipsForValue: oldValue
                          ofPropertyWithDescription: propertyDesc];
}

/**
 * Fast path version of -commonWillChangeValueForProperty: where objects 
 * represent the inserted, removed or replacement objects.
 *
 * For an array and ETCollectionMutationKindReplacement, replaced objects can be
 * computed based the replacement objects.
 *
 * For a set, ETCollectionKindReplacement represents both [NSMutableSet intersectSet:] 
 * and [NSMutableSet setSet:]. The objects argument represents all the elements
 * in the final set. For a set intersection, we consider the entire set is replaced.
 *
 * For a dictionary, the objects argument represent the values and
 * ETCollectionKindReplacement represent [NSMutableDictionary setObject(s):forKey(s):].
 * For a replacement operation, we have no way to determine the replaced objects, 
 * this would requires to receive the keys rather than the values, so we consider 
 * the entire dictionary is replaced.
 * ETCollectionKindInsertion is a valid dictionary operation, but is never used 
 * in practice when writing will/DidChangeValueForProperty:.
 */
- (void)commonWillChangeValueForProperty: (NSString *)key
                               atIndexes: (NSIndexSet *)indexes
                             withObjects: (NSArray *)objects
                            mutationKind: (ETCollectionMutationKind)mutationKind
{
    ETPropertyDescription *propertyDesc =
        [_entityDescription propertyDescriptionForName: key];
    id oldValue = [self serializableValueForStorageKey: key];

    [self pushProperty: key];
    if ([self isCoreObjectCollection: oldValue])
    {
        [(id <COPrimitiveCollection>)oldValue beginMutation];
    }

    NSArray *replacedOrRemoved;
    if (mutationKind == ETCollectionMutationKindInsertion)
    {
        replacedOrRemoved = @[];
    }
    else if (mutationKind == ETCollectionMutationKindRemoval)
    {
        replacedOrRemoved = objects;
    }
    else if (mutationKind == ETCollectionMutationKindReplacement)
    {
        if ([oldValue isOrdered])
        {
            replacedOrRemoved = [oldValue objectsAtIndexes: indexes];
        }
        else if ([oldValue isKeyed])
        {
            replacedOrRemoved = [oldValue allValues];
        }
        else
        {
            // For an unordered collection, we consider all the objects have
            // been replaced/removed in a way similar to -[NSMutableSet setSet:].
            replacedOrRemoved = oldValue;
        }
    }
    else
    {
        ETAssert(NO);
    }

    // Do the various validations / updates for the removed objects.
    for (id oldCollectionMember in replacedOrRemoved)
    {
        [self removeCachedOutgoingRelationshipsForCollectionValue: oldCollectionMember
                                        ofPropertyWithDescription: propertyDesc];
    }
}

- (void)willChangeValueForProperty: (NSString *)key
{
    // Use the slow path
    [self commonWillChangeValueForProperty: key];
    [super willChangeValueForKey: key];
}

- (void)willChangeValueForProperty: (NSString *)property
                         atIndexes: (NSIndexSet *)indexes
                       withObjects: (NSArray *)objects
                      mutationKind: (ETCollectionMutationKind)mutationKind
{
    // Use the fast path
    [self commonWillChangeValueForProperty: property
                                 atIndexes: indexes
                               withObjects: objects
                              mutationKind: mutationKind];
    [self willChangeValueForKey: property
                      atIndexes: indexes
                    withObjects: objects
                   mutationKind: mutationKind];
}

- (void)didChangeValueForProperty: (NSString *)property
                        atIndexes: (NSIndexSet *)indexes
                      withObjects: (NSArray *)objects
                     mutationKind: (ETCollectionMutationKind)mutationKind
{
    [self commonDidChangeValueForProperty: property
                                atIndexes: indexes
                              withObjects: objects
                             mutationKind: mutationKind];
    [self didChangeValueForKey: property
                     atIndexes: indexes
                   withObjects: objects
                  mutationKind: mutationKind];
}

static inline BOOL isValidDeadReferenceForPropertyDescription(id value,
    ETPropertyDescription *propertyDesc)
{
    return [value isKindOfClass: [COPath class]]
           && !propertyDesc.multivalued
           && propertyDesc.isPersistentRelationship;
}

ETEntityDescription *entityDescriptionForObjectInRepository(id anObject,
    ETModelDescriptionRepository *repo)
{
    if ([anObject isKindOfClass: [COObject class]])
    {
        // special case to support the case when we're using COObject class
        // and not a user-supplied subclass
        return ((COObject *)anObject)->_entityDescription;
    }
    else
    {
        return [repo entityDescriptionForClass: [anObject class]];
    }
}

static void validateSingleValueConformsToPropertyDescriptionInRepository(id singleValue,
    ETPropertyDescription *propertyDesc, ETModelDescriptionRepository *repo)
{
    // TODO: We should move this nil check inside -isValidValue:type:
    // nil is an allowed value for all CoreObject univalued property types
    if (singleValue == nil)
        return;

    ETEntityDescription *newValueEntityDesc = entityDescriptionForObjectInRepository(singleValue,
                                                                                     repo);
    assert(newValueEntityDesc != nil);

    const BOOL isValidValue = [propertyDesc.type isValidValue: singleValue
                                                         type: newValueEntityDesc];

    if (isValidValue || isValidDeadReferenceForPropertyDescription(singleValue, propertyDesc))
        return;

    [NSException raise: NSInvalidArgumentException
                format: @"single value '%@' (entity %@) does not conform to type %@ (property %@)",
                        singleValue, newValueEntityDesc, propertyDesc.type, propertyDesc];
}

/**
 * Counterpart to -validateTypeForNewValue:propertyDescription:, but it only validates
 * a single value being added to a multivalued property, rather than the whole collection.
 */
- (void)validateTypeForNewCollectionValue: (id)value
                      propertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (!propertyDesc.persistent)
        return;

    if ([self serializationGetterForProperty: propertyDesc.name] != NULL)
        return;

    ETAssert(propertyDesc.multivalued);

    ETModelDescriptionRepository *repo = _objectGraphContext.modelDescriptionRepository;

    validateSingleValueConformsToPropertyDescriptionInRepository(value, propertyDesc, repo);
}

/**
 * Counterpart to -validateNewValue:propertyDescription:, but it only takes
 * a single value being added to a multivalued property.
 */
- (void)validateNewCollectionValue: (id)newValue
               propertyDescription: (ETPropertyDescription *)propertyDesc
{
    [self validateEditingContextForNewCollectionValue: newValue
                                  propertyDescription: propertyDesc];
    [self validateObjectGraphContextForNewCollectionValue: newValue
                                      propertyDescription: propertyDesc];
    [self validateTypeForNewCollectionValue: newValue
                        propertyDescription: propertyDesc];
}

- (void)validateNewValue: (id)newValue
     propertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (!propertyDesc.isPersistent)
        return;

    ETModelDescriptionRepository *repo = _objectGraphContext.modelDescriptionRepository;
    const BOOL isPersistentRelationship = propertyDesc.isPersistentRelationship;
    const BOOL isValidatableType = ([self serializationGetterForProperty: propertyDesc.name] == NULL);

    if (!isValidatableType)
        return;

    if (propertyDesc.multivalued)
    {
        // We count on -objectEnumerator to detect when newValue isn't a collection
        for (COObject *object in [newValue objectEnumerator])
        {
            ETAssert([newValue isKindOfClass: [self collectionClassForPropertyDescription: propertyDesc]]);

            if (isPersistentRelationship)
            {
                ETAssert([self isEditingContextValidForObject: object]);
                ETAssert([self isObjectGraphContextValidForObject: object
                                              propertyDescription: propertyDesc]);
            }
            validateSingleValueConformsToPropertyDescriptionInRepository(object, propertyDesc, repo);
        }
    }
    else
    {
        if (isPersistentRelationship)
        {
            const BOOL isDeadRef = [newValue isKindOfClass: [COPath class]];

            ETAssert(isDeadRef || [self isEditingContextValidForObject: (COObject *)newValue]);
            ETAssert(isDeadRef || [self isObjectGraphContextValidForObject: (COObject *)newValue
                                                       propertyDescription: propertyDesc]);
        }

        validateSingleValueConformsToPropertyDescriptionInRepository(newValue, propertyDesc, repo);
    }
}

/**
 * If the given property description is an ordered multivalued relationship to 
 * COObjects (either composite or not), scans for duplicates in the given collection.
 *
 * If there are duplicates, removes them and saves the modified value
 * using -setValue:forStorageKey:, and returns YES. Which values are kept and 
 * which are not is undefined.
 *
 * Otherwise returns NO.
 */
- (BOOL)removeDuplicatesInValue: (id)value
            propertyDescription: (ETPropertyDescription *)propertyDesc
{
    NSString *key = propertyDesc.name;

    if (!propertyDesc.isPersistentRelationship)
        return NO;

    if (!propertyDesc.multivalued)
        return NO;

    if (!propertyDesc.ordered)
        return NO;

    BOOL hasDuplicates = NO;
    NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity: [value count]];

    for (COObject *object in value)
    {
        if ([set containsObject: object])
        {
            hasDuplicates = YES;
            break;
        }
        [set addObject: object];
    }

    if (!hasDuplicates)
        return NO;

    [set removeAllObjects];
    NSMutableArray *collectionWithDuplicatesRemoved = [[NSMutableArray alloc] initWithCapacity: [value count]];

    for (COObject *object in value)
    {
        if (![set containsObject: object])
        {
            [collectionWithDuplicatesRemoved addObject: object];
        }
        [set addObject: object];
    }

    [self setValue: collectionWithDuplicatesRemoved forStorageKey: key];

    return YES;
}

/**
 * Copy of -updateCompositeRelationshipForPropertyDescription: that only handles
 * a single object being added to a multivalued property
 */
- (void)updateCompositeRelationshipForNewCollectionValue: (COObject *)child
                                     propertyDescription: (ETPropertyDescription *)propertyDesc
{
    ETAssert(propertyDesc.multivalued);

    if (!propertyDesc.isComposite)
        return;

    NSString *key = propertyDesc.name;
    ETPropertyDescription *parentDesc = propertyDesc.opposite;

    /* From the child viewpoint (the child as target), the parent is a referring object */
    COObject *oldParent = [child.incomingRelationshipCache
        referringObjectForPropertyInTarget: parentDesc.name];

    if (oldParent == nil || oldParent == self)
        return;

    /* Post a KVO notification */
    [oldParent removeObjects: @[child]
                   atIndexes: [NSIndexSet indexSet]
                       hints: @[]
                 forProperty: key];
}

/**
 * Removes objects from their old parents (the new parent is the receiver).
 *
 * From a metamodel viewpoint, composite = children (incoming relationship) and
 * container = parent (outgoing relationship).
 *
 * When moving objects into a composite relationship, if they are already 
 * children in another composite relationship, we must remove them from the 
 * previous composite relationship, since objects are limited to a single 
 * parent in such a relationship.
 *
 * If the relationship is a composite (the children are the property value),
 * and a child parent doesn't match the receiver, we remove the child from
 * the children collection owned by its parent.
 *
 * For the inverse relationship (the parent property for each child), we have 
 * nothing to do. COObject manages incoming relationships on our behalf.
 */
- (void)updateCompositeRelationshipForPropertyDescription: (ETPropertyDescription *)propertyDesc
{
    if (!propertyDesc.isComposite)
        return;

    NSString *key = propertyDesc.name;
    ETPropertyDescription *parentDesc = propertyDesc.opposite;
    id value = [self valueForStorageKey: key];

    if (value == nil)
        return;

    /* For parent-to-children relationship, just handle to-one or to-many in the same way  */
    id <ETCollection> children =
        (propertyDesc.multivalued ? value : @[value]);

    for (COObject *child in children)
    {
        /* From the child viewpoint (the child as target), the parent is a referring object */
        COObject *oldParent = [child.incomingRelationshipCache
            referringObjectForPropertyInTarget: parentDesc.name];

        // FIXME: Minor flaw, you can insert a composite twice if the collection is ordered.
        // e.g.
        // (a, b, c) => (a, b, c, a) since we only remove the objects from their
        // old parents if the parent is different than the object we're inserting into

        if (oldParent == nil || oldParent == self)
            continue;

        if (propertyDesc.multivalued)
        {
            /* Post a KVO notification */
            [oldParent removeObjects: @[child]
                           atIndexes: [NSIndexSet indexSet]
                               hints: @[]
                         forProperty: key];
        }
        else
        {
            id oldParentChild = [oldParent valueForStorageKey: key];
            ETAssert(oldParentChild == child);

            [oldParent setValue: nil forStorageKey: key];
        }
    }
}

- (void)popProperty: (NSString *)key
{
    NSString *top = _propertyChangeStack.lastObject;

    if (![top isEqual: key])
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"-willChangeValueForProperty: and -didChangeValueForProperty: must be "
                                "paired in setters. Either -willChangeValueForProperty: was not "
                                "called for %@ or -didChangeValueForProperty: was not called for %@.",
                            key, top];
    }

    [_propertyChangeStack removeLastObject];
}

- (void)commonDidChangeValueForProperty: (NSString *)key
{
    ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
    id newValue = [self serializableValueForStorageKey: key];
    [self popProperty: key];

    if (propertyDesc == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Property %@ is not declared in the metamodel %@ for %@",
                            key, _entityDescription, self];
    }

    if ([self isCoreObjectCollection: newValue])
    {
        [(id <COPrimitiveCollection>)newValue endMutation];
    }
    else
    {
        // COPrimitiveCollection handles duplicate removal itself
        if ([self removeDuplicatesInValue: newValue propertyDescription: propertyDesc])
        {
            // the -removeDuplicatesInValue:propertyDescription: method removed some
            // duplicates and saved the resulting de-duplicated collection in the storage
            // again. Reload the new value.
            newValue = [self valueForStorageKey: key];
        }
    }

    [self validateNewValue: newValue propertyDescription: propertyDesc];
    [self updateCompositeRelationshipForPropertyDescription: propertyDesc];
    [self addCachedOutgoingRelationshipsForValue: newValue
                       ofPropertyWithDescription: propertyDesc];

    [_objectGraphContext markObjectAsUpdated: self
                                 forProperty: key];
}

/**
 * Fast path variant of -commonDidChangeValueForProperty: that only checks
 * the inserted/removed values
 */
- (void)commonDidChangeValueForProperty: (NSString *)key
                              atIndexes: (NSIndexSet *)indexes
                            withObjects: (NSArray *)objects
                           mutationKind: (ETCollectionMutationKind)mutationKind
{
    ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
    id newValue = [self serializableValueForStorageKey: key];

    if (propertyDesc == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Property %@ is not declared in the metamodel %@ for %@",
                            key, _entityDescription, self];
    }

    if (![self isCoreObjectCollection: newValue])
    {
        // Call the slow path.

        // We rely on COUnsafeRetainedMutableArray automatic removal of duplicates,
        // otherwise we could use the fast path for non-COPrimitiveCollection multivalues.

        [self commonDidChangeValueForProperty: key];
        return;
    }

    // Fast path:

    [self popProperty: key];
    [(id <COPrimitiveCollection>)newValue endMutation];

    // We must figure out which objects were added, and which were replaced or removed

    NSArray *addedObjects;

    if (mutationKind == ETCollectionMutationKindInsertion)
    {
        addedObjects = objects;
    }
    else if (mutationKind == ETCollectionMutationKindRemoval)
    {
        addedObjects = @[];
    }
    else if (mutationKind == ETCollectionMutationKindReplacement)
    {
        addedObjects = objects;
    }
    else
    {
        ETAssert(NO);
    }

    // Do the various validations / updates for the added objects.

    for (id newValue in addedObjects)
    {
        [self validateNewCollectionValue: newValue
                     propertyDescription: propertyDesc];
        // Remove inserted objects from their old parents, if needed
        [self updateCompositeRelationshipForNewCollectionValue: newValue
                                           propertyDescription: propertyDesc];
        [self addCachedOutgoingRelationshipsForCollectionValue: newValue
                                     ofPropertyWithDescription: propertyDesc];
    }

    [_objectGraphContext markObjectAsUpdated: self
                                 forProperty: key];
}

- (void)didChangeValueForProperty: (NSString *)key
{
    [self commonDidChangeValueForProperty: key];
    [super didChangeValueForKey: key];
}

#pragma mark - Collection Mutation with Integrity Check

- (id)collectionForProperty: (NSString *)key mutationIndexes: (NSIndexSet *)indexes
{
    ETPropertyDescription *desc = [self.entityDescription propertyDescriptionForName: key];
    id collection = [self valueForStorageKey: key];
    Class expectedCollectionClass = [[self collectionClassForPropertyDescription: desc] mutableClass];

    if (!([collection isKindOfClass: expectedCollectionClass]))
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Multivalued property %@ not set up properly in %@. The collection "
                                "class %@ doesn't match the property description which was "
                                "requiring %@.", desc, self, [collection class], expectedCollectionClass];
    }

    if ([indexes isEmpty])
    {
        if (!desc.multivalued)
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"Attempt to call insertion or mutation methods for %@ which is "
                                    "not a multivalued property of %@", key, self];
        }
    }
    else
    {
        if (!(desc.multivalued && desc.ordered))
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"Attempt to call index-based insertion and removal methods for %@ "
                                    "which is not an ordered multivalued property of %@", key, self];
        }
    }

    return collection;
}

- (void)insertObjects: (NSArray *)objects
            atIndexes: (NSIndexSet *)indexes
                hints: (NSArray *)hints
          forProperty: (NSString *)key
{
    id collection = [self collectionForProperty: key mutationIndexes: indexes];

    [self willChangeValueForProperty: key
                           atIndexes: indexes
                         withObjects: objects
                        mutationKind: ETCollectionMutationKindInsertion];

    [collection insertObjects: objects atIndexes: indexes hints: hints];

    [self didChangeValueForProperty: key
                          atIndexes: indexes
                        withObjects: objects
                       mutationKind: ETCollectionMutationKindInsertion];
}

- (void)removeObjects: (NSArray *)objects
            atIndexes: (NSIndexSet *)indexes
                hints: (NSArray *)hints
          forProperty: (NSString *)key
{
    id collection = [self collectionForProperty: key mutationIndexes: indexes];

    [self willChangeValueForProperty: key
                           atIndexes: indexes
                         withObjects: objects
                        mutationKind: ETCollectionMutationKindRemoval];

    [collection removeObjects: objects atIndexes: indexes hints: hints];

    [self didChangeValueForProperty: key
                          atIndexes: indexes
                        withObjects: objects
                       mutationKind: ETCollectionMutationKindRemoval];
}

- (void)validateMultivaluedPropertiesUsingMetamodel
{
    for (ETPropertyDescription *propDesc in self.entityDescription.allPropertyDescriptions)
    {
        /* At validation time, derived properties should return a valid collection */
        if (!propDesc.multivalued)
            continue;

        Class class = [self collectionClassForPropertyDescription: propDesc];
        /* For performance reasons, we use -valueForVariableStorageKey: and
           -valueForKey: rather than just -valueForProperty: */
        id collection = [self valueForVariableStorageKey: propDesc.name
                                          notFoundMarker: nil
                                              shouldLoad: NO];

        if (collection == nil)
        {
            // NOTE: For ivar-backed and derived properties
            collection = [self valueForKey: propDesc.name];
        }

        if (![collection isKindOfClass: class])
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Property %@ of %@ is declared as a collection in the metamodel "
                                    "but the value class is %@ and doesn't match the requirements.",
                                propDesc.name, self, [collection class]];
        }
    }
}

#pragma mark - Overridable Loading Notifications

- (void)awakeFromDeserialization
{
    ETAssert(![[_additionalStoreItemUUIDs allValues] containsObject: cachedNSNull]);
}

- (void)willLoadObjectGraph
{

}

- (void)didLoadObjectGraph
{
    // NOTE: This must be called once all properties have been recreated including
    // transient ones. Since -awakeFromDeserialization superclass implementation
    // must be called first, calling it in -awakeFromDeserialization would be too early.
    [self validateMultivaluedPropertiesUsingMetamodel];
}

- (void)willDiscard
{
    [self removeCachedOutgoingRelationships];

    // If there are any pointers in other object graph contexts to self, replace them
    // with [COPath brokenPath]. This shouldn't normally happen, but does when deallocating
    // one COObjectGraphContext but not another that has pointers to the first.
    for (COCachedRelationship *cacheEntry in [_incomingRelationshipCache.allEntries copy])
    {
        if (cacheEntry.sourceObject.objectGraphContext != self.objectGraphContext)
        {
            [cacheEntry.sourceObject.objectGraphContext replaceObject: self
                                                           withObject: (id)[COPath brokenPath]];
        }
    }

    /* For dead outgoing univalued relationship, the property value is nil and 
       not a COPath, so -removeCachedOutgoingRelationships does nothing, and 
       we have to remove the receiver manually.
       If we don't do that the next time the cross persistent root references 
       are updated, -[COObjectGraphContext replaceObject:withObject:] might 
       retrieve this zombie object as a referring object from the dead 
       relationship cache and attempt to update it. */
    COCrossPersistentRootDeadRelationshipCache *deadRelationshipCache =
        self.editingContext.deadRelationshipCache;

    ETAssert(!self.isPersistent || deadRelationshipCache != nil);
    [deadRelationshipCache removeReferringObject: self];
}

#pragma mark - Equality

- (BOOL)isTemporallyEqual: (id)anObject
{
    if (anObject == self)
    {
        return YES;
    }
    if (![anObject isKindOfClass: [COObject class]])
    {
        return NO;
    }
    if ([[anObject UUID] isEqual: _UUID] && [[anObject revision] isEqual: self.revision])
    {
        return YES;
    }
    return NO;
}

#pragma mark - Description

- (NSString *)detailedDescriptionWithTraversalKey: (NSString *)aProperty
{
    NSMutableDictionary *options =
        [@{kETDescriptionOptionValuesForKeyPaths: self.propertyNames,
           kETDescriptionOptionPropertyIndent: @"\t"} mutableCopy];

    if (aProperty != nil)
    {
        options[kETDescriptionOptionTraversalKey] = aProperty;
    }

    return [self descriptionWithOptions: options];
}

- (NSString *)detailedDescription
{
    return [self detailedDescriptionWithTraversalKey: nil];
}

- (NSString *)description
{
    NSString *name = self.isZombie ? @"<zombie object>" : self.name;

    return [NSString stringWithFormat: @"<%@(%@) '%@' %p - %@>", NSStringFromClass([self class]),
                                       self.entityDescription.name, name, self, _UUID];
}

- (NSString *)typeDescription
{
    return self.entityDescription.localizedDescription;
}

- (NSString *)revisionDescription
{
    return [self.revision.UUID stringValue];
}

- (NSString *)tagDescription
{
    return [(NSArray *)[[self.tags.allObjects mappedCollection] tagString]
        componentsJoinedByString: @", "];
}

#pragma mark - Cached Relationships

- (CORelationshipCache *)incomingRelationshipCache
{
    return _incomingRelationshipCache;
}

- (NSSet *)referringObjects
{
    return _incomingRelationshipCache.referringObjects;
}

#pragma mark - Cross Persistent Root References

/**
 * The -[COObjectGraphContext insertOrUpdateItems:] API may face a situation
 * where it needs to replace a COObject instance with another one of a different
 * subclass.
 *
 * e.g. a root object of a fault / a broken reference is loaded as a COObject.
 * but later, the actual persistent root is loaded and the root object turns
 * out to be SubclassFoo. 
 *
 * In this situation, COObjectGraphContext will turn the old object into a zombie,
 * allocate a replacement, find all objects with references to the old object
 * using the relationship cache, and use this method on each of those to fix 
 * up the references to point to the replacement.
 */
- (void)replaceReferencesToObjectIdenticalTo: (COObject *)anObject
                                  withObject: (COObject *)aReplacement
{
    ETAssert(!(anObject == nil && aReplacement == nil));
    id object = anObject;
    id replacement = aReplacement;
    const BOOL isUndeletion = (anObject == nil);
    const BOOL isDeletion = (aReplacement == nil);

    if (isDeletion)
    {
        if (anObject.objectGraphContext.trackingSpecificBranch)
        {
            replacement = [COPath pathWithPersistentRoot: anObject.persistentRoot.UUID
                                                  branch: anObject.branch.UUID];
        }
        else
        {
            replacement = [COPath pathWithPersistentRoot: anObject.persistentRoot.UUID];
        }
    }
    else if (isUndeletion)
    {
        if (aReplacement.objectGraphContext.trackingSpecificBranch)
        {
            object = [COPath pathWithPersistentRoot: aReplacement.persistentRoot.UUID
                                             branch: aReplacement.branch.UUID];
        }
        else
        {
            object = [COPath pathWithPersistentRoot: aReplacement.persistentRoot.UUID];
        }
    }

    for (NSString *key in self.persistentPropertyNames)
    {
        id value = [self serializableValueForStorageKey: key];
        BOOL updated = NO;

        if ([value isKindOfClass: [COMutableArray class]])
        {
            COMutableArray *array = value;
            const NSUInteger count = array.backing.count;

            [array beginMutation];
            for (NSUInteger i = 0; i < count; i++)
            {
                if ([[array referenceAtIndex: i] isEqual: object])
                {
                    if (!updated)
                    {
                        [self willChangeValueForProperty: key];
                        updated = YES;
                    }
                    [array replaceReferenceAtIndex: i withReference: replacement];
                    // Make sure it wasn't wrongly rejected as a duplicate, etc.
                    ETAssert([array referenceAtIndex: i] == replacement);
                }
            }
            [array endMutation];
        }
        else if ([value isKindOfClass: [COMutableSet class]])
        {
            COMutableSet *set = value;

            [set beginMutation];
            if ([set containsReference: object])
            {
                if (!updated)
                {
                    [self willChangeValueForProperty: key];
                    updated = YES;
                }
                [set removeReference: object];
                [set addReference: replacement];
                ETAssert([set containsReference: replacement]);
            }
            [set endMutation];
        }
        else if ([value isEqual: object])
        {
            // TODO: Will require some changes in -valueFor(Variable)StorageKey:
            // to return nil when a dead reference marker is inserted.
            // FIXME: We should call -setValue:forStorageKey here.
            [self willChangeValueForProperty: key];
            [self setValue: replacement forVariableStorageKey: key];
            // TODO: Would be nice to have an assertion here
            //ETAssert([self valueForVariableStorageKey: key] == replacement);
            updated = YES;
        }

        if (updated)
        {
            // Will update the dead relationship cache
            [self didChangeValueForProperty: key];
        }

        // FIXME: COMutableDictionary
    }
}

/**
 * Used for lazy loading.
 * TODO: Combine with -replaceReferencesToObjectIdenticalTo: ?
 */
- (void)replaceReferencesWithLoadedObjectsForKey: (NSString *)key
                                      collection: (id)value
{
    BOOL updated = NO;

    self.objectGraphContext.ignoresChangeTrackingNotifications = YES;

    if ([value isKindOfClass: [COMutableArray class]])
    {
        COMutableArray *array = value;

        if (array.count == array.backing.count)
        {
            // All references are unfaulted
            self.objectGraphContext.ignoresChangeTrackingNotifications = NO;
            return;
        }

        [array beginMutation];
        const NSUInteger count = array.backing.count;
        for (NSUInteger i = 0; i < count; i++)
        {
            id pathOrCOObject = [array referenceAtIndex: i];

            if ([pathOrCOObject isKindOfClass: [COPath class]])
            {
                COObject *target = [self.editingContext crossPersistentRootReferenceWithPath: pathOrCOObject
                                                                                  shouldLoad: YES];
                if (target != nil)
                {
                    if (!updated)
                    {
                        [self willChangeValueForProperty: key];
                        updated = YES;
                    }
                    [array replaceReferenceAtIndex: i withReference: target];
                    // Make sure it wasn't wrongly rejected as a duplicate, etc.
                    ETAssert([array referenceAtIndex: i] == target);
                }
            }
        }
        [array endMutation];
    }
    else if ([value isKindOfClass: [COMutableSet class]])
    {
        COMutableSet *set = value;

        if (set.deadReferencesArray.count == 0)
        {
            self.objectGraphContext.ignoresChangeTrackingNotifications = NO;
            return;
        }

        [set beginMutation];
        for (COPath *ref in set.deadReferencesArray)
        {
            COObject *target = [self.editingContext crossPersistentRootReferenceWithPath: ref
                                                                              shouldLoad: YES];
            if (target != nil)
            {
                if (!updated)
                {
                    [self willChangeValueForProperty: key];
                    updated = YES;
                }
                [set removeReference: ref];
                [set addReference: target];
                ETAssert([set containsReference: target]);
            }
        }
        [set endMutation];
    }

    if (updated)
    {
        // Will update the dead relationship cache
        [self didChangeValueForProperty: key];
    }

    self.objectGraphContext.ignoresChangeTrackingNotifications = NO;
    // FIXME: COMutableDictionary
}

@end
