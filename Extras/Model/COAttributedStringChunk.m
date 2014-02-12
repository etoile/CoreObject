/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedStringChunk.h"
#import "COAttributedStringAttribute.h"
#import "COAttributedString.h"

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
	
	entity.diffAlgorithm = @"COAttributedStringDiff";
	
    return entity;
}
@dynamic text, attributes, parentString;

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

- (NSUInteger) length
{
	return [self.text length];
}

- (NSString *) attributesDebugDescription
{
	return [[self.attributes mappedCollectionWithBlock: ^(id anObj) {
		COAttributedStringAttribute *attr = anObj;
		return [NSString stringWithFormat: @"%@=%@", attr.styleKey, attr.styleValue];
	}] componentsJoinedByString: @","];
}

- (NSUInteger) characterIndex
{
	NSUInteger i = 0;
	
	for (COAttributedStringChunk *chunk in self.parentString.chunks)
	{
		if (chunk == self)
			return i;
		else
			i += chunk.length;
	}
	return NSUIntegerMax;
}

- (NSRange) characterRange
{
	return NSMakeRange([self characterIndex], [self length]);
}

- (NSString *) description
{
	NSMutableString *result = [NSMutableString new];
	if ([self.attributes count] == 0)
	{
		[result appendFormat: @"<span>%@</span>", self.text];
	}
	else
	{
		NSArray *attrs = [[self.attributes allObjects] sortedArrayUsingDescriptors:
						  @[[NSSortDescriptor sortDescriptorWithKey: @"htmlCode" ascending: YES]]];
		for (COAttributedStringAttribute *attr in attrs)
		{
			[result appendFormat: @"<%@>", attr];
		}
		[result appendFormat: @"%@", self.text];
		for (COAttributedStringAttribute *attr in attrs)
		{
			[result appendFormat: @"</%@>", attr];
		}
	}
	return result;
}

@end
