/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "OrderedGroupWithOpposite.h"

@implementation OrderedGroupWithOpposite

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];

    if (![entity.name isEqual: [OrderedGroupWithOpposite className]])
        return entity;

    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                             typeName: @"NSString"];
    labelProperty.persistent = YES;

    ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
                                                                                typeName: @"OrderedGroupContent"];
    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = YES;
    contentsProperty.oppositeName = @"OrderedGroupContent.parentGroups";

    entity.propertyDescriptions = @[labelProperty, contentsProperty];

    return entity;
}

@dynamic label;
@dynamic contents;

@end
