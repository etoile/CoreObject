/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COSetAttribute.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSetAttribute

@synthesize type;
@synthesize value;

- (BOOL) isEqualIgnoringSourceIdentifier: (id)other
{
    return [super isEqualIgnoringSourceIdentifier: other]
    &&  type == ((COSetAttribute*)other).type
    &&  [value isEqual: ((COSetAttribute*)other).value];
}

- (NSUInteger) hash
{
    return 4265092495078449026ULL ^ super.hash ^ type ^ [value hash];
}

- (instancetype) initWithUUID: (ETUUID *)aUUID
                    attribute: (NSString *)anAttribute
             sourceIdentifier: (id)aSourceIdentifier
                         type: (COType)aType
                        value: (id)aValue
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(anAttribute);
    NILARG_EXCEPTION_TEST(aValue);

    self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier];
    if (self == nil)
        return nil;

    type = aType;
    value = [aValue copy];
    return self;
}

- (instancetype) initWithUUID: (ETUUID *)aUUID
                    attribute: (NSString *)anAttribute
             sourceIdentifier: (id)aSourceIdentifier
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                         type: kCOTypeString
                        value: nil];
}

- (instancetype)init
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                         type: kCOTypeString
                        value: nil];
}


- (NSString *) description
{
    return [NSString stringWithFormat: @"set %@.%@ = %@ (%@)", UUID, attribute, value, sourceIdentifier];
}

- (NSSet *) insertedInnerItemUUIDs
{
    if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
    {
        if (COTypeIsUnivalued(type))
        {
            return [NSSet setWithObject: value];
        }
        else
        {
            if (COTypeIsOrdered(type))
            {
                return [NSSet setWithArray: value];
            }
            else
            {
                return [NSSet setWithSet: value];
            }
        }
    }
    else
    {
        return [NSSet set];
    }
}

@end
