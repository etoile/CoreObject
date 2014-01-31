#import "TestAttributedStringCommon.h"

@implementation EditingContextTestCase (TestAttributedStringCommon)

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)graph
{
	COAttributedStringAttribute *attribute = [graph insertObjectWithEntityName: @"COAttributedStringAttribute"];
	attribute.htmlCode = htmlCode;
	return attribute;
}

- (void) addHtmlCode: (NSString *)code toChunk: (COAttributedStringChunk *)aChunk
{
	COAttributedStringAttribute *attr = [self makeAttr: code inCtx: aChunk.objectGraphContext];
	[aChunk insertObject: attr atIndex: ETUndeterminedIndex hint: nil forProperty: @"attributes"];
}

- (COObjectGraphContext *) makeAttributedStringWithUUID: (ETUUID *)uuid
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COAttributedString *ctx1String = [[COAttributedString alloc] prepareWithUUID: uuid
															   entityDescription: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"COAttributedString"]
															  objectGraphContext: ctx1
																		   isNew: YES];
	ctx1.rootObject = ctx1String;
	return ctx1;
}

- (COObjectGraphContext *) makeAttributedString
{
	static ETUUID *uuid;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		uuid = [ETUUID new];
	});
	
	return [self makeAttributedStringWithUUID: uuid];
}

- (COObjectGraphContext *) makeAttributedString2
{
	static ETUUID *uuid;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		uuid = [ETUUID new];
	});
	
	return [self makeAttributedStringWithUUID: uuid];
}

- (COObjectGraphContext *) makeAttributedStringWithHTML: (NSString *)html
{
	COObjectGraphContext *result = [self makeAttributedString];
	[self appendHTMLString: html toAttributedString: [result rootObject]];
	return result;
}

- (COObjectGraphContext *) makeAttributedString2WithHTML: (NSString *)html
{
	COObjectGraphContext *result = [self makeAttributedString2];
	[self appendHTMLString: html toAttributedString: [result rootObject]];
	return result;
}

- (void) clearAttributedString: (COAttributedString *)dest
{
	dest.chunks = @[];
}

- (COAttributedStringChunk *) appendString: (NSString *)string htmlCodes: (NSArray *)codes toAttributedString: (COAttributedString *)dest
{
	COObjectGraphContext *graph = [dest objectGraphContext];
	COAttributedStringChunk *chunk = [graph insertObjectWithEntityName: @"COAttributedStringChunk"];
	chunk.text = string;
	
	for (NSString *code in codes)
	{
		[self addHtmlCode: code toChunk: chunk];
	}
	
	[[dest mutableArrayValueForKey: @"chunks"] addObject: chunk];
	return chunk;
}

- (COAttributedStringChunk *) appendString: (NSString *)string htmlCode: (NSString *)aCode toAttributedString: (COAttributedString *)dest
{
	return [self appendString: string htmlCodes: (aCode == nil ? @[] : @[aCode]) toAttributedString: dest];
}

- (void) checkAttribute: (NSString *)attributeName hasValue: (id)expectedValue withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target
{
	NSRange actualRange;
	id actualValue = [target attribute: attributeName
							   atIndex: expectedRange.location
				 longestEffectiveRange: &actualRange
							   inRange: NSMakeRange(0, [target length])];
	
	if (expectedValue == nil)
	{
		UKNil(actualValue);
	}
	else
	{
		UKObjectsEqual(expectedValue, actualValue);
	}
	
	UKIntsEqual(expectedRange.location, actualRange.location);
	UKIntsEqual(expectedRange.length, actualRange.length);
}

- (void) checkFontHasTraits: (NSFontSymbolicTraits)traits withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target
{
	NSRange actualRange;
	NSFont *actualFont = [target attribute: NSFontAttributeName
								   atIndex: expectedRange.location
					 longestEffectiveRange: &actualRange
								   inRange: NSMakeRange(0, [target length])];
	
	NSFontSymbolicTraits actualTraits = [[actualFont fontDescriptor] symbolicTraits];
	
	UKTrue((actualTraits & traits) == traits);
	
	UKIntsEqual(expectedRange.location, actualRange.location);
	UKIntsEqual(expectedRange.length, actualRange.length);
}

- (void) setFontTraits: (NSFontSymbolicTraits)traits inRange: (NSRange)aRange inTextStorage: (NSTextStorage *)target
{
	NSFont *font = [[NSFontManager sharedFontManager] convertFont: [NSFont userFontOfSize: 12] toHaveTrait: traits];
	[target addAttribute: NSFontAttributeName
				   value: font
				   range: aRange];
}

- (void) appendHTMLString: (NSString *)html toAttributedString: (COAttributedString *)dest
{
	NSUInteger len = [html length];
	
	NSMutableSet *attributes = [NSMutableSet new];
	BOOL inAngleBrackets = NO;
	BOOL isRemoving = NO;
	NSMutableString *htmlCode = [NSMutableString new];
	NSMutableString *text = [NSMutableString new];
	
	for (NSUInteger i = 0; i < len; i++)
	{
		NSString *character = [html substringWithRange: NSMakeRange(i, 1)];
		if (inAngleBrackets)
		{
			if ([character isEqualToString: @"/"])
			{
				isRemoving = YES;
			}
			else if ([character isEqualToString: @">"])
			{
				NSString *htmlCodeCopy = [NSString stringWithString: [htmlCode lowercaseString]];
				if (isRemoving)
				{
					[attributes removeObject: htmlCodeCopy];
				}
				else
				{
					[attributes addObject: htmlCodeCopy];
				}
				
				inAngleBrackets = NO;
				isRemoving = NO;
				[htmlCode setString: @""];
			}
			else
			{
				[htmlCode appendString: character];
			}
		}
		else
		{
			if ([character isEqualToString: @"<"])
			{
				if ([text length] > 0)
					[self appendString: [NSString stringWithString: text] htmlCodes: [attributes allObjects] toAttributedString: dest];
				
				inAngleBrackets = YES;
				[text setString: @""];
			}
			else
			{
				[text appendString: character];
			}
		}
	}
	
	if ([text length] > 0)
		[self appendString: [NSString stringWithString: text] htmlCodes: [attributes allObjects] toAttributedString: dest];
}

- (void) checkMergingBase: (NSString *)base
			  withBranchA: (NSString *)branchA
			  withBranchB: (NSString *)branchB
					gives: (NSString *)result
{
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendHTMLString: base toAttributedString: [ctx1 rootObject]];
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	[self clearAttributedString: [ctx2 rootObject]];
	[self appendHTMLString: branchA toAttributedString: [ctx2 rootObject]];
	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	[self clearAttributedString: [ctx3 rootObject]];
	[self appendHTMLString: branchB toAttributedString: [ctx3 rootObject]];
	
	COAttributedStringDiff *diffA = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																		   secondAttributedString: [ctx2 rootObject]
																						   source: @"branchA"];
	
    COAttributedStringDiff *diffB = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																		   secondAttributedString: [ctx3 rootObject]
																						   source: @"branchB"];
	
	COAttributedStringDiff *diffMerged = [diffA diffByMergingWithDiff: diffB];
	
	COObjectGraphContext *destCtx = [COObjectGraphContext new];
	[destCtx setItemGraph: ctx1];
	
	[diffMerged applyToAttributedString: [destCtx rootObject]];
	
	
	COObjectGraphContext *expectedCtx = [COObjectGraphContext new];
	[expectedCtx setItemGraph: ctx1];
	[self clearAttributedString: [expectedCtx rootObject]];
	[self appendHTMLString: result toAttributedString: [expectedCtx rootObject]];
	
	
	COAttributedStringWrapper *actualWrapper = [[COAttributedStringWrapper alloc] initWithBacking: [destCtx rootObject]];
	COAttributedStringWrapper *expectedWrapper = [[COAttributedStringWrapper alloc] initWithBacking: [expectedCtx rootObject]];
	
	UKObjectsEqual(expectedWrapper, actualWrapper);
}

@end
