/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnivaluedGroupWithOpposite.h"

@implementation UnivaluedGroupWithOpposite

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [UnivaluedGroupWithOpposite className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
	
	ETPropertyDescription *contentProperty = [ETPropertyDescription descriptionWithName: @"content"
																				   typeName: @"UnivaluedGroupContent"];
    contentProperty.persistent = YES;
	contentProperty.oppositeName = @"UnivaluedGroupContent.parents";
	
	entity.propertyDescriptions = @[labelProperty, contentProperty];
	
    return entity;
}

@dynamic label;
@dynamic content;
@end
