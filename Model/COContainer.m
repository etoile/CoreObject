/*
	Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

	Date:  November 2010
	License:  MIT  (see COPYING)
 */

#import "COContainer.h"
#import "COGroup.h"

@implementation COContainer

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([collection.name isEqual: [COContainer className]] == NO) 
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
