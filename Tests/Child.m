/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "Child.h"

@implementation Child

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];

	if (![entity.name isEqual: [Child className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
   
    ETPropertyDescription *parentProperty =
    [ETPropertyDescription descriptionWithName: @"parent" type: (id)@"Anonymous.Parent"];
    
    [parentProperty setMultivalued: NO];
    [parentProperty setOpposite: (id)@"Anonymous.Parent.child"];
	[parentProperty setDerived: YES];
    
    [entity setPropertyDescriptions: @[labelProperty, parentProperty]];
	
    return entity;
}

@dynamic label;
@dynamic parent;

@end
