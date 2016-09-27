/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COSequenceModification.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSequenceModification

@synthesize type;
@synthesize objects;

- (instancetype)initWithUUID: (ETUUID *)aUUID
                   attribute: (NSString *)anAttribute
            sourceIdentifier: (id)aSourceIdentifier
                       range: (NSRange)aRange
                        type: (COType)aType
                     objects: (NSArray *)anArray
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(anAttribute);
    NILARG_EXCEPTION_TEST(anArray);

    self = [super initWithUUID: aUUID
                     attribute: anAttribute
              sourceIdentifier: aSourceIdentifier
                         range: aRange];
    if (self == nil)
        return nil;

    type = aType;
    objects = [[NSArray alloc] initWithArray: anArray copyItems: YES];
    return self;
}

- (instancetype)initWithUUID: (ETUUID *)aUUID
                   attribute: (NSString *)anAttribute
            sourceIdentifier: (id)aSourceIdentifier
                       range: (NSRange)aRange
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                        range: NSMakeRange(0, 0)
                         type: kCOTypeString
                      objects: nil];
}

- (instancetype)init
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                        range: NSMakeRange(0, 0)
                         type: kCOTypeString
                      objects: nil];
}

- (BOOL)isEqualIgnoringSourceIdentifier: (id)other
{
    return [super isEqualIgnoringSourceIdentifier: other]
           && type == ((COSequenceModification *)other).type
           && [objects isEqual: ((COSequenceModification *)other).objects];
}

- (NSUInteger)hash
{
    return 11773746616539821587ULL ^ super.hash ^ type ^ objects.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"replace %@.%@[%d:%d] with %@ (%@)",
                                       UUID,
                                       attribute,
                                       (int)range.location,
                                       (int)range.length,
                                       objects,
                                       sourceIdentifier];
}

- (NSSet *)insertedInnerItemUUIDs
{
    if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
    {
        return [NSSet setWithArray: objects];
    }
    else
    {
        return [NSSet set];
    }
}

@end
