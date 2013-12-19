/*
	Copyright (C) 2013 Eric Wasylishen

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
	
	ETPropertyDescription *attributesProperty = [ETPropertyDescription descriptionWithName: @"attributes"
																					  type: (id)@"COAttributedStringAttribute"];
	attributesProperty.multivalued = YES;
	attributesProperty.persistent = YES;
	
	[entity setPropertyDescriptions: @[textProperty, attributesProperty]];
    return entity;
}
@dynamic text, attributes;
@end
