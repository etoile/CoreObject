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

- (COItemGraph *) attributeItemGraph
{
	COItemGraph *result = [[COItemGraph alloc] init];
	
	COCopier *copier = [COCopier new];
	ETUUID *copyUUID = [copier copyItemWithUUID: [self UUID] fromGraph: self.objectGraphContext toGraph: result];
	[result setRootItemUUID: copyUUID];
	
	return result;
}

+ (BOOL) isAttributeSet: (NSSet *)aSet equalToSet: (NSSet *)anotherSet
{
	return [[[aSet mappedCollection] htmlCode] isEqual: [[anotherSet mappedCollection] htmlCode]];
}

+ (NSSet *) attributeSet: (NSSet *)aSet minusSet: (NSSet *)anotherSet
{
	NSSet *htmlCodesToRemove = (NSSet *)[[anotherSet mappedCollection] htmlCode];
	
	NSMutableSet *result = [NSMutableSet set];
	for (COAttributedStringAttribute *attr in aSet)
	{
		if (![htmlCodesToRemove containsObject: attr.htmlCode])
		{
			[result addObject: attr];
		}
	}
	return result;
}

@end
