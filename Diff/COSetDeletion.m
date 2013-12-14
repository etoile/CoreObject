/*
	Copyright (C) 2012 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import "COSetDeletion.h"

@implementation COSetDeletion

- (NSUInteger) hash
{
	return 1310827214389984141ULL ^ [super hash];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"delete from set %@.%@ value %@ (%@)", UUID, attribute, object, sourceIdentifier];
}

- (NSSet *) insertedInnerItemUUIDs
{
	return [NSSet set];
}

@end