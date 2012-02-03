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

	ETPropertyDescription *collectionContentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.COObject"];
	[collectionContentsProperty setMultivalued: YES];
	[collectionContentsProperty setOpposite: (id)@"Anonymous.COObject.parentCollections"]; // FIXME: just 'parentCollections' should work...
	[collectionContentsProperty setOrdered: NO];
	[collectionContentsProperty setPersistent: YES];

	[collection setPropertyDescriptions: A(collectionContentsProperty)];

	return collection;
}

- (BOOL)isGroup
{
	return YES;
}

- (BOOL) isOrdered
{
	return NO;
}

- (NSArray *) contentArray
{
	return [[self content] allObjects];
}

@end


@implementation COTag

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COTag className]] == NO) 
		return collection;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COTag"
	                               description: @"Core Object Tag"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[collection setLocalizedDescription: _(@"Tag")];

	return collection;
}

- (BOOL)isTag
{
	assert([[[self editingContext] tagLibrary] containsObject: self]);
	return YES;
}

- (NSString *)tagString
{
	return [[self name] lowercaseString];
}

@end


@implementation COTagGroup

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COTagGroup className]] == NO) 
		return collection;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COTagGroup"
	                               description: @"Core Object Tag Group"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[collection setLocalizedDescription: _(@"Tag Group")];

	return collection;
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
		[ETPropertyDescription descriptionWithName: @"content" type: (id)@"Anonymous.COObject"];
	
	[contentProperty setMultivalued: YES];
	// FIXME: We should use [contentProperty setOpposite: (id)@"Anonymous.COObject.parentGroups"];
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
	ASSIGN(targetCollection, aGroup);
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
