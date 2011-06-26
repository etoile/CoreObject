/*
	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  August 2007
	License:  Modified BSD (see COPYING)
 */
 
#import "NSIndexSet+Etoile.h"

@implementation NSIndexSet (Etoile)

/** Returns an array of index paths by creating a new index path for each index
stored in the receiver. 

Each resulting index path only contains a single index. */
- (NSArray *) indexPaths
{
	NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: [self count]];
	/* Will set lastIndex to 0 or NSNotFound */
	unsigned int lastIndex = [self indexGreaterThanOrEqualToIndex: 0];

	if (lastIndex == NSNotFound)
		return nil;

	do
	{
		[indexPaths addObject: [NSIndexPath indexPathWithIndex: lastIndex]];
	} while ((lastIndex = [self indexGreaterThanIndex: lastIndex]) != NSNotFound);
	
	return indexPaths;
}

@end


@implementation NSMutableIndexSet (Etoile)

/** Inverts whether an index is present or not in the index set.

If the receiver contains index, this index gets removed, else this index gets added. */
- (void) invertIndex: (unsigned int)index
{
	if ([self containsIndex: index])
	{
		[self removeIndex: index];
	}
	else
	{
		[self addIndex: index];
	}
}

@end
