/*
	Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

	Date:  November 2010
	License:  MIT  (see COPYING)
 */

#import "COGroup.h"
#import "COContainer.h"
#import "COEditingContext.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COGroup

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COGroup className]] == NO) 
		return collection;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COGroup"
	                               description: @"Core Object Group"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[collection setLocalizedDescription: _(@"Group")];

	ETPropertyDescription *objects =
		[self contentPropertyDescriptionWithName: @"objects"
		                                    type: @"COObject"
		                                opposite: nil];

	[collection setPropertyDescriptions: A(objects)];

	return collection;
}

- (BOOL)isGroup
{
	return YES;
}

- (NSArray *)contentArray
{
	return [[self content] allObjects];
}

@end


@implementation COSmartGroup

@synthesize targetCollection, query, contentBlock;

+ (void)initialize
{
	if (self != [COSmartGroup class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *group = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[group name] isEqual: [COSmartGroup className]] == NO) 
		return group;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COSmartGroup"
	                               description: @" Smart Core Object Group"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[group setLocalizedDescription: _(@"Smart Group")];

	ETPropertyDescription *content = 
		[ETPropertyDescription descriptionWithName: @"content" type: (id)@"COObject"];
	[content setMultivalued: YES];
	[content setOrdered: YES];

	[group setPropertyDescriptions: A(content)];

	return group;	
}

- (void)setTargetCollection: (id <ETCollection>)aGroup
{
	targetCollection =  (id)aGroup;
	[self refresh];
}

- (void)setContentBlock: (COContentBlock)aBlock
{
	contentBlock = [aBlock copy];
	[self refresh];
}

- (void)setQuery: (COQuery *)aQuery
{
	query =  aQuery;
	[self refresh];
}

- (BOOL)isOrdered
{
	return YES;
}

- (id)content
{
	return content;
}

- (NSArray *)contentArray
{
	return [NSArray arrayWithArray: content];
}

- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter]
		postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (void)refresh
{
	NSArray *result = nil;

	if (contentBlock != NULL)
	{
		result = contentBlock();
	}
	else if (targetCollection != nil && query != nil)
	{
		if ([(id)targetCollection conformsToProtocol: @protocol(COObjectMatching)])
		{
			result = [(id <COObjectMatching>)targetCollection objectsMatchingQuery: query];
		}
		else if ([query predicate] != nil)
		{
			result = [[targetCollection contentArray] filteredArrayUsingPredicate: [query predicate]];
		}
	}
	else if (query != nil)
	{
		// TODO: Query the store
	}
	else
	{
		result = [targetCollection contentArray];
	}

	ETAssert([result isKindOfClass: [NSArray class]]);

	content =  result;
	[self didUpdate];
}

// TODO: COGroup implements the same methods, put them in a COObjectMatchingTrait

- (id)objectForIdentifier: (NSString *)anId
{
	for (id object in [self content])
	{
		if ([[object identifier] isEqualToString: anId])
		{
			return object;
		}
	}
	return nil;
}

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	NSMutableArray *result = [NSMutableArray array];

	for (COObject *object in [self content])
	{
		if ([[aQuery predicate] evaluateWithObject: object])
		{
			[result addObject: object];
		}
	}

	return result;
}

@end
