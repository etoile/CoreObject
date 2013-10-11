/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COContainer.h"
#import "COGroup.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COContainer

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COContainer className]] == NO) 
		return collection;
	
	ETPropertyDescription *objects =
		[self contentPropertyDescriptionWithName: @"objects" type: (id)@"COObject" opposite: nil];
	
	[collection setPropertyDescriptions: A(objects)];

	return collection;	
}

- (BOOL)isContainer
{
	return YES;
}

@end
