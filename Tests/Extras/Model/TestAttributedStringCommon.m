#import "TestAttributedStringCommon.h"

@implementation TestAttributedStringCommon

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)ctx
{
	COAttributedStringAttribute *attribute = [ctx insertObjectWithEntityName: @"COAttributedStringAttribute"];
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
	COAttributedString *ctx1String = [ctx1 insertObjectWithEntityName: @"COAttributedString"];
	ctx1.rootObject = ctx1String;
	return ctx1;
}

- (void) appendString: (NSString *)string htmlCodes: (NSArray *)codes toAttributedString: (COAttributedString *)dest
{
	COObjectGraphContext *ctx = [dest objectGraphContext];
	COAttributedStringChunk *chunk = [ctx insertObjectWithEntityName: @"COAttributedStringChunk"];
	chunk.text = string;
	
	for (NSString *code in codes)
	{
		[self addHtmlCode: code toChunk: chunk];
	}
	
	[dest insertObject: chunk atIndex: ETUndeterminedIndex hint: nil forProperty: @"chunks"];
}

- (void) appendString: (NSString *)string htmlCode: (NSString *)aCode toAttributedString: (COAttributedString *)dest
{
	[self appendString: string htmlCodes: (aCode == nil ? @[] : @[aCode]) toAttributedString: dest];
}

@end
