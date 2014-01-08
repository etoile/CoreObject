#import "TestAttributedStringCommon.h"

@implementation TestAttributedStringCommon

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

- (COObjectGraphContext *) makeAttributedString
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COAttributedString *ctx1String = [[COAttributedString alloc] initWithObjectGraphContext: ctx1];
	ctx1.rootObject = ctx1String;
	return ctx1;
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
	
	[dest insertObject: chunk atIndex: ETUndeterminedIndex hint: nil forProperty: @"chunks"];
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

@end
