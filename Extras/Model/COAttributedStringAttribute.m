/*
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "COAttributedStringAttribute.h"

@implementation COAttributedStringAttribute

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"COAttributedStringAttribute"];
    [entity setParent: (id)@"COObject"];
	
	ETPropertyDescription *htmlCodeProperty = [ETPropertyDescription descriptionWithName: @"htmlCode"
																					type: (id)@"NSString"];
	htmlCodeProperty.persistent = YES;
	
	[entity setPropertyDescriptions: @[htmlCodeProperty]];
	
	entity.diffAlgorithm = @"COAttributedStringDiff";
	
    return entity;
}

@dynamic htmlCode;

- (NSUInteger) hash
{
	return [self.htmlCode hash];
}

- (BOOL) isEqual: (id)anObject
{
	if (![anObject isKindOfClass: [COAttributedStringAttribute class]])
		return NO;
	
	COAttributedStringAttribute *anAttribute = anObject;
	return [self.htmlCode isEqual: anAttribute.htmlCode];
}

- (COItemGraph *) attributeItemGraph
{
	COItemGraph *result = [[COItemGraph alloc] init];
	
	COCopier *copier = [COCopier new];
	ETUUID *copyUUID = [copier copyItemWithUUID: [self UUID] fromGraph: self.objectGraphContext toGraph: result];
	[result setRootItemUUID: copyUUID];
	
	return result;
}

@end
