/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COGroup.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COGroup

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COGroup className]] == NO) 
		return collection;
	
	[collection setParent: (id)@"Anonymous.COObject"];

	ETPropertyDescription *collectionContentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.COObject"];
	[collectionContentsProperty setMultivalued: YES];
	[collectionContentsProperty setOpposite: (id)@"Anonymous.COObject.parentCollections"]; // FIXME: just 'parentCollections' should work...
	[collectionContentsProperty setOrdered: NO];
	[collectionContentsProperty setPersistent: YES];

	[collection setPropertyDescriptions: A(collectionContentsProperty)];

	return collection;
}

- (BOOL) isOrdered
{
	return NO;
}

- (NSArray *) contentArray
{
	return [[self content] allObjects];
}

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	NSMutableArray *result = [NSMutableArray array];

	for (COObject *object in [self content])
	{
		if ([object matchesPredicate: [aQuery predicate]])
		{
			[result addObject: object];
		}
	}

	return result;
}

@end

@implementation COSmartGroup

@synthesize targetGroup, query, contentBlock;

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
	DESTROY(targetGroup);
	DESTROY(query);
	DESTROY(contentBlock);
	[super dealloc];
}

- (void) setTargetGroup: (COGroup *)aGroup
{
	ASSIGN(targetGroup, aGroup);
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

	if (contentBlock != nil)
	{
		result = contentBlock();
	}
	else if (targetGroup != nil)
	{
		ETAssert(query != nil);

		result = [targetGroup objectsMatchingQuery: query];
	}
	else if (query != nil)
	{
		// TODO: Query the store
	}
	else
	{
		NSLog(@"WARNING: %@ misses content provider to be refreshed", self);
	}

	ETAssert([result isKindOfClass: [NSArray class]]);

	ASSIGN(content, result);
}

@end
