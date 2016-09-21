/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnorderedGroupWithOpposite.h"

@implementation UnorderedGroupWithOpposite

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [UnorderedGroupWithOpposite className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					typeName: @"UnorderedGroupContent"];
    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = NO;
	contentsProperty.oppositeName = @"UnorderedGroupContent.parentGroups";
	
	entity.propertyDescriptions = @[labelProperty, contentsProperty];
	
    return entity;
}

@dynamic label;
@dynamic contents;
@end
