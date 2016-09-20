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
    parentProperty.opposite = (id)@"Anonymous.Parent.child";
	[parentProperty setDerived: YES];
    
    entity.propertyDescriptions = @[labelProperty, parentProperty];
	
    return entity;
}

@dynamic label;
@dynamic parent;

@end
