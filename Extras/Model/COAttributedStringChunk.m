#import "COAttributedStringChunk.h"

@implementation COAttributedStringChunk
+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"COAttributedStringChunk"];
    [entity setParent: (id)@"COObject"];
	
	ETPropertyDescription *textProperty = [ETPropertyDescription descriptionWithName: @"text"
																				 type: (id)@"NSString"];
	textProperty.persistent = YES;
	
	ETPropertyDescription *htmlCodeProperty = [ETPropertyDescription descriptionWithName: @"htmlCode"
																					type: (id)@"NSString"];
	htmlCodeProperty.persistent = YES;
	
	[entity setPropertyDescriptions: @[textProperty, htmlCodeProperty]];
    return entity;
}
@dynamic text, htmlCode;
@end
