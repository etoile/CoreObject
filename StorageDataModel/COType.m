#import "COType.h"

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