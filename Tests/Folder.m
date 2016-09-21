/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "Folder.h"

@implementation Folder

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [Folder className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
	
	ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" typeName: @"Folder"];
	
    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = NO;

    ETPropertyDescription *parentProperty =
    [ETPropertyDescription descriptionWithName: @"parent" typeName: @"Folder"];
    
    parentProperty.multivalued = NO;
	parentProperty.derived = YES;
    parentProperty.oppositeName = @"Folder.contents";
    
    entity.propertyDescriptions = @[labelProperty, contentsProperty, parentProperty];
	
    return entity;
}

@dynamic label;
@dynamic contents;
@dynamic parent;

@end
