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
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
   
    ETPropertyDescription *parentProperty =
    [ETPropertyDescription descriptionWithName: @"parent" typeName: @"Parent"];
    
    parentProperty.multivalued = NO;
    parentProperty.oppositeName = @"Parent.child";
	parentProperty.derived = YES;
    
    entity.propertyDescriptions = @[labelProperty, parentProperty];
	
    return entity;
}

@dynamic label;
@dynamic parent;

@end
