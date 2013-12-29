/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedStringWrapper.h"
#import "COAttributedString.h"
#import "COAttributedStringChunk.h"
#import "COAttributedStringAttribute.h"

@interface COAttributedStringWrapper ()

@end

@implementation COAttributedStringWrapper

@synthesize backing = _backing;

- (instancetype) initWithBacking: (COAttributedString *)aBacking
{
	SUPERINIT;
	self.backing = aBacking;
	return self;
}

// Primitive NSAttributedString methods

- (NSString *)string
{
	NSMutableString *result = [NSMutableString new];
	for (COAttributedStringChunk *chunk in _backing.chunks)
	{
		[result appendString: chunk.text];
	}
	return result;
}

- (NSDictionary *)attributesAtIndex: (NSUInteger)anIndex effectiveRange: (NSRangePointer)aRangeOut
{
	NSUInteger chunkIndex = 0, chunkStart = 0;
	COAttributedStringChunk *target = [self.backing chunkContainingIndex: anIndex chunkStart: &chunkStart chunkIndex: &chunkIndex];
	
	if (target != nil)
	{
		if (aRangeOut != NULL)
		{
			*aRangeOut = NSMakeRange(chunkStart, target.length);
		}
		
		NSMutableDictionary *result = [NSMutableDictionary new];
		
		NSFont *font = [NSFont userFontOfSize: 12];
		
		for (COAttributedStringAttribute *attr in target.attributes)
		{
			if ([attr.htmlCode isEqualToString: @"b"])
			{
				font = [[NSFontManager sharedFontManager] convertFont: font toHaveTrait: NSFontBoldTrait];
			}
			if ([attr.htmlCode isEqualToString: @"i"])
			{
				font = [[NSFontManager sharedFontManager] convertFont: font toHaveTrait: NSFontItalicTrait];
			}
			if ([attr.htmlCode isEqualToString: @"u"])
			{
				result[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
			}
		}
		
		result[NSFontAttributeName] = font;
		
		return result;
	}
	
	return nil;
}

// Primitive NSMutableAttributedString methods

- (void)replaceCharactersInRange: (NSRange)aRange withString: (NSString *)aString
{
	NSUInteger chunkIndex = 0, chunkStart = 0;
	COAttributedStringChunk *chunk = [_backing chunkContainingIndex: aRange.location chunkStart: &chunkStart chunkIndex: &chunkIndex];
	const NSUInteger chunkLength = [[chunk text] length];
	
	const NSUInteger indexInChunk = aRange.location - chunkStart;
	NSUInteger lengthInChunkToReplace = aRange.length;
	if (indexInChunk + lengthInChunkToReplace > chunkLength)
	{
		lengthInChunkToReplace = chunkLength - indexInChunk;
	}
	
	NSString *newText = [chunk.text stringByReplacingCharactersInRange: NSMakeRange(indexInChunk, lengthInChunkToReplace) withString: aString];
	chunk.text = newText;
	
	NSUInteger remainingLengthToDelete = aRange.length - lengthInChunkToReplace;
	
	while (remainingLengthToDelete > 0)
	{
		// Scan forward through the following chunks, trimming text as needed

		chunk = _backing.chunks[++chunkIndex];

		lengthInChunkToReplace = MIN([[chunk text] length], remainingLengthToDelete);
		chunk.text = [chunk.text stringByReplacingCharactersInRange: NSMakeRange(0, lengthInChunkToReplace) withString: @""];
		remainingLengthToDelete -= lengthInChunkToReplace;
	}
}

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode
{
	COAttributedStringAttribute *attribute = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: [_backing objectGraphContext]];
	attribute.htmlCode = htmlCode;
	return attribute;
}

- (void)setAttributes:(NSDictionary *)attrs forChunk: (COAttributedStringChunk *)aChunk
{
	NSMutableSet *newAttribs = [NSMutableSet new];
	
	for (NSString *attributeName in attrs)
	{
		id attributeValue = attrs[attributeName];
		
		if ([attributeName isEqual: NSUnderlineStyleAttributeName] && [attributeValue isEqual: @(NSUnderlineStyleSingle)])
		{
			[newAttribs addObject: [self makeAttr: @"u"]];
		}
		else if ([attributeName isEqual: NSFontAttributeName])
		{
			NSFont *font = attributeValue;
			NSFontSymbolicTraits traits = [[font fontDescriptor] symbolicTraits];
			if ((traits & NSFontBoldTrait) == NSFontBoldTrait)
			{
				[newAttribs addObject: [self makeAttr: @"b"]];
			}
			if ((traits & NSFontItalicTrait) == NSFontItalicTrait)
			{
				[newAttribs addObject: [self makeAttr: @"i"]];
			}
		}
	}
	
	aChunk.attributes = newAttribs;
}

- (void)setAttributes: (NSDictionary *)aDict range: (NSRange)aRange
{
	if (aRange.length == 0)
	{
		return;
	}
	
	// TODO: We could avoid splitting if the given range already has exactly
	// the right attributes
	
	const NSUInteger splitChunk1 = [_backing splitChunkAtIndex: aRange.location];
	const NSUInteger splitChunk2 = [_backing splitChunkAtIndex: NSMaxRange(aRange)];
	
	ETAssert(splitChunk2 > splitChunk1);
	
	// Set all chunks from splitChunk1, up to but not including splitChunk2, to
	// have the attributes in aDict
	
	for (NSUInteger i = splitChunk1; i < splitChunk2; i++)
	{
		COAttributedStringChunk *chunk = _backing.chunks[i];
		[self setAttributes: aDict forChunk: chunk];
	}
}

@end
