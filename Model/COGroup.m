/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COGroup.h"
#import "COContainer.h"
#import "COEditingContext.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COGroup

+ (ETEntityDescription *) newEntityDescription
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

	ETPropertyDescription *contentProperty = 
		[self contentPropertyDescriptionWithName: @"contents" type: @"COObject" opposite: nil];

	[collection setPropertyDescriptions: A(contentProperty)];

	return collection;
}

- (BOOL)isGroup
{
	return YES;
}

- (NSArray *) contentArray
{
	return [[self content] allObjects];
}

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	// TODO: Switch to NSMutableOrderedSet once implemented on GNUstep
	if ([[self content] containsObject: object])
		return;

	[super insertObject: object atIndex: index hint: hint forProperty: key];
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

	ETPropertyDescription *contentProperty = 
		[ETPropertyDescription descriptionWithName: @"content" type: (id)@"COObject"];
	[contentProperty setMultivalued: YES];
	[contentProperty setOrdered: YES];

	[group setPropertyDescriptions: A(contentProperty)];

	return group;	
}

- (void)dealloc
{
	DESTROY(targetCollection);
	DESTROY(query);
	DESTROY(contentBlock);
	[super dealloc];
}

- (void) setTargetCollection: (id <ETCollection>)aGroup
{
	ASSIGN(targetCollection, (id)aGroup);
	[self refresh];
}

- (void) setContentBlock: (COContentBlock)aBlock
{
	[contentBlock release];
	contentBlock = [aBlock copy];
	[self refresh];
}

- (void) setQuery: (COQuery *)aQuery
{
	ASSIGN(query, aQuery);
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

	ASSIGN(content, result);
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
