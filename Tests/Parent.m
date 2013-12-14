/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "Parent.h"

@implementation Parent

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"Parent"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
    
    ETPropertyDescription *childProperty =
    [ETPropertyDescription descriptionWithName: @"child" type: (id)@"Anonymous.Child"];
    [childProperty setPersistent: YES];
    
    [entity setPropertyDescriptions: @[labelProperty, childProperty]];
	
    return entity;
}

@dynamic label;
@dynamic child;

@end
