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
            return @"kCOArrayType | ";
        }
        else
        {
            return @"kCOSetType | ";
        }
    }
    return @"";
}

static NSString *
COTypePrimitiveDescription(COType type)
{
    switch (COPrimitiveType(type))
    {
        case kCOInt64Type: return @"kCOInt64Type";
        case kCODoubleType: return @"kCODoubleType";
        case kCOStringType: return @"kCOStringType";
        case kCOBlobType: return @"kCOBlobType";
        case kCOReferenceType: return @"kCOReferenceType";
        case kCOCompositeReferenceType: return @"kCOCompositeReferenceType";
        case kCOAttachmentType: return @"kCOAttachmentType";
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
    switch (COPrimitiveType(type))
    {
        case kCOInt64Type:
        case kCODoubleType: return [anObject isKindOfClass: [NSNumber class]]
            || anObject == [NSNull null];
        case kCOStringType: return [anObject isKindOfClass: [NSString class]]
            || anObject == [NSNull null];
        case kCOBlobType: return [anObject isKindOfClass: [NSData class]]
            || anObject == [NSNull null];
        case kCOReferenceType:
        case kCOCompositeReferenceType: return [anObject isKindOfClass: [ETUUID class]]
            || [anObject isKindOfClass: [COPath class]]
            || anObject == [NSNull null];
        case kCOAttachmentType: return [anObject isKindOfClass: [NSData class]]
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