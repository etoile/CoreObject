/*
    Copyright (C) 2012 Quentin Mathe

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "CODictionary.h"
#import "COObjectGraphContext+Private.h"
#import "COObject+Private.h"
#import "COSerialization.h"

@interface COObject ()
- (id)serializedValueForPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
- (id)serializedValueForValue: (id)value
 univaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
- (COType)serializedTypeForUnivaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc
                                                ofValue: (id)aValue;
- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
 univaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
@end

@implementation COObject (CODictionarySerialization)

#pragma mark Serialization
#pragma mark -

- (COItem *)storeItemFromDictionaryForPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    NILARG_EXCEPTION_TEST(aPropertyDesc);

    NSDictionary *dict = [self serializedValueForPropertyDescription: aPropertyDesc];
    NSMutableDictionary *types =
        [NSMutableDictionary dictionaryWithCapacity: dict.count];
    NSMutableDictionary *values =
        [NSMutableDictionary dictionaryWithCapacity: dict.count];

    for (NSString *key in dict.allKeys)
    {
        NSAssert2(isSerializablePrimitiveValue(key),
            @"Unsupported key type %@ in %@. For dictionary serialization, "
              "keys must be a primitive CoreObject values (NSString, NSNumber or NSData).",
              key, dict);
    
        id value = dict[key];
        id serializedValue = [self serializedValueForValue: value
                              univaluedPropertyDescription: aPropertyDesc];
        COType serializedType = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
                                                                            ofValue: serializedValue];
    
        values[key] = serializedValue;
        types[key] = @(serializedType);
    }

    ETEntityDescription *rootCoreObjectEntity =
        [_objectGraphContext.modelDescriptionRepository entityDescriptionForClass: [COObject class]];

    return [self storeItemWithUUID: _additionalStoreItemUUIDs[aPropertyDesc.name]
                             types: types
                            values: values
                        entityName: @"CODictionary"
                packageDescription: rootCoreObjectEntity.owner];
}

- (NSDictionary *)dictionaryFromStoreItem: (COItem *)aStoreItem
                   forPropertyDescription: (ETPropertyDescription *)propertyDesc
{
    NILARG_EXCEPTION_TEST(aStoreItem);
    NILARG_EXCEPTION_TEST(propertyDesc);

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    for (NSString *property in aStoreItem.attributeNames)
    {
        if ([property isEqualToString: kCOObjectEntityNameProperty]
         || [property isEqualToString: kCOObjectPackageVersionProperty]
         || [property isEqualToString: kCOObjectPackageNameProperty])
        {
            // HACK
            continue;
        }

        id serializedValue = [aStoreItem valueForAttribute: property];
        COType serializedType = [aStoreItem typeForAttribute: property];
    
        if (propertyDesc == nil)
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"Tried to set serialized value %@ of type %@ "
                                 "for property %@ missing in the metamodel %@",
                                serializedValue, @(serializedType), propertyDesc.name, self.entityDescription];
        }

        id value = [self valueForSerializedValue: serializedValue
                                          ofType: serializedType
                    univaluedPropertyDescription: propertyDesc];
        dict[property] = value;
    }

    // FIXME: Make read-only if needed
    return dict;
}

@end

@implementation COItem (CODictionarySerialization)

- (BOOL)isAdditionalItem
{
    return [[self valueForAttribute: kCOObjectEntityNameProperty] isEqualToString: @"CODictionary"];
}

@end
