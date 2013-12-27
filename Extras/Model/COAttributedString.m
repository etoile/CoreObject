/*
	Copyright (C) 2013 Eric Wasylishen

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

- (COItemGraph *) substringItemGraphWithRange: (NSRange)aRange
{
	COItemGraph *result = [[COItemGraph alloc] init];
	
	// FIXME: Implement
	
	return result;
}

@end
