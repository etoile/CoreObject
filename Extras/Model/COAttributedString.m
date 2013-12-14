/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedString.h"

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
	
	[entity setPropertyDescriptions: @[chunksProperty]];
    return entity;
}

@dynamic chunks;
@end
