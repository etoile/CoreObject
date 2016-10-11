/*
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "COSerialization.h"
#import "COObject+Private.h"
#import "COObject+RelationshipCache.h"
#import "CODictionary.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COPath.h"
#import "COPrimitiveCollection.h"
#import "COAttachmentID.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COEditingContext+Private.h"
#import "CODateSerialization.h"

#include <objc/runtime.h>

static NSNull *null = nil;
static NSDictionary *serializablePersistentTypes = nil;

@implementation COObject (COSerialization)

+ (void)initializeSerialization
{
    null = [NSNull null];
    // TODO: We should use -[COObjectGraphContext serializablePersistentTypes]
    // and construct it when the context is initialized with the model description repository.
    serializablePersistentTypes = @{@"NSString": @(kCOTypeString), @"NSData": @(kCOTypeBlob)};
}

static inline BOOL isSerializablePersistentType(ETPropertyDescription *aPropertyDesc)
{
    return serializablePersistentTypes[aPropertyDesc.persistentType.name] != nil;
}

/* Returns whether the given value is a primitive type supported by CoreObject
serialization. */
BOOL isSerializablePrimitiveValue(id value)
{
    return ([value isKindOfClass: [NSString class]]
            || [value isKindOfClass: [NSNumber class]]
            || [value isKindOfClass: [NSData class]]);
}

/* See ETGeometry.h in EtoileUI
 
There is no support for null scalar structs in AppKit unlike CoreGraphics. 
EtoileUI extends AppKit to support them. Could be better to move them to 
EtoileFoundation. */
static const NSPoint CONullPoint = {FLT_MIN, FLT_MIN};
static const NSSize CONullSize = {FLT_MIN, FLT_MIN};
static const NSRect CONullRect = {{FLT_MIN, FLT_MIN}, {FLT_MIN, FLT_MIN}};

/* Returns whether the given value is a scalar type supported by CoreObject 
serialization. */
BOOL isSerializableScalarValue(id value)
{
    if (![value isKindOfClass: [NSValue class]])
        return NO;

    const char *type = [value objCType];

    return ((strcmp(type, @encode(NSPoint)) == 0)
            || (strcmp(type, @encode(NSSize)) == 0)
            || (strcmp(type, @encode(NSRect)) == 0)
            || (strcmp(type, @encode(NSRange)) == 0));
}

/* Returns a scalar string representation for a NSValue object if possible.
 
Nil is returned when the value type is unsupported by CoreObject serialization. */
- (id)serializedValueForScalarValue: (NSValue *)value
{
    NSParameterAssert([value isKindOfClass: [NSValue class]]);
    const char *type = value.objCType;

    if (strcmp(type, @encode(NSPoint)) == 0)
    {
        const NSPoint point = value.pointValue;
        if (NSEqualPoints(point, CONullPoint))
        {
            return @"null-point";
        }
        return NSStringFromPoint(point);
    }
    else if (strcmp(type, @encode(NSSize)) == 0)
    {
        const NSSize size = value.sizeValue;
        if (NSEqualSizes(size, CONullSize))
        {
            return @"null-size";
        }
        return NSStringFromSize(size);
    }
    else if (strcmp(type, @encode(NSRect)) == 0)
    {
        const NSRect rect = value.rectValue;
        if (NSEqualRects(rect, CONullRect))
        {
            return @"null-rect";
        }
        return NSStringFromRect(rect);
    }
    else if (strcmp(type, @encode(NSRange)) == 0)
    {
        // TODO: Add null range support
        return NSStringFromRange(value.rangeValue);
    }
    else
    {
        NSAssert2(NO, @"Unsupported scalar serialization type %s for %@", type, value);
    }
    return nil;
}

static id serializedReferenceInContextForObject(COObjectGraphContext *objectGraphContext,
    COObject *value)
{
    /* Some root object relationships are special in the sense the value can be
       a core object but its persistency isn't enabled. We interpret these 
       one-to-one relationships as transient.
       Usually a root object belongs to some other objects at run-time, in some
       cases the root object  want to hold a backward pointer (inverse
       relationship) to those non-persistent object(s).
       For example, a root object can be a layout item whose parent item is the
       window group... In such a case, we don't want to persist the window
       group, but ignore it. At deseserialiation time, the app is responsible
       to add the item back to the window group (the parent item would be
       restored then). */
    if (!value.isPersistent && value.objectGraphContext != objectGraphContext)
    {
        return null;
    }

    if (value.persistentRoot == objectGraphContext.persistentRoot)
    {
        return value.UUID;
    }
    else
    {
        // Serialize this cross-persistent root reference as a COPath

        NSCAssert([value isRoot], @"A property must point to a root object "
            "for references accross persistent roots");

        COPersistentRoot *referencedPersistentRoot = value.persistentRoot;
        COObjectGraphContext *referencedPersistentRootCurrentBranchGraph =
            referencedPersistentRoot.objectGraphContext;
        COObjectGraphContext *referencedObjectGraph = value.objectGraphContext;
        COBranch *referencedBranch = value.branch;

        if (referencedObjectGraph == referencedPersistentRootCurrentBranchGraph)
        {
            // Serialize as a reference to the current branch
            return [COPath pathWithPersistentRoot: referencedPersistentRoot.UUID];
        }
        else
        {
            // Serialize as a reference to a specific branch
            return [COPath pathWithPersistentRoot: referencedPersistentRoot.UUID
                                           branch: referencedBranch.UUID];
        }
    }
}

- (id) serializedValueForValue: (id)value
multivaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    NSAssert(value != nil, @"Multivalued properties must not be nil");

    /* Don't serialize NSDictionary as multivalue but as CODictionary reference */
    if (aPropertyDesc.keyed)
    {
        ETAssert([value isKindOfClass: [NSDictionary class]]);
        return _additionalStoreItemUUIDs[aPropertyDesc.name];
    }
    else if (aPropertyDesc.ordered)
    {
        ETAssert([value isKindOfClass: [COMutableArray class]]);
        NSMutableArray *array = [NSMutableArray arrayWithCapacity: [value count]];

        for (id element in [value enumerableReferences])
        {
            [array addObject: serializeUnivalue(self, element, aPropertyDesc)];
        }
        return array;
    }
    else
    {
        ETAssert([value isKindOfClass: [COMutableSet class]]);
        NSMutableSet *set = [NSMutableSet setWithCapacity: [value count]];

        for (id element in [value enumerableReferences])
        {
            [set addObject: serializeUnivalue(self, element, aPropertyDesc)];
        }
        return set;
    }
}

static id transformedValueOfPropertyDescription(COObject *self, id value,
    ETPropertyDescription *aPropertyDesc)
{
    if (aPropertyDesc.valueTransformerName == nil)
        return value;

    // TODO: Move in the caller
    assert(isSerializablePersistentType(aPropertyDesc));

    ETModelDescriptionRepository *repo = self->_objectGraphContext.modelDescriptionRepository;
    ETEntityDescription *valueEntity = entityDescriptionForObjectInRepository(value, repo);

    assert(value == nil || [valueEntity isKindOfEntity: aPropertyDesc.type]);

    NSValueTransformer *transformer = valueTransformerForPropertyDescription(aPropertyDesc);
    id result = [transformer transformedValue: value];

    ETEntityDescription *resultEntity = entityDescriptionForObjectInRepository(result, repo);

    assert(result == nil || [resultEntity isKindOfEntity: aPropertyDesc.persistentType]);
    assert(result == nil || isSerializablePrimitiveValue(result));
    return result;
}

- (id)serializedValueForValue: (id)aValue
 univaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    return serializeUnivalue(self, aValue, aPropertyDesc);
}

static id serializeUnivalue(COObject *self, id aValue, ETPropertyDescription *aPropertyDesc)
{
    id value = transformedValueOfPropertyDescription(self, aValue, aPropertyDesc);

    if (value == nil)
    {
        return null;
    }
    else if ([value isKindOfClass: [COObject class]])
    {
        return serializedReferenceInContextForObject(self->_objectGraphContext, value);
    }
    else if ([value isKindOfClass: [COPath class]])
    {
        return value;
    }
    else if ([value isKindOfClass: [COAttachmentID class]])
    {
        return value;
    }
    else if (isSerializablePrimitiveValue(value))
    {
        return value;
    }
    else if (isSerializableScalarValue(value))
    {
        return [self serializedValueForScalarValue: value];
    }
    else if ([value isKindOfClass: [NSDate class]])
    {
        /* For convenience, serialize NSDate as a int64_t using Java semantics. */
        return CODateToJavaTimestamp(value);
    }
    else
    {
        NSCAssert2(NO, @"Unsupported serialization type %@ for %@", [value class], value);
    }
    return nil;
}

- (id)serializedValueForValue: (id)value
          propertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    if (aPropertyDesc.multivalued)
    {
        return [self serializedValueForValue: value
              multivaluedPropertyDescription: aPropertyDesc];
    }
    else
    {
        return serializeUnivalue(self, value, aPropertyDesc);
    }
}

/* Returns whether the given value is a scalar type name supported by CoreObject 
serialization. */
static inline BOOL isSerializableScalarTypeName(NSString *aTypeName)
{
    return ([aTypeName isEqualToString: @"NSRect"]
            || [aTypeName isEqualToString: @"NSSize"]
            || [aTypeName isEqualToString: @"NSPoint"]
            || [aTypeName isEqualToString: @"NSRange"]);
}

- (COType)serializedTypeForNumber: (NSNumber *)value
{
    NSParameterAssert(value == nil || [value isKindOfClass: [NSNumber class]]);

    // TODO: A bit ugly, would be better to add new entity descriptions
    // such as NSBOOLNumber, NSCGFloatNumber etc.
    if (value == nil)
        return kCOTypeString;

    if (strcmp(value.objCType, @encode(BOOL)) == 0
        || strcmp(value.objCType, @encode(NSInteger)) == 0
        || strcmp(value.objCType, @encode(NSUInteger)) == 0)
    {
        return kCOTypeInt64;
    }
    else if (strcmp(value.objCType, @encode(CGFloat)) == 0
             || strcmp(value.objCType, @encode(double)) == 0
             || strcmp(value.objCType, @encode(float)) == 0)
    {
        return kCOTypeDouble;
    }

    // FIXME: Finish the above... we should handle all values that NSNumber can encode,
    // except unsigned integers larger than the maximum value of int64_t.
    ETAssertUnreachable();
    return 0;
}

- (NSString *)primitiveTypeNameFromValue: (id)value
{
    if (value == nil)
    {
        // NOTE: We use an arbitrary type
        return @"NSData";
    }
    else if ([value isKindOfClass: [COObject class]])
    {
        return @"COObject";
    }
    else if ([value isKindOfClass: [NSString class]])
    {
        return @"NSString";
    }
    else if ([value isKindOfClass: [NSNumber class]])
    {
        return @"NSNumber";
    }
    else if ([value isKindOfClass: [NSData class]])
    {
        return @"NSData";
    }
    else if ([value isKindOfClass: [COAttachmentID class]])
    {
        return @"COAttachmentID";
    }
    else
    {
        NSAssert1(NO, @"Unsupported dynamic serialization type for %@", value);
        return nil;
    }
}

- (COType)serializedTypeForUnivaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc
                                                ofValue: (id)value
{
    ETEntityDescription *type = aPropertyDesc.persistentType;
    ETAssert(type != nil);
    NSString *typeName = type.name;

    if (aPropertyDesc.valueTransformerName != nil)
    {
        ETAssert(![type isEqual: aPropertyDesc.type]);
        return [serializablePersistentTypes[typeName] intValue];
    }

    BOOL isDynamicType = [typeName isEqualToString: @"NSObject"];

    /* For a dynamic type, we get the type from the value directly, rather than
       from the metamodel, then we return a COType exactly as we would for a
       type declared in the metamodel.
       For a nil value, we return an arbitrary type since we cannot get a type 
       from the value. */
    if (isDynamicType)
    {
        typeName = [self primitiveTypeNameFromValue: value];
    }

    if (aPropertyDesc.isPersistentRelationship)
    {
        return (aPropertyDesc.isComposite ? kCOTypeCompositeReference : kCOTypeReference);
    }
    else if ([typeName isEqualToString: @"BOOL"]
             || [typeName isEqualToString: @"NSInteger"]
             || [typeName isEqualToString: @"NSUInteger"])
    {
        return kCOTypeInt64;
    }
    else if ([typeName isEqualToString: @"CGFloat"]
             || [typeName isEqualToString: @"Double"])
    {
        return kCOTypeDouble;
    }
    else if ([typeName isEqualToString: @"NSString"])
    {
        return kCOTypeString;
    }
    else if ([typeName isEqualToString: @"NSNumber"])
    {
        return [self serializedTypeForNumber: value];
    }
    else if ([typeName isEqualToString: @"NSData"])
    {
        return kCOTypeBlob;
    }
    else if (isSerializableScalarTypeName(typeName))
    {
        return kCOTypeString;
    }
    else if ([typeName isEqualToString: @"COAttachmentID"])
    {
        return kCOTypeAttachment;
    }
    else if ([typeName isEqualToString: @"NSDate"])
    {
        /** For convenience, serialize NSDate as a int64_t using Java semantics. */
        return kCOTypeInt64;
    }
    else
    {
        NSAssert2(NO, @"Unsupported serialization type %@ for %@", type, value);
        return 0;
    }
}

- (NSNumber *)serializedTypeForPropertyDescription: (ETPropertyDescription *)aPropertyDesc
                                             value: (id)value
{
    COType type = 0;

    if (aPropertyDesc.multivalued)
    {
        NSAssert(value != nil, @"Multivalued properties must not be nil");

        /* Don't serialize NSDictionary as multivalue but as CODictionary reference */
        if (aPropertyDesc.keyed)
        {
            ETAssert([value isKindOfClass: [NSDictionary class]]);
            type = kCOTypeCompositeReference;
        }
        else if (aPropertyDesc.ordered)
        {
            ETAssert([value isKindOfClass: [NSArray class]]);
            // HACK: The ofValue param should be removed.
            // Should not need to infer type based on an element of the collection.
            COType elementType = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
                                                                             ofValue: [value firstObject]];
            type = (kCOTypeArray | elementType);
        }
        else
        {
            ETAssert([value isKindOfClass: [NSSet class]]);
            COType elementType = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
                                                                             ofValue: [value anyObject]];
            type = (kCOTypeSet | elementType);
        }
    }
    else
    {
        type = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
                                                           ofValue: value];
    }
    return @(type);
}

- (SEL)serializationGetterForProperty: (NSString *)property
{
    const char *key = property.UTF8String;
    const size_t keyLength = strlen(key);
    const char *prefix = "serialized";
    const size_t prefixLength = strlen(prefix);
    char getter[prefixLength + keyLength + 1];

    memcpy(getter, prefix, prefixLength);
    memcpy(getter + prefixLength, key, keyLength);

    getter[prefixLength] = toupper(key[0]);
    getter[prefixLength + keyLength] = '\0';
    assert(getter[prefixLength + keyLength] == '\0');

    SEL selector = sel_getUid(getter);

    return ([self respondsToSelector: selector] ? selector : NULL);
}

// TODO: Could be changed to -serializedValueForProperty: once the previous
// serialization format has been removed.
- (id)serializedValueForPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    /* First we try to use the getter named 'serialized' + 'key' */

    SEL getter = [self serializationGetterForProperty: aPropertyDesc.name];

    if (getter != NULL)
    {
        NSAssert1([self serializationSetterForProperty: aPropertyDesc.name] != NULL,
                  @"Serialization getter %@ must have a matching serialization setter",
                  NSStringFromSelector(getter));

        return [self performSelector: getter];
    }

    /* If no custom getter can be found, we access the stored value directly 
       (ivar and variable storage) */

    return [self serializableValueForStorageKey: aPropertyDesc.name];
}

- (COItem *)storeItemWithUUID: (ETUUID *)aUUID
                        types: (NSMutableDictionary *)types
                       values: (NSMutableDictionary *)values
                   entityName: (NSString *)anEntityName
           packageDescription: (ETPackageDescription *)package
{
    values[kCOItemEntityNameProperty] = anEntityName;
    types[kCOItemEntityNameProperty] = @(kCOTypeString);
    values[kCOItemPackageVersionProperty] = @(package.version);
    types[kCOItemPackageVersionProperty] = @(kCOTypeInt64);
    values[kCOItemPackageNameProperty] = package.name;
    types[kCOItemPackageNameProperty] = @(kCOTypeString);

    return [[COItem alloc] initWithUUID: aUUID
                     typesForAttributes: types
                    valuesForAttributes: values];
}

- (COItem *)storeItem
{
    NSArray *serializedPropertyDescs =
        _entityDescription.allPersistentPropertyDescriptions;
    NSMutableDictionary *types =
        [NSMutableDictionary dictionaryWithCapacity: serializedPropertyDescs.count];
    NSMutableDictionary *values =
        [NSMutableDictionary dictionaryWithCapacity: serializedPropertyDescs.count];

    for (ETPropertyDescription *propertyDesc in serializedPropertyDescs)
    {
        // TODO: Should change -serializedValueForPropertyDescription: to
        // -serializedValueForProperty: once we remove the previous serialization support
        id value = [self serializedValueForPropertyDescription: propertyDesc];
        id serializedValue = [self serializedValueForValue: value
                                       propertyDescription: propertyDesc];
        NSNumber *serializedType = [self serializedTypeForPropertyDescription: propertyDesc
                                                                        value: value];

        values[propertyDesc.name] = serializedValue;
        types[propertyDesc.name] = serializedType;
    }

    return [self storeItemWithUUID: _UUID
                             types: types
                            values: values
                        entityName: _entityDescription.name
                packageDescription: _entityDescription.owner];
}

- (COItem *)additionalStoreItemForUUID: (ETUUID *)anItemUUID
{
    if ([_additionalStoreItemUUIDs isEmpty])
        return nil;

    NSString __block *property = nil;

    [_additionalStoreItemUUIDs enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop)
    {
        if ([obj isEqual: anItemUUID])
        {
            property = key;
            *stop = YES;
        }
    }];

    ETPropertyDescription *propertyDesc =
        [self.entityDescription propertyDescriptionForName: property];

    return [self storeItemFromDictionaryForPropertyDescription: propertyDesc];
}

/* Returns a NSValue object for a scalar string value if possible.
 
Nil is returned when the value type is unsupported by CoreObject deserialization. */
- (NSValue *)scalarValueForSerializedValue: (id)value typeName: (NSString *)typeName
{
    // NOTE: We should never receive a nil value, because scalar values are
    // either special zero or null constants encoded as such but never equal to
    // zero or nil.
    NSParameterAssert(value != nil);
    NSParameterAssert([value isKindOfClass: [NSString class]]);

    if ([typeName isEqualToString: @"NSPoint"])
    {
        NSPoint point;
        if ([value isEqualToString: @"null-point"])
        {
            point = CONullPoint;
        }
        else
        {
            point = NSPointFromString(value);
        }
        return [NSValue valueWithPoint: point];
    }
    else if ([typeName isEqualToString: @"NSSize"])
    {
        NSSize size;
        if ([value isEqualToString: @"null-size"])
        {
            size = CONullSize;
        }
        else
        {
            size = NSSizeFromString(value);
        }
        return [NSValue valueWithSize: size];
    }
    else if ([typeName isEqualToString: @"NSRect"])
    {
        NSRect rect;
        if ([value isEqualToString: @"null-rect"])
        {
            rect = CONullRect;
        }
        else
        {
            rect = NSRectFromString(value);
        }
        return [NSValue valueWithRect: rect];
    }
    else if ([typeName isEqualToString: @"NSRange"])
    {
        // TODO: Add null range support
        return [NSValue valueWithRange: NSRangeFromString(value)];
    }
    else
    {
        NSAssert2(NO, @"Unsupported scalar serialization type %@ for %@", typeName, value);
    }
    return nil;
}

- (COObject *)objectForSerializedReference: (id)value
                                    ofType: (COType)type
                       propertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    COObject *object = nil;

    if ([value isKindOfClass: [ETUUID class]])
    {
        NSParameterAssert(COTypePrimitivePart(type) == kCOTypeReference
                          || COTypePrimitivePart(type) == kCOTypeCompositeReference);
        /* Look up a inner object reference in the receiver persistent root */
        object = [self.objectGraphContext objectReferenceWithUUID: value];
        ETAssert(object != nil);
    }
    else /* COPath */
    {
        NSParameterAssert(COTypePrimitivePart(type) == kCOTypeReference);
        object = [self.persistentRoot.editingContext crossPersistentRootReferenceWithPath: (COPath *)value
                                                                               shouldLoad: NO];
        /* object may be nil for dead reference */
    }

    if (object != nil)
    {
        ETAssert([object.entityDescription isKindOfEntity: [aPropertyDesc persistentType]]);
    }

    return object;
}

// TODO: Could replace -loadingItemGraph as a semi-private COObjectGraphContext API.
- (COItem *)itemForUUIDDuringLoading: (ETUUID *)aUUID
{
    COItem *item = [self.objectGraphContext.loadingItemGraph itemForUUID: aUUID];

    if (item == nil)
    {
        item = [self.objectGraphContext itemForUUID: aUUID];
    }
    NSAssert1(item != nil, @"Found no item %@", aUUID);

    return item;
}

// NOTE: If we add more collection attributes to the metamodel, we should update this method assertions.
- (id) valueForSerializedValue: (id)value
                        ofType: (COType)type
multivaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    if (COTypeMultivaluedPart(type) == kCOTypeArray)
    {
        NSAssert(!aPropertyDesc.keyed && aPropertyDesc.ordered && aPropertyDesc.multivalued,
                 @"Serialization type doesn't match metamodel");

        COMutableArray *resultCollection =
            [[self coreObjectCollectionClassForPropertyDescription: aPropertyDesc] new];

        [resultCollection beginMutation];
        for (id subvalue in value)
        {
            id deserializedValue =
                deserializeUnivalue(self, subvalue, COTypePrimitivePart(type), aPropertyDesc);

            [resultCollection addReference: deserializedValue];
        }
        [resultCollection endMutation];

        return resultCollection;
    }
    else if (COTypeMultivaluedPart(type) == kCOTypeSet)
    {
        NSAssert(!aPropertyDesc.keyed && !aPropertyDesc.ordered && aPropertyDesc.multivalued,
                 @"Serialization type doesn't match metamodel");

        COMutableSet *resultCollection =
            [[self coreObjectCollectionClassForPropertyDescription: aPropertyDesc] new];

        [resultCollection beginMutation];
        for (id subvalue in value)
        {
            id deserializedValue =
                deserializeUnivalue(self, subvalue, COTypePrimitivePart(type), aPropertyDesc);

            [resultCollection addReference: deserializedValue];
        }
        [resultCollection endMutation];

        return resultCollection;
    }
    else if (type == kCOTypeCompositeReference)
    {
        NSParameterAssert([value isKindOfClass: [ETUUID class]]);
        NSAssert(aPropertyDesc.keyed && !aPropertyDesc.ordered && aPropertyDesc.multivalued,
                 @"Serialization type doesn't match metamodel");

        ETUUID *itemUUID = _additionalStoreItemUUIDs[aPropertyDesc.name];
        const BOOL isNewObjectFromDeserialization = [itemUUID isEqual: null];

        if (isNewObjectFromDeserialization)
        {
            _additionalStoreItemUUIDs[aPropertyDesc.name] = value;
        }
        else /* Future deserializations targeting the same object */
        {
            NSAssert([itemUUID isEqual: value],
                     @"Additional store item UUIDs must remain constant");
        }

        /* Set the dictionary now to ensure attribute dictionaries are already
           loaded when -awakeFromDeserialization is called. */
        return [self dictionaryFromStoreItem: [self itemForUUIDDuringLoading: value]
                      forPropertyDescription: aPropertyDesc];
    }
    else
    {
        NSAssert2(NO, @"Unsupported serialization type %@ for %@", COTypeDescription(type), value);
        return nil;
    }
}

static inline NSValueTransformer *valueTransformerForPropertyDescription(
    ETPropertyDescription *aPropertyDesc)
{
    NSValueTransformer *transformer =
        [NSValueTransformer valueTransformerForName: aPropertyDesc.valueTransformerName];

    if (transformer == nil)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Found no value transformer registered for %@, attached to %@",
                            aPropertyDesc.valueTransformerName, aPropertyDesc.fullName];
    }
    return transformer;
}

static id reverseTransformedValueOfPropertyDescription(COObject *self, id value,
    ETPropertyDescription *aPropertyDesc)
{
    if (aPropertyDesc.valueTransformerName == nil)
        return value;

    // TODO: Move in the caller
    assert(isSerializablePersistentType(aPropertyDesc));

    ETModelDescriptionRepository *repo = self->_objectGraphContext.modelDescriptionRepository;
    ETEntityDescription *valueEntity = entityDescriptionForObjectInRepository(value, repo);;

    assert(value == nil || [valueEntity isKindOfEntity: [aPropertyDesc persistentType]]);
    assert(value == nil || isSerializablePrimitiveValue(value));
    // TODO: Move in the caller probably
    //ETAssert([self.serializablePersistentTypes containsObject: @(COTypePrimitivePart(type))]);

    NSValueTransformer *transformer = valueTransformerForPropertyDescription(aPropertyDesc);
    id result = [transformer reverseTransformedValue: value];

    ETEntityDescription *resultEntityDesc = entityDescriptionForObjectInRepository(result, repo);

    assert(result == nil || [resultEntityDesc isKindOfEntity: aPropertyDesc.type]);

    return result;
}

- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
 univaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    return deserializeUnivalue(self, value, type, aPropertyDesc);
}

static id deserializeUnivalue(COObject *self, id value, COType type,
    ETPropertyDescription *aPropertyDesc)
{
    NSString *typeName = aPropertyDesc.persistentType.name;
    const BOOL isNull = (value == null);
    id result = value;

    if (isNull)
    {
        assert(COTypeIsValid(type));
        result = nil;
    }
    else if (type == kCOTypeReference || type == kCOTypeCompositeReference)
    {
        result = [self objectForSerializedReference: value
                                             ofType: type
                                propertyDescription: aPropertyDesc];

        const BOOL isCrossPersistentRootRef = [value isKindOfClass: [COPath class]];
        const BOOL isDeletedCrossPersistentRootRef = isCrossPersistentRootRef
                                               && ([result persistentRoot].deleted || [result branch].deleted);
        const BOOL isDeadCrossPersistentRootRef = (result == nil && isCrossPersistentRootRef);

        result = (isDeadCrossPersistentRootRef || isDeletedCrossPersistentRootRef ? value : result);

        // TODO: We should be able to remove it since the value transformer
        // shouldn't touch it
        return result;
    }
    else if (type == kCOTypeInt64)
    {
        if ([typeName isEqualToString: @"NSDate"])
        {
            result = CODateFromJavaTimestamp(value);
        }
    }
    else if (type == kCOTypeDouble)
    {

    }
    else if (type == kCOTypeString)
    {
        if (isSerializableScalarTypeName(typeName))
        {
            result = [self scalarValueForSerializedValue: value typeName: typeName];
        }
    }
    else if (type == kCOTypeBlob)
    {
        assert([value isKindOfClass: [NSData class]]);
    }
    else if (type == kCOTypeAttachment)
    {
        assert([value isKindOfClass: [COAttachmentID class]]);
    }
    else
    {
        NSCAssert2(NO, @"Unsupported serialization type %@ for %@", COTypeDescription(type), value);
    }

    return reverseTransformedValueOfPropertyDescription(self, result, aPropertyDesc);
}

- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
          propertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    // NOTE: For the elements in a dictionary, type is the key type (e.g.
    // kCOTypeString). In both cases, aPropertyDesc.isKeyed is YES.
    if (COTypeIsMultivalued(type) || aPropertyDesc.keyed)
    {
        if (aPropertyDesc.isKeyed)
        {
            ETAssert(type == kCOTypeCompositeReference);
        }
        return [self valueForSerializedValue: value
                                      ofType: type
              multivaluedPropertyDescription: aPropertyDesc];
    }
    else
    {
        return deserializeUnivalue(self, value, type, aPropertyDesc);;
    }
}

- (SEL)serializationSetterForProperty: (NSString *)property
{
    const char *key = property.UTF8String;
    const size_t keyLength = strlen(key);
    const char *prefix = "setSerialized";
    const size_t prefixLength = strlen(prefix);
    char setter[prefixLength + keyLength + 2];

    memcpy(setter, prefix, prefixLength);
    memcpy(setter + prefixLength, key, keyLength);

    setter[prefixLength] = toupper(key[0]);
    setter[prefixLength + keyLength] = ':';
    setter[prefixLength + keyLength + 1] = '\0';
    assert(setter[prefixLength + keyLength + 1] == '\0');

    SEL selector = sel_getUid(setter);

    return ([self respondsToSelector: selector] ? selector : NULL);
}

// TODO: Could be changed to -setSerializedValue:forProperty: once the previous
// serialization format has been removed.
- (void)setSerializedValue: (id)value forPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    NSString *key = aPropertyDesc.name;

    /* First we try to use the setter named 'setSerialized' + 'key' */

    SEL setter = [self serializationSetterForProperty: key];

    if ([self respondsToSelector: setter])
    {
        NSAssert1([self serializationGetterForProperty: aPropertyDesc.name] != NULL,
                  @"Serialization setter %@ must have a matching serialization getter",
                  NSStringFromSelector(setter));

        [self performSelector: setter withObject: value];
        return;
    }

    /* When no custom setter can be found, we access the stored value directly */

    [self willChangeValueForProperty: key];
    [self setValue: value forStorageKey: key];
    /* Persistent roots will post KVO notifications but won't record the changes */
    [self didChangeValueForProperty: key];
}

/* Validates that the receiver is compatible with the provided store item. */
- (void)validateStoreItem: (COItem *)aStoreItem
{
    if (![aStoreItem.UUID isEqual: self.UUID])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"-setStoreItem: called with UUID %@ on COObject with UUID %@",
                            aStoreItem.UUID,
                            self.UUID];
    }

    ETEntityDescription *entityDesc =
        [_objectGraphContext.modelDescriptionRepository descriptionForName: aStoreItem.entityName];

    /* If B is a subclass of A, and a property description type is A but the 
       the property value is a B object, the deserialized property value is 
       accepted because [B isKindOfEntity: A] is true. */
    if (![_entityDescription isKindOfEntity: entityDesc] && !_entityDescription.isRoot)
    {
        // TODO: Rewrite this exception to provide a better explanation.
        [NSException raise: NSInvalidArgumentException
                    format: @"-setStoreItem: called with entity name %@ on COObject with entity name %@",
                            aStoreItem.entityName, self.entityDescription.name];

    }

    const BOOL wasSerializedBeforeSchemaMigrationSupport =
        aStoreItem.packageName == nil && [aStoreItem valueForAttribute: kCOItemPackageVersionProperty] == nil;

    if (wasSerializedBeforeSchemaMigrationSupport)
        return;

    if (![aStoreItem.packageName isEqualToString: entityDesc.owner.name])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"-setStoreItem: called with package name %@ on COObject with package name %@",
                            aStoreItem.packageName, self.entityDescription.owner.name];
    }
    if (aStoreItem.packageVersion != entityDesc.owner.version)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"-setStoreItem: called with package version %lld on COObject with "
                                "package version %lu",
                            aStoreItem.packageVersion,
                            (unsigned long)self.entityDescription.owner.version];
    }
}

- (void)setStoreItem: (COItem *)aStoreItem
{
    [self removeCachedOutgoingRelationships];

    [self validateStoreItem: aStoreItem];

    for (NSString *property in aStoreItem.attributeNames)
    {
        if ([property isEqualToString: kCOItemEntityNameProperty]
            || [property isEqualToString: kCOItemPackageVersionProperty]
            || [property isEqualToString: kCOItemPackageNameProperty])
        {
            // HACK
            continue;
        }

        ETPropertyDescription *propertyDesc =
            [_entityDescription propertyDescriptionForName: property];
        id serializedValue = [aStoreItem valueForAttribute: property];
        COType serializedType = [aStoreItem typeForAttribute: property];

        if (propertyDesc == nil)
        {
            // Was an exception in 0.5, but that seems overly paranoid
            NSLog(@"Warning: Tried to set serialized value %@ of type %@ for property %@ missing "
                      "in the metamodel %@",
                  serializedValue, COTypeDescription(serializedType), property, self.entityDescription);
            continue;
        }

        id value = [self valueForSerializedValue: serializedValue
                                          ofType: serializedType
                             propertyDescription: propertyDesc];
        // TODO: Should change -setSerializedValue:forPropertyDescription: to
        // -setSerializedValue:forProperty: once we remove the previous serialization support
        [self setSerializedValue: value forPropertyDescription: propertyDesc];
    }

    [self awakeFromDeserialization];
    // TODO: Decide whether to update relationship cache here. Document it.
}

- (id)roundTripValueForProperty: (NSString *)key
{
    ETPropertyDescription *propertyDesc = [self.entityDescription propertyDescriptionForName: key];
    ETAssert(propertyDesc.persistent);
    id value = [self serializedValueForPropertyDescription: propertyDesc];
    id serializedValue = [self serializedValueForValue: value propertyDescription: propertyDesc];
    NSNumber *serializedType = [self serializedTypeForPropertyDescription: propertyDesc
                                                                    value: value];
    const BOOL isSerializedAsAdditionalItem = [_additionalStoreItemUUIDs.allValues containsObject: serializedValue];

    if (isSerializedAsAdditionalItem)
    {
        ETAssert([serializedValue isKindOfClass: [ETUUID class]]);
        ETAssert([serializedType intValue] == kCOTypeCompositeReference);

        return [self dictionaryFromStoreItem: [self additionalStoreItemForUUID: serializedValue]
                      forPropertyDescription: propertyDesc];

    }

    return [self valueForSerializedValue: serializedValue
                                  ofType: serializedType.intValue
                     propertyDescription: [self.entityDescription propertyDescriptionForName: key]];
}

@end
