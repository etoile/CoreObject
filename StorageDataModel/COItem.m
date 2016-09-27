/*
    Copyright (C) 2011 Eric Wasylishen

    Date:  December 2011
    License:  MIT  (see COPYING)
 */

#import "COItem.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
#import "COPath.h"
#import "COAttachmentID.h"

NSString *kCOObjectEntityNameProperty = @"org.etoile-project.coreobject.entityname";
NSString *kCOObjectPackageVersionProperty = @"org.etoile-project.coreobject.packageversion";
NSString *kCOObjectPackageNameProperty = @"org.etoile-project.coreobject.packagename";
NSString *kCOObjectIsSharedProperty = @"isShared";

static NSDictionary *copyValueDictionary(NSDictionary *input, BOOL mutable)
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];

    for (NSString *key in input)
    {
        id obj = input[key];

        if ([obj isKindOfClass: [NSCountedSet class]])
        {
            // FIXME: Always mutable
            result[key] = obj;
        }
        else if ([obj isKindOfClass: [NSSet class]])
        {
            result[key] = [(mutable ? [NSMutableSet class] : [NSSet class]) setWithSet: obj];
        }
        else if ([obj isKindOfClass: [NSArray class]])
        {
            result[key] = [(mutable ? [NSMutableArray class] : [NSArray class]) arrayWithArray: obj];
        }
        else
        {
            result[key] = obj;
        }
    }

    if (!mutable)
    {
        NSDictionary *immutable = [[NSDictionary alloc] initWithDictionary: result];
        return immutable;
    }
    return result;
}

@implementation COItem

- (instancetype)initWithUUID: (ETUUID *)aUUID
          typesForAttributes: (NSDictionary *)typesForAttributes
         valuesForAttributes: (NSDictionary *)valuesForAttributes
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(typesForAttributes);
    NILARG_EXCEPTION_TEST(valuesForAttributes);

    SUPERINIT;
    uuid = aUUID;
    // FIXME: These casts are not truly elegant
    types = (NSMutableDictionary *)[[NSDictionary alloc] initWithDictionary: typesForAttributes];
    values = (NSMutableDictionary *)copyValueDictionary(valuesForAttributes, NO);

    for (NSString *key in values)
    {
        ETAssert(COTypeValidateObject([types[key] intValue], values[key]));
    }

    return self;
}

- (instancetype)init
{
    return [self initWithUUID: nil typesForAttributes: nil valuesForAttributes: nil];
}

+ (COItem *)itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
                   valuesForAttributes: (NSDictionary *)valuesForAttributes
{
    return [[self alloc] initWithUUID: [ETUUID UUID]
                   typesForAttributes: typesForAttributes
                  valuesForAttributes: valuesForAttributes];
}

- (ETUUID *)UUID
{
    return uuid;
}

- (NSArray *)attributeNames
{
    return types.allKeys;
}

- (COType)typeForAttribute: (NSString *)anAttribute
{
    return [types[anAttribute] intValue];
}

- (id)valueForAttribute: (NSString *)anAttribute
{
    return values[anAttribute];
}


/** @taskunit equality testing */

- (BOOL)isEqual: (id)object
{
    if (object == self)
    {
        return YES;
    }
    if (![object isKindOfClass: [COItem class]])
    {
        return NO;
    }
    COItem *otherItem = (COItem *)object;

    if (![otherItem->uuid isEqual: uuid]) return NO;
    if (![otherItem->types isEqual: types]) return NO;
    if (![otherItem->values isEqual: values]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    return uuid.hash ^ types.hash ^ values.hash ^ 9014972660509684524LL;
}

/** @taskunit convenience */

- (NSString *)entityName
{
    return [self valueForAttribute: kCOObjectEntityNameProperty];
}

- (int64_t)packageVersion
{
    NSNumber *version = values[kCOObjectPackageVersionProperty];
    if (version != nil)
    {
        return version.longLongValue;
    }
    return -1;
}

- (NSString *)packageName
{
    return values[kCOObjectPackageNameProperty];
}

- (NSArray *)allObjectsForAttribute: (NSString *)attribute
{
    id value = [self valueForAttribute: attribute];

    if (COTypeIsUnivalued([self typeForAttribute: attribute]))
    {
        return ([value isEqual: [NSNull null]] ? @[] : @[value]);
    }
    else
    {
        if ([value isKindOfClass: [NSSet class]])
        {
            return ((NSSet *)value).allObjects;
        }
        else if ([value isKindOfClass: [NSArray class]])
        {
            return value;
        }
        else
        {
            return @[];
        }
    }
}

- (NSSet *)compositeReferencedItemUUIDs
{
    NSMutableSet *result = [NSMutableSet set];

    for (NSString *key in self.attributeNames)
    {
        COType type = [self typeForAttribute: key];
        if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
        {
            for (ETUUID *embedded in [self allObjectsForAttribute: key])
            {
                [result addObject: embedded];
            }
        }
    }
    return [NSSet setWithSet: result];
}

- (NSSet *)referencedItemUUIDs
{
    NSMutableSet *result = [NSMutableSet set];

    for (NSString *key in self.attributeNames)
    {
        COType type = [self typeForAttribute: key];
        if (COTypePrimitivePart(type) == kCOTypeReference)
        {
            for (ETUUID *embedded in [self allObjectsForAttribute: key])
            {
                // FIXME: May return COPath!
                [result addObject: embedded];
            }
        }
    }
    return [NSSet setWithSet: result];
}

- (NSSet *)allInnerReferencedItemUUIDs
{
    NSMutableSet *result = [NSMutableSet set];

    for (NSString *key in self.attributeNames)
    {
        COType type = [self typeForAttribute: key];
        if (COTypePrimitivePart(type) == kCOTypeCompositeReference
            || COTypePrimitivePart(type) == kCOTypeReference)
        {
            for (id aChild in [self allObjectsForAttribute: key])
            {
                // Ignore cross-persistent root references
                if ([aChild isKindOfClass: [COPath class]])
                    continue;

                // Ignore NSNull (that means the relationship is set to nil)
                if ([aChild isKindOfClass: [NSNull class]])
                    continue;

                [result addObject: aChild];
            }
        }
    }
    return [NSSet setWithSet: result];
}

// Helper methods for doing GC

- (NSArray *)attachments
{
    NSMutableArray *result = [NSMutableArray array];

    for (NSString *key in self.attributeNames)
    {
        COType type = [self typeForAttribute: key];
        if (COTypePrimitivePart(type) == kCOTypeAttachment)
        {
            for (COAttachmentID *embedded in [self allObjectsForAttribute: key])
            {
                [result addObject: embedded];
            }
        }
    }
    return result;
}

- (NSArray *)allReferencedPersistentRootUUIDs
{
    NSMutableArray *result = [NSMutableArray array];

    for (NSString *key in self.attributeNames)
    {
        COType type = [self typeForAttribute: key];
        if (COTypePrimitivePart(type) == kCOTypeReference)
        {
            for (id ref in [self allObjectsForAttribute: key])
            {
                if ([ref isKindOfClass: [COPath class]])
                {
                    [result addObject: [ref persistentRoot]];
                }
            }
        }
    }
    return result;
}

- (NSString *)fullTextSearchContent
{
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *key in self.attributeNames)
    {
        COType type = [self typeForAttribute: key];
        if (COTypePrimitivePart(type) == kCOTypeString)
        {
            [result addObject: [self valueForAttribute: key]];
        }
    }
    return [result componentsJoinedByString: @" "];
}

- (NSString *)description
{
    NSMutableString *result = [NSMutableString string];

    [result appendFormat: @"{ COItem %@\n", uuid];

    for (NSString *attrib in self.attributeNames)
    {
        [result appendFormat: @"\t%@ <%@> = '%@'\n",
                              attrib,
                              COTypeDescription([self typeForAttribute: attrib]),
                              [self valueForAttribute: attrib]];
    }

    [result appendFormat: @"}"];

    return result;
}

/** @taskunit copy */

- (id)copyWithZone: (NSZone *)zone
{
    return self;
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
    return [[COMutableItem alloc] initWithUUID: uuid
                            typesForAttributes: types
                           valuesForAttributes: values];
}

- (id)mutableCopyWithNameMapping: (NSDictionary *)aMapping
{
    COMutableItem *aCopy = [self mutableCopy];

    ETUUID *newUUIDForSelf = aMapping[self.UUID];
    if (newUUIDForSelf != nil)
    {
        [aCopy setUUID: newUUIDForSelf];
    }

    for (NSString *attr in aCopy.attributeNames)
    {
        id value = [aCopy valueForAttribute: attr];
        COType type = [aCopy typeForAttribute: attr];

        if (COTypeIsUnivalued(type))
        {
            /* For COPath and primitive values, the mapping is not used */
            if ([value isKindOfClass: [ETUUID class]] && aMapping[value] != nil)
            {
                [aCopy setValue: aMapping[value]
                   forAttribute: attr
                           type: type];
            }
        }
        else
        {
            id newCollection = [value mutableCopy];
            [newCollection removeAllObjects];

            for (id subValue in value)
            {
                if ([subValue isKindOfClass: [ETUUID class]] && aMapping[subValue] != nil)
                {
                    [newCollection addObject: aMapping[subValue]];
                }
                else
                {
                    /* For COPath and primitive values */
                    [newCollection addObject: subValue];
                }
            }

            [aCopy setValue: newCollection
               forAttribute: attr
                       type: type];
        }
    }

    return aCopy;
}

@end


@implementation COMutableItem

@dynamic entityName, packageName, packageVersion;

+ (COMutableItem *)itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
                          valuesForAttributes: (NSDictionary *)valuesForAttributes
{
    return (COMutableItem *)[super itemWithTypesForAttributes: typesForAttributes
                                          valuesForAttributes: valuesForAttributes];
}

- (instancetype)initWithUUID: (ETUUID *)aUUID
          typesForAttributes: (NSDictionary *)typesForAttributes
         valuesForAttributes: (NSDictionary *)valuesForAttributes
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(typesForAttributes);
    NILARG_EXCEPTION_TEST(valuesForAttributes);

    uuid = aUUID;
    types = [[NSMutableDictionary alloc] initWithDictionary: typesForAttributes];
    values = (NSMutableDictionary *)copyValueDictionary(valuesForAttributes, YES);

    for (NSString *key in values)
    {
        ETAssert(COTypeValidateObject([types[key] intValue], values[key]));
    }

    return self;
}

- (instancetype)initWithUUID: (ETUUID *)aUUID
{
    return [self initWithUUID: aUUID
           typesForAttributes: @{}
          valuesForAttributes: @{}];
}

- (instancetype)init
{
    return [self initWithUUID: [ETUUID UUID]];
}

+ (COMutableItem *)item
{
    return [[self alloc] init];
}

+ (COMutableItem *)itemWithUUID: (ETUUID *)aUUID
{
    return [(COMutableItem *)[self alloc] initWithUUID: aUUID];
}

- (void)setUUID: (ETUUID *)aUUID
{
    NILARG_EXCEPTION_TEST(aUUID);
    uuid = aUUID;
}

- (void)setValue: (id)aValue
    forAttribute: (NSString *)anAttribute
            type: (COType)aType
{
    NILARG_EXCEPTION_TEST(aValue);
    NILARG_EXCEPTION_TEST(anAttribute);

    ETAssert(COTypeValidateObject(aType, aValue));

    ((NSMutableDictionary *)types)[anAttribute] = @(aType);
    ((NSMutableDictionary *)values)[anAttribute] = aValue;
}

- (void)removeValueForAttribute: (NSString *)anAttribute
{
    [(NSMutableDictionary *)types removeObjectForKey: anAttribute];
    [(NSMutableDictionary *)values removeObjectForKey: anAttribute];
}

/** @taskunit convenience */

- (void)setEntityName: (NSString *)entityName
{
    [self setValue: [entityName copy]
      forAttribute: kCOObjectEntityNameProperty
              type: kCOTypeString];
}

- (void)setPackageVersion: (int64_t)entityVersion
{
    [self setValue: @(entityVersion)
      forAttribute: kCOObjectPackageVersionProperty
              type: kCOTypeInt64];
}

- (void)setPackageName: (NSString *)packageName
{
    [self setValue: [packageName copy]
      forAttribute: kCOObjectPackageNameProperty
              type: kCOTypeString];
}

- (void)setValue: (id)aValue
    forAttribute: (NSString *)anAttribute
{
    [self setValue: aValue
      forAttribute: anAttribute
              type: [self typeForAttribute: anAttribute]];
}

- (id)copyWithZone: (NSZone *)zone
{
    return [[COItem alloc] initWithUUID: uuid
                     typesForAttributes: types
                    valuesForAttributes: values];
}

@end

