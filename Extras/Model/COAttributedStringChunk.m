/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

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
