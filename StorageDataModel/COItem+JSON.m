/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "COItem+JSON.h"
#import <EtoileFoundation/EtoileFoundation.h>
#import "COPath.h"
#import "COAttachmentID.h"
#import "COJSONSerialization.h"

@implementation COItem (JSON)

// Semi-hack: we store the UUID alongside the real object properties.
// This property name is reserved for JSON serialization and cannot be used
// as an actual property name.
NSString *const kCOJSONObjectUUIDProperty = @"_uuid";
NSString *const kCOJSONFormatProperty = @"_json-format";
NSString *const kCOJSONDeprecatedObjectUUIDProperty = @"org.etoile-project.coreobject.uuid";
NSString *const kCOJSONDeprecatedFormatProperty = @"org.etoile-project.coreobject.json-format";
NSString *const kCOJSONFormat1_0 = @"1.0";
// COType -> string

static NSString *arraySuffix = @"-array";
static NSString *setSuffix = @"-set";
static NSString *intPrefix = @"int";
static NSString *floatPrefix = @"float";
static NSString *stringPrefix = @"string";
static NSString *blobPrefix = @"blob";
static NSString *referencePrefix = @"reference";
static NSString *compositePrefix = @"composite";
static NSString *attachmentPrefix = @"attachment";

static NSString *
COJSONMultivalueTypeToString(COType type)
{
    if (COTypeIsMultivalued(type))
    {
        if (COTypeIsOrdered(type))
        {
            return arraySuffix;
        }
        else
        {
            return setSuffix;
        }
    }
    return @"";
}

static NSString *
COJSONPrimitiveTypeToString(COType type)
{
    switch (COTypePrimitivePart(type))
    {
        case kCOTypeInt64:
            return intPrefix;
        case kCOTypeDouble:
            return floatPrefix;
        case kCOTypeString:
            return stringPrefix;
        case kCOTypeBlob:
            return blobPrefix;
        case kCOTypeReference:
            return referencePrefix;
        case kCOTypeCompositeReference:
            return compositePrefix;
        case kCOTypeAttachment:
            return attachmentPrefix;
        default:
            return @"";
    }
}

NSString *
COJSONTypeToString(COType type)
{
    NSCAssert(COTypeIsValid(type), @"type to serialize not valid");
    return [COJSONPrimitiveTypeToString(type) stringByAppendingString: COJSONMultivalueTypeToString(type)];
}

// string -> COType

static COType
COJSONStringToType(NSString *type)
{
    NSArray *components = [type componentsSeparatedByString: @"-"];

    COType result = [@{intPrefix: @(kCOTypeInt64),
                       floatPrefix: @(kCOTypeDouble),
                       stringPrefix: @(kCOTypeString),
                       blobPrefix: @(kCOTypeBlob),
                       referencePrefix: @(kCOTypeReference),
                       compositePrefix: @(kCOTypeCompositeReference),
                       attachmentPrefix: @(kCOTypeAttachment)}[components[0]] intValue];

    if ([type hasSuffix: setSuffix])
    {
        result |= kCOTypeSet;
    }
    else if ([type hasSuffix: arraySuffix])
    {
        result |= kCOTypeArray;
    }

    NSCAssert(COTypeIsValid(result), @"deserialized type not valid");

    return result;
}

// COItem attribute value -> JSON-compatible plist

static id plistValueForPrimitiveValue(id aValue, COType aType)
{
    if (aValue == [NSNull null])
    {
        return aValue;
    }

    switch (COTypePrimitivePart(aType))
    {
        case kCOTypeInt64:
            return aValue;
        case kCOTypeDouble:
            return aValue;
        case kCOTypeString:
            return aValue;
        case kCOTypeAttachment:
            return [[aValue dataValue] base64String];
        case kCOTypeBlob:
            return [aValue base64String];
        case kCOTypeCompositeReference:
            return [aValue stringValue];
        case kCOTypeReference:
            if ([aValue isKindOfClass: [COPath class]])
            {
                return [@"path:" stringByAppendingString: [aValue stringValue]];
            }
            else
            {
                return [aValue stringValue];
            }
        default:
            [NSException raise: NSInvalidArgumentException format: @"unknown type %d", aType];
            return nil;
    }
}

static id plistValueForValue(id aValue, COType aType)
{
    NSString *typeString = COJSONTypeToString(aType);

    if (COTypeIsUnivalued(aType))
    {
        return @{typeString: plistValueForPrimitiveValue(aValue, aType)};
    }
    else
    {
        NSMutableArray *collection = [NSMutableArray array];
        for (id obj in aValue)
        {
            [collection addObject: plistValueForPrimitiveValue(obj, aType)];
        }
        return @{typeString: collection};
    }
}

// JSON-compatible plist -> COItem attribute value

static id valueForPrimitivePlistValue(id aValue, COType aType)
{
    if (aValue == [NSNull null])
    {
        return aValue;
    }

    switch (COTypePrimitivePart(aType))
    {
        case kCOTypeInt64:
            return aValue;
        case kCOTypeDouble:
            return aValue;
        case kCOTypeString:
            return aValue;
        case kCOTypeAttachment:
            return [[COAttachmentID alloc] initWithData: [aValue base64DecodedData]];
        case kCOTypeBlob:
            return [aValue base64DecodedData];
        case kCOTypeCompositeReference:
            return [ETUUID UUIDWithString: aValue];
        case kCOTypeReference:
            if ([aValue hasPrefix: @"path:"])
            {
                return [COPath pathWithString: [aValue substringFromIndex: 5]];
            }
            else
            {
                return [ETUUID UUIDWithString: aValue];
            }
        default:
            [NSException raise: NSInvalidArgumentException format: @"unknown type %d", aType];
            return nil;
    }
}

static id importValueFromPlist(id typeValuePair)
{
    NSCAssert([typeValuePair count] == 1, @"JSON value dictionary should be one key : one value");
    COType aType = COJSONStringToType([typeValuePair allKeys][0]);
    id aValue = [typeValuePair allValues][0];

    if (COTypeIsUnivalued(aType))
    {
        return valueForPrimitivePlistValue(aValue, aType);
    }
    else
    {
        id collection;
        if (COTypeIsOrdered(aType))
        {
            collection = [NSMutableArray array];
        }
        else
        {
            collection = [NSMutableSet set];
        }

        for (id obj in aValue)
        {
            [collection addObject: valueForPrimitivePlistValue(obj, aType)];
        }
        return collection;
    }
}

static COType importTypeFromPlist(id typeValuePair)
{
    NSCAssert([typeValuePair count] == 1, @"JSON value dictionary should be one key : one value");
    COType aType = COJSONStringToType([typeValuePair allKeys][0]);
    return aType;
}

// Migrate internal DNS prefixed keys (old format) to underscore prefixed keys (new format)
static NSDictionary *migrateInternalKeysFromOldToNewFormat(id aPlist) {
    if (aPlist[kCOJSONObjectUUIDProperty] != nil)
    {
        return aPlist;
    }
    NSMutableDictionary *plist = [aPlist isKindOfClass: [NSMutableDictionary class]]
        ? aPlist
        : [NSMutableDictionary dictionaryWithDictionary: aPlist];

    plist[kCOItemEntityNameProperty] = plist[kCOItemDeprecatedEntityNameProperty];
    plist[kCOItemPackageNameProperty] = plist[kCOItemDeprecatedPackageNameProperty];
    plist[kCOItemPackageVersionProperty] = plist[kCOItemDeprecatedPackageVersionProperty];
    plist[kCOJSONFormatProperty] = plist[kCOJSONDeprecatedFormatProperty];
    plist[kCOJSONObjectUUIDProperty] = plist[kCOJSONDeprecatedObjectUUIDProperty];
    
    [plist removeObjectForKey: kCOItemDeprecatedEntityNameProperty];
    [plist removeObjectForKey: kCOItemDeprecatedPackageNameProperty];
    [plist removeObjectForKey: kCOItemDeprecatedPackageVersionProperty];
    [plist removeObjectForKey: kCOJSONDeprecatedFormatProperty];
    [plist removeObjectForKey: kCOJSONDeprecatedObjectUUIDProperty];
    
    return plist;
}

- (id)JSONPlist
{
    NSMutableDictionary *plistValues = [NSMutableDictionary dictionaryWithCapacity: values.count];

    for (NSString *key in values)
    {
        id plistValue = plistValueForValue(values[key], [types[key] intValue]);
        plistValues[key] = plistValue;
    }

    ETAssert(plistValues[kCOJSONObjectUUIDProperty] == nil);
    plistValues[kCOJSONObjectUUIDProperty] = [self.UUID stringValue];

    ETAssert(plistValues[kCOJSONFormatProperty] == nil);
    plistValues[kCOJSONFormatProperty] = kCOJSONFormat1_0;

    return plistValues;
}

- (instancetype)initWithJSONPlist: (id)aPlist
{
    NSDictionary *plist = migrateInternalKeysFromOldToNewFormat(aPlist);
    ETUUID *aUUID = [ETUUID UUIDWithString: plist[kCOJSONObjectUUIDProperty]];

    NSMutableDictionary *importedValues = [NSMutableDictionary dictionary];
    NSMutableDictionary *importedTypes = [NSMutableDictionary dictionary];

    // Check format
    if (!(plist[kCOJSONFormatProperty] == nil // accept JSON written before format tag was added
          || [plist[kCOJSONFormatProperty] isEqual: kCOJSONFormat1_0]))
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Unknown COItem JSON format '%@'",
                            plist[kCOJSONFormatProperty]];
    }

    for (NSString *key in plist)
    {
        if ([key isEqualToString: kCOJSONObjectUUIDProperty]
            || [key isEqualToString: kCOJSONFormatProperty])
            continue;

        id typeValuePair = plist[key];

        importedValues[key] = importValueFromPlist(typeValuePair);

        importedTypes[key] = @(importTypeFromPlist(typeValuePair));
    }

    self = [self initWithUUID: aUUID
           typesForAttributes: importedTypes
          valuesForAttributes: importedValues];

    return self;
}

- (NSData *)JSONData
{
    id plist = self.JSONPlist;
    return CODataWithJSONObject(plist, NULL);
}

- (instancetype)initWithJSONData: (NSData *)data
{
    id plist = COJSONObjectWithData(data, NULL);
    return [self initWithJSONPlist: plist];
}

@end
