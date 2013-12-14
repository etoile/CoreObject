/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>,
			 Eric Wasylishen <ewasylishen@gmail.com>
	Date:  October 2013
	License:  MIT  (see COPYING)
 */

#import "KeyedRelationshipModel.h"

@implementation KeyedRelationshipModel

@dynamic entries;

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *object = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[object name] isEqual: [KeyedRelationshipModel className]] == NO)
		return object;
	
	ETPropertyDescription *entries =
	[ETPropertyDescription descriptionWithName: @"entries" type: (id)@"COObject"];
	[entries setMultivalued: YES];
	[entries setKeyed: YES];
	[entries setPersistent: YES];
	
	[object addPropertyDescription: entries];
	
	return object;
}

@end
