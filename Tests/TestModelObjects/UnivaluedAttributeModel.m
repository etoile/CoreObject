/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnivaluedAttributeModel.h"

@implementation UnivaluedAttributeModel

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
    
    if (![entity.name isEqual: [UnivaluedAttributeModel className]])
        return entity;
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
    
    entity.propertyDescriptions = @[labelProperty];
    
    return entity;
}

@dynamic label;

@end
