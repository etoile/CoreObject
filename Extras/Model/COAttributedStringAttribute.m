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

+ (COItemGraph *) attributeItemGraphForHTMLCode: (NSString *)aCode
{
	COObjectGraphContext *tempCtx = [COObjectGraphContext new];
	COAttributedStringAttribute *attr = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: tempCtx];
	attr.htmlCode = aCode;
	return [attr attributeItemGraph];
}

+ (BOOL) isAttributeItemGraph: (COItemGraph *)aGraph equalToItemGraph: (COItemGraph *)anotherGraph
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	[ctx1 setItemGraph: aGraph];
	COAttributedStringAttribute *anAttr = [ctx1 rootObject];
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: anotherGraph];
	COAttributedStringAttribute *anotherAttr = [ctx2 rootObject];
	
	return [anAttr.htmlCode isEqualToString: anotherAttr.htmlCode];
}

@end
