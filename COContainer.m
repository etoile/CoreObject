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
	ETEntityDescription *container = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[container name] isEqual: [COContainer className]] == NO) 
		return container;
	
	ETPropertyDescription *containerContentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.COObject"];
	
	[containerContentsProperty setMultivalued: YES];
	[containerContentsProperty setOpposite: (id)@"Anonymous.COObject.parentContainer"]; // FIXME: just 'parent' should work...
	[containerContentsProperty setOrdered: YES];
	[containerContentsProperty setPersistent: YES];

	[container setPropertyDescriptions: A(containerContentsProperty)];

	return container;	
}

- (BOOL) isOrdered
{
	return YES;
}

@end
