/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COContainer.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COContainer

+ (void) initialize
{
	if (self != [COContainer class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
	[self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *group = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[group name] isEqual: [COContainer className]] == NO) 
		return group;
	
	ETPropertyDescription *groupContentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.COObject"];
	
	[groupContentsProperty setMultivalued: YES];
	[groupContentsProperty setOpposite: (id)@"Anonymous.COObject.parentContainer"]; // FIXME: just 'parent' should work...
	[groupContentsProperty setOrdered: YES];
	[groupContentsProperty setPersistent: YES];

	[group setPropertyDescriptions: A(groupContentsProperty)];

	return group;	
}

- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return [self valueForProperty: @"contents"];
}

- (NSArray *) contentArray
{
	 // FIXME: Should return a new array, but this might break other things currently
	return [self valueForProperty: @"contents"];
}

- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	if (index == ETUndeterminedIndex)
	{
		[self addObject: object forProperty: @"contents"];
	}
	else
	{
		[self insertObject: object atIndex: index forProperty: @"contents"];
	}
}

- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	if (index == ETUndeterminedIndex)
	{
		[self removeObject: object forProperty: @"contents"];	
	}
	else
	{
		[self removeObject: object atIndex: index forProperty: @"contents"];
	}
}

@end
