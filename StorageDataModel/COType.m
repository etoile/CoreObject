#import "COType.h"
#import <EtoileFoundation/ETUUID.h>
#import "COPath.h"

static NSString *
COTypeMultivalueDescription(COType type)
{
    if (COTypeIsMultivalued(type))
    {
        if (COTypeIsOrdered(type))
        {
            return @"kCOTypeArray | ";
        }
        else
        {
            return @"kCOTypeSet | ";
        }
    }
    return @"";
}

static NSString *
COTypePrimitiveDescription(COType type)
{
    switch (COTypePrimitivePart(type))
    {
        case kCOTypeInt64: return @"kCOTypeInt64";
        case kCOTypeDouble: return @"kCOTypeDouble";
        case kCOTypeString: return @"kCOTypeString";
        case kCOTypeBlob: return @"kCOTypeBlob";
        case kCOTypeReference: return @"kCOTypeReference";
        case kCOTypeCompositeReference: return @"kCOTypeCompositeReference";
        case kCOTypeAttachment: return @"kCOTypeAttachment";
    }
    return @"";
}


NSString *
COTypeDescription(COType type)
{
    if (!COTypeIsValid(type))
    {
        return @"invalid type";
    }
    
    return [COTypeMultivalueDescription(type) stringByAppendingString: COTypePrimitiveDescription(type)];
}


BOOL
COTypePrimitiveValidateObject(COType type, id anObject)
{
    switch (COTypePrimitivePart(type))
    {
        case kCOTypeInt64:
        case kCOTypeDouble: return [anObject isKindOfClass: [NSNumber class]]
            || anObject == [NSNull null];
        case kCOTypeString: return [anObject isKindOfClass: [NSString class]]
            || anObject == [NSNull null];
        case kCOTypeBlob: return [anObject isKindOfClass: [NSData class]]
            || anObject == [NSNull null];
        case kCOTypeReference:
        case kCOTypeCompositeReference: return [anObject isKindOfClass: [ETUUID class]]
            || [anObject isKindOfClass: [COPath class]]
            || anObject == [NSNull null];
        case kCOTypeAttachment: return [anObject isKindOfClass: [NSData class]]
            || anObject == [NSNull null];
    }
    return NO;
}


BOOL
COTypeValidateObject(COType type, id anObject)
{
    if (!COTypeIsValid(type))
    {
        return NO;
    }
    
    if (COTypeIsMultivalued(type))
    {
        if (![anObject isKindOfClass: COTypeIsOrdered(type) ? [NSArray class] : [NSSet class]])
        {
            return NO;
        }

        for (id primitive in anObject)
        {
            if (!COTypePrimitiveValidateObject(type, primitive))
            {
                return NO;
            }
        }
        return YES;
    }
    
    if (!COTypePrimitiveValidateObject(type, anObject))
    {
        return NO;
    }
    return YES;
}