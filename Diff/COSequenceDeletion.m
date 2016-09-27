/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COSequenceDeletion.h"

@implementation COSequenceDeletion

- (NSUInteger)hash
{
    return 17441750424377234775ULL ^ super.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"delete range %@.%@[%d:%d] (%@)",
                                       UUID,
                                       attribute,
                                       (int)range.location,
                                       (int)range.length,
                                       sourceIdentifier];
}

@end
