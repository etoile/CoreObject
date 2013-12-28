/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedString.h"
#import "COAttributedStringChunk.h"

// FIXME: Hack to get -insertObjects:atIndexes:hints:forProperty:
#import "COObject+Private.h"
#import "COObjectGraphContext+Private.h"
#import "COObjectGraphContext+Graphviz.h"

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
	chunksProperty.opposite = (id)@"Anonymous.COAttributedStringChunk.parentString";
	
	[entity setPropertyDescriptions: @[chunksProperty]];
    return entity;
}

@dynamic chunks;

- (COItemGraph *) substringItemGraphWithRange: (NSRange)aRange
{
	// Copy the receiver into a temporary context
	COObjectGraphContext *tempCtx = [COObjectGraphContext new];
	
	COCopier *copier = [COCopier new];
	ETUUID *copyUUID = [copier copyItemWithUUID: [self UUID] fromGraph: self.objectGraphContext toGraph: tempCtx];
	COAttributedString *tempCopy = [tempCtx loadedObjectForUUID: copyUUID];
	[tempCtx setRootObject: tempCopy];
	
	// Split the copy with the given range
	NSUInteger start = [tempCopy splitChunkAtIndex: aRange.location];
	NSUInteger end = [tempCopy splitChunkAtIndex: aRange.location + aRange.length];
	
	// Remove all chunks outside the requested range.
	tempCopy.chunks = [tempCopy.chunks subarrayWithRange: NSMakeRange(start, end-start)];
	
	[tempCtx removeUnreachableObjects];
	
	COItemGraph *result = [[COItemGraph alloc] initWithItemGraph: tempCtx];
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

- (NSUInteger) splitChunkAtIndex: (NSUInteger)characterIndex
{
	if (characterIndex == [self length])
		return [self.chunks count];
	
	NSUInteger chunkIndex = 0, chunkStart = 0;
	COAttributedStringChunk *chunk = [self chunkContainingIndex: characterIndex chunkStart: &chunkStart chunkIndex: &chunkIndex];
	
	if (characterIndex == chunkStart)
		return chunkIndex;
	
	// We need to split 'chunk'
	
	ETAssert(characterIndex > chunkStart);
	
	NSUInteger leftChunkLength = characterIndex - chunkStart;
	NSString *leftString = [chunk.text substringToIndex: leftChunkLength];
	NSString *rightString = [chunk.text substringFromIndex: leftChunkLength];
	
	// First, trim 'chunk' down to the point where we are splitting it
	
	chunk.text = leftString;
	
	// Create a new chunk for the right side, copying from the left side so we also copy the
	// attributes.
	// FIXME: Since attributes aren't referred to with a composite rel'n, currently
	// they are being aliased and not copied.
	
	COCopier *copier = [COCopier new];
	ETUUID *rightChunkUUID = [copier copyItemWithUUID: [chunk UUID] fromGraph: self.objectGraphContext toGraph: self.objectGraphContext];
	COAttributedStringChunk *rightChunk = [self.objectGraphContext loadedObjectForUUID: rightChunkUUID];
	rightChunk.text = rightString;
	
	// Insert rightChunk
	
	[self insertObjects: @[rightChunk]
			  atIndexes: [[NSIndexSet alloc] initWithIndex: chunkIndex + 1]
				  hints: nil
			forProperty: @"chunks"];
	
	return chunkIndex + 1;
}

@end
