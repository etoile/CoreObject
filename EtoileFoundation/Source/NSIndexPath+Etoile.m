/*
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  September 2007
	License:  Modified BSD (see COPYING)
 */
 
#import "NSIndexPath+Etoile.h"
#import "Macros.h"
#import "EtoileCompatibility.h"

@implementation NSIndexPath (Etoile)

/** Returns a new autoreleased empty index path. */
+ (NSIndexPath *) indexPath
{
	return AUTORELEASE([[NSIndexPath alloc] init]);
}

/** Returns the first path component in the index path. */
- (unsigned int) firstIndex
{
	return [self indexAtPosition: 0];
}

/** Returns the last path component in the index path. */
- (unsigned int) lastIndex
{
	return [self indexAtPosition: [self length] - 1];
}

/** Returns a new autoreleased index path by removing the first path component. */
- (NSIndexPath *) indexPathByRemovingFirstIndex
{
	/*unsigned int *indexes = NSZoneMalloc(NSDefaultMallocZone(), sizeof(unsigned int) * [self length]);
	unsigned int *buffer = NSZoneMalloc(NSDefaultMallocZone(), sizeof(unsigned int) * ([self length] - 1));*/
	NSUInteger *indexes = calloc(sizeof(unsigned int), [self length]);
	NSUInteger *buffer = calloc(sizeof(unsigned int), [self length] - 1);
	
	[self getIndexes: indexes];
	buffer = memcpy(buffer, &indexes[1], sizeof(unsigned int) * ([self length] -1));
	//NSZoneFree(NSDefaultMallocZone(), indexes);
	free(indexes);
	NSIndexPath *thePath = [NSIndexPath indexPathWithIndexes: buffer
	                                                  length: [self length] - 1];
	free(buffer);
	return thePath;
}

/** Returns an autoreleased string representation by joining each index path 
component with the given separator.

e.g. '5/6/7' with '/' as separator or '5.6.7' with '.' as separator.

Will raise an NSInvalidArgumentException if the separator is nil. */
- (NSString *) stringByJoiningIndexPathWithSeparator: (NSString *)separator
{
	NILARG_EXCEPTION_TEST(separator);

	if ([self length] == 0)
		return @"";

	NSString *path = [NSString stringWithFormat: @"%lu", [self firstIndex]];
	int indexCount = [self length];
	
	for (int i = 1; i < indexCount; i++)
	{
		path = [path stringByAppendingString: 
			[NSString stringWithFormat: @"%@%lu", separator, [self indexAtPosition: i]]];
	}
	
	return path;
}

/** Returns a string representation of the receiver which can be used as a key
path. 

Take note that KVC as implemented by Foundation collection classes such as 
NSArray doesn't support to look up elements with a key like '5' or a key path 
like '6.name'. -valueForKey: and -valueForKeyPath: would try to lookup 5 and 6 
as ivar or method names. */
- (NSString *) keyPath
{
	return [self stringByJoiningIndexPathWithSeparator: @"."];
}

@end
