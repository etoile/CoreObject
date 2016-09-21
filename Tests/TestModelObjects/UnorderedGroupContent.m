/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnorderedGroupContent.h"

@implementation UnorderedGroupContent

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [UnorderedGroupContent className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
	
	ETPropertyDescription *parentGroupsProperty = [ETPropertyDescription descriptionWithName: @"parentGroups"
																						typeName: @"UnorderedGroupWithOpposite"];
    parentGroupsProperty.multivalued = YES;
    parentGroupsProperty.ordered = NO;
	parentGroupsProperty.oppositeName = @"UnorderedGroupWithOpposite.contents";
	parentGroupsProperty.derived = YES;
	
	entity.propertyDescriptions = @[labelProperty, parentGroupsProperty];
	
    return entity;
}

@dynamic label;
@dynamic parentGroups;
@end
