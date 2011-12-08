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

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COContainer className]] == NO) 
		return collection;
	
	ETPropertyDescription *contentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.COObject"];
	
	[contentsProperty setMultivalued: YES];
	[contentsProperty setOpposite: (id)@"Anonymous.COObject.parentContainer"]; // FIXME: just 'parent' should work...
	[contentsProperty setOrdered: YES];
	[contentsProperty setPersistent: YES];

	[collection setPropertyDescriptions: A(contentsProperty)];

	return collection;	
}

- (BOOL)isContainer
{
	return YES;
}

- (BOOL) isOrdered
{
	return YES;
}

@end


@implementation COLibrary

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COLibrary className]] == NO) 
		return collection;

	return collection;	
}

- (BOOL)isLibrary
{
	return YES;
}

- (BOOL) isOrdered
{
	return NO;
}

@end

