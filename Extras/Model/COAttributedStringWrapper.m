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
	COAttributedStringChunk *target = nil;
	
	{
		NSUInteger i = 0;
		for (COAttributedStringChunk *chunk in _backing.chunks)
		{
			NSUInteger chunkLen = [chunk.text length];
			if (anIndex >= i && anIndex < (i + chunkLen))
			{
				target = chunk;
				
				if (aRangeOut != NULL)
				{
					*aRangeOut = NSMakeRange(i, chunkLen);
				}
				
				break;
			}
			i += chunkLen;
		}
	}
	
	if (target != nil)
	{
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
		}
		
		result[NSFontAttributeName] = font;
		
		return result;
	}
	
	return nil;
}

// Primitive NSMutableAttributedString methods

- (void)replaceCharactersInRange: (NSRange)aRange withString: (NSString *)aString
{
	
}
- (void)setAttributes: (NSDictionary *)aDict range: (NSRange)aRange
{
	
}

@end
