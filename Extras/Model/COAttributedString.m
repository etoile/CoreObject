/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedString.h"
#import "COAttributedStringChunk.h"

@implementation COAttributedString

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"COAttributedString"];
    [entity setParent: (id)@"COObject"];
	
	ETPropertyDescription *chunksProperty = [ETPropertyDescription descriptionWithName: @"chunks"
																				  type: (id)@"COAttributedStringChunk"];
	chunksProperty.multivalued = YES;
	chunksProperty.ordered = YES;
	chunksProperty.persistent = YES;
	
	[entity setPropertyDescriptions: @[chunksProperty]];
    return entity;
}

@dynamic chunks;

- (COItemGraph *) substringItemGraphWithRange: (NSRange)aRange
{
	COItemGraph *result = [[COItemGraph alloc] init];
	
	// FIXME: Implement
	
	return result;
}

- (COAttributedStringChunk *) chunkContainingIndex: (NSUInteger)anIndex chunkStart: (NSUInteger *)chunkStartOut chunkIndex: (NSUInteger *)chunkIndexOut
{
	COAttributedStringChunk *target = nil;
	NSUInteger i = 0, chunkIndex = 0;
	
	for (COAttributedStringChunk *chunk in self.chunks)
	{
		const NSUInteger chunkLen = [chunk.text length];
		if (anIndex >= i && anIndex < (i + chunkLen))
		{
			target = chunk;
			
			if (chunkStartOut != NULL)
			{
				*chunkStartOut = i;
			}
			
			if (chunkIndexOut != NULL)
			{
				*chunkIndexOut = chunkIndex;
			}
			
			break;
		}
		i += chunkLen;
		chunkIndex++;
	}
	
	return target;
}

- (NSUInteger) length
{
	NSUInteger result = 0;
	for (COAttributedStringChunk *chunk in self.chunks)
	{
		result += [chunk.text length];
	}
	return result;
}

@end
