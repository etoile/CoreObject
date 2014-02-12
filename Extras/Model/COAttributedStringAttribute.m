/*
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "COAttributedStringAttribute.h"

@implementation COAttributedStringAttribute

@dynamic styleKey, styleValue;

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"COAttributedStringAttribute"];
    [entity setParent: (id)@"COObject"];
	
	ETPropertyDescription *styleKeyProperty = [ETPropertyDescription descriptionWithName: @"styleKey"
																					type: (id)@"NSString"];
	styleKeyProperty.persistent = YES;

	ETPropertyDescription *styleValueProperty = [ETPropertyDescription descriptionWithName: @"styleValue"
																					  type: (id)@"NSString"];
	styleValueProperty.persistent = YES;

	
	[entity setPropertyDescriptions: @[styleKeyProperty, styleValueProperty]];
	
	entity.diffAlgorithm = @"COAttributedStringDiff";
	
    return entity;
}

- (COItemGraph *) attributeItemGraph
{
	COItemGraph *result = [[COItemGraph alloc] init];
	
	COCopier *copier = [COCopier new];
	ETUUID *copyUUID = [copier copyItemWithUUID: [self UUID] fromGraph: self.objectGraphContext toGraph: result];
	[result setRootItemUUID: copyUUID];
	
	return result;
}

+ (NSDictionary *) dictionaryForAttributeSet: (NSSet *)aSet
{
	NSMutableDictionary *result = [NSMutableDictionary new];
	for (COAttributedStringAttribute *attr in aSet)
	{
		result[attr.styleKey] = attr.styleValue;
	}
	return result;
}

+ (BOOL) isAttributeSet: (NSSet *)aSet equalToSet: (NSSet *)anotherSet
{
	return [[self dictionaryForAttributeSet: aSet]
			isEqual: [self dictionaryForAttributeSet: anotherSet]];
}

+ (NSSet *) attributeSet: (NSSet *)aSet minusSet: (NSSet *)anotherSet
{
	NSDictionary *pairsToRemove = [self dictionaryForAttributeSet: anotherSet];
	
	NSMutableSet *result = [NSMutableSet set];
	for (COAttributedStringAttribute *attr in aSet)
	{
		if (![pairsToRemove[attr.styleKey] isEqualToString: attr.styleValue])
		{
			[result addObject: attr];
		}
	}
	return result;
}

+ (COItemGraph *) attributeItemGraphForStyleKey: (NSString *)aKey styleValue: (NSString *)aValue
{
	COObjectGraphContext *tempCtx = [COObjectGraphContext new];
	COAttributedStringAttribute *attr = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: tempCtx];
	attr.styleKey = aKey;
	attr.styleValue = aValue;
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
	
	return [anAttr isDeeplyEqualToAttribute: anotherAttr];
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"%@=%@", self.styleKey, self.styleValue];
}

- (BOOL) isDeeplyEqualToAttribute: (COAttributedStringAttribute *)anAttribute
{
	return [self.styleKey isEqualToString: anAttribute.styleKey]
		&& [self.styleValue isEqualToString: anAttribute.styleValue];
}

@end
