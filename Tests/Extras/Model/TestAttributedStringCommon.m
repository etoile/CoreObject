#import "TestAttributedStringCommon.h"

@implementation TestAttributedStringCommon

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)ctx
{
	COAttributedStringAttribute *attribute = [ctx insertObjectWithEntityName: @"COAttributedStringAttribute"];
	attribute.htmlCode = htmlCode;
	return attribute;
}

- (COObjectGraphContext *) makeAttributedString
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COAttributedString *ctx1String = [ctx1 insertObjectWithEntityName: @"COAttributedString"];
	ctx1.rootObject = ctx1String;
	return ctx1;
}

- (void) appendString: (NSString *)string htmlCode: (NSString *)aCode toAttributedString: (COAttributedString *)dest
{
	COObjectGraphContext *ctx = [dest objectGraphContext];
	COAttributedStringChunk *chunk = [ctx insertObjectWithEntityName: @"COAttributedStringChunk"];
	chunk.text = string;
	
	if (aCode != nil)
	{
		chunk.attributes = S([self makeAttr: aCode inCtx: ctx]);
	}
	
	[dest insertObject: chunk atIndex: ETUndeterminedIndex hint: nil forProperty: @"chunks"];
}

@end
