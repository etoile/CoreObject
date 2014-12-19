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
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentProperty = [ETPropertyDescription descriptionWithName: @"content"
																				   type: (id)@"Anonymous.UnivaluedGroupContent"];
    [contentProperty setPersistent: YES];
	[contentProperty setOpposite: (id)@"Anonymous.UnivaluedGroupContent.parents"];
	
	[entity setPropertyDescriptions: @[labelProperty, contentProperty]];
	
    return entity;
}

@dynamic label;
@dynamic content;
@end
