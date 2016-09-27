/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COSetInsertion.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSetInsertion

@synthesize type;
@synthesize object;

- (instancetype)initWithUUID: (ETUUID *)aUUID
                   attribute: (NSString *)anAttribute
            sourceIdentifier: (id)aSourceIdentifier
                        type: (COType)aType
                      object: (id)anObject
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(anAttribute);
    NILARG_EXCEPTION_TEST(anObject);

    self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier];
    if (self == nil)
        return nil;

    type = aType;
    object = [anObject copy];
    return self;
}

- (instancetype)initWithUUID: (ETUUID *)aUUID
                   attribute: (NSString *)anAttribute
            sourceIdentifier: (id)aSourceIdentifier
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                         type: kCOTypeString
                       object: nil];
}

- (instancetype)init
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                         type: kCOTypeString
                       object: nil];
}

- (BOOL)isEqualIgnoringSourceIdentifier: (id)other
{
    return [super isEqualIgnoringSourceIdentifier: other]
           && type == ((COSetInsertion *)other).type
           && [object isEqual: ((COSetInsertion *)other).object];
}

- (NSUInteger)hash
{
    return 595258568559201742ULL ^ super.hash ^ type ^ [object hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"insert into set %@.%@ value %@ (%@)",
                                       UUID,
                                       attribute,
                                       object,
                                       sourceIdentifier];
}

- (NSSet *)insertedInnerItemUUIDs
{
    if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
    {
        return [NSSet setWithObject: object];
    }
    else
    {
        return [NSSet set];
    }
}

- (BOOL)isSameKindOfEdit: (COItemGraphEdit *)anEdit
{
    return [anEdit isKindOfClass: [COSetInsertion class]]; // COSetDeletion is a subclass
}

@end
