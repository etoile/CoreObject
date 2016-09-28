/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "Parent.h"

@implementation Parent

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];

    if (![entity.name isEqual: [Parent className]])
        return entity;

    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                             typeName: @"NSString"];
    labelProperty.persistent = YES;

    ETPropertyDescription *childProperty =
        [ETPropertyDescription descriptionWithName: @"child" typeName: @"Child"];
    childProperty.persistent = YES;

    entity.propertyDescriptions = @[labelProperty, childProperty];

    return entity;
}

@dynamic label;
@dynamic child;

@end
