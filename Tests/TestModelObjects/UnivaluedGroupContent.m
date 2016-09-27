/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnivaluedGroupContent.h"

@implementation UnivaluedGroupContent

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
    
    if (![entity.name isEqual: [UnivaluedGroupContent className]])
        return entity;
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
    
    ETPropertyDescription *parentsProperty = [ETPropertyDescription descriptionWithName: @"parents"
                                                                                   typeName: @"UnivaluedGroupWithOpposite"];
    parentsProperty.multivalued = YES;
    parentsProperty.ordered = NO;
    parentsProperty.oppositeName = @"UnivaluedGroupWithOpposite.content";
    parentsProperty.derived = YES;
    
    entity.propertyDescriptions = @[labelProperty, parentsProperty];
    
    return entity;
}

@dynamic label;
@dynamic parents;
@end
