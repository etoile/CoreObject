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
	
	ETPropertyDescription *parentStringProperty = [ETPropertyDescription descriptionWithName: @"parentString"
																						type: (id)@"COAttributedString"];
	parentStringProperty.multivalued = NO;
	parentStringProperty.derived = YES;
	parentStringProperty.opposite = (id)@"Anonymous.COAttributedString.chunks";
	
	[entity setPropertyDescriptions: @[textProperty, attributesProperty, parentStringProperty]];
    return entity;
}
@dynamic text, attributes;

- (COItemGraph *) subchunkItemGraphWithRange: (NSRange)aRange
{
	COItemGraph *result = [[COItemGraph alloc] init];
	COCopier *copier = [[COCopier alloc] init];
	
	ETUUID *copyRootUUID = [copier copyItemWithUUID: self.UUID fromGraph: self.objectGraphContext toGraph: result];
	result.rootItemUUID = copyRootUUID;
	
	COMutableItem *chunkCopy = [result itemForUUID: copyRootUUID];
	[chunkCopy setValue: [self.text substringWithRange: aRange]
		   forAttribute: @"text"];
	
	return result;
}

@end
