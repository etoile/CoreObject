/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "OrderedAttributeModel.h"

@implementation OrderedAttributeModel

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
    
    if (![entity.name isEqual: [OrderedAttributeModel className]])
        return entity;
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
    
    ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
                                                                                    typeName: @"NSString"];
    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = YES;
    
    entity.propertyDescriptions = @[labelProperty, contentsProperty];
    
    return entity;
}

@dynamic label;
@dynamic contents;

@end
