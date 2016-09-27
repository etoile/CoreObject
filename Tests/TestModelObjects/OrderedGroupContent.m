/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "OrderedGroupContent.h"

@implementation OrderedGroupContent

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
    
    if (![entity.name isEqual: [OrderedGroupContent className]])
        return entity;
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
    
    ETPropertyDescription *parentGroupsProperty = [ETPropertyDescription descriptionWithName: @"parentGroups"
                                                                                        typeName: @"OrderedGroupWithOpposite"];
    parentGroupsProperty.multivalued = YES;
    parentGroupsProperty.ordered = NO;
    parentGroupsProperty.oppositeName = @"OrderedGroupWithOpposite.contents";
    parentGroupsProperty.derived = YES;
    
    entity.propertyDescriptions = @[labelProperty, parentGroupsProperty];
    
    return entity;
}

@dynamic label;
@dynamic parentGroups;
@end
