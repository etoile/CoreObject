/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COSequenceInsertion.h"

@implementation COSequenceInsertion

- (instancetype) initWithUUID: (ETUUID *)aUUID
                    attribute: (NSString *)anAttribute
             sourceIdentifier: (id)aSourceIdentifier
                     location: (NSUInteger)aLocation
                         type: (COType)aType
                      objects: (NSArray *)anArray
{
    return [super initWithUUID: aUUID
                     attribute: anAttribute
              sourceIdentifier: aSourceIdentifier
                         range: NSMakeRange(aLocation, 0)
                          type: aType
                       objects: anArray];
}

- (instancetype) initWithUUID: (ETUUID *)aUUID
                    attribute: (NSString *)anAttribute
             sourceIdentifier: (id)aSourceIdentifier
                        range: (NSRange)aRange
                         type: (COType)aType
                      objects: (NSArray *)anArray
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

- (NSUInteger) hash
{
    return 14584168390782580871ULL ^ super.hash;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"insert at %@.%@[%d] value %@ (%@)", UUID, attribute, (int)range.location, objects, sourceIdentifier];
}

@end
