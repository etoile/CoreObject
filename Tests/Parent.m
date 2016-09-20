/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "Parent.h"

@implementation Parent

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [Parent className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
    
    ETPropertyDescription *childProperty =
    [ETPropertyDescription descriptionWithName: @"child" type: (id)@"Anonymous.Child"];
    [childProperty setPersistent: YES];
    
    entity.propertyDescriptions = @[labelProperty, childProperty];
	
    return entity;
}

@dynamic label;
@dynamic child;

@end
