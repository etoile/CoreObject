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
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *parentsProperty = [ETPropertyDescription descriptionWithName: @"parents"
																				   type: (id)@"Anonymous.UnivaluedGroupWithOpposite"];
    [parentsProperty setMultivalued: YES];
    [parentsProperty setOrdered: NO];
	[parentsProperty setOpposite: (id)@"Anonymous.UnivaluedGroupWithOpposite.content"];
	[parentsProperty setDerived: YES];
	
	[entity setPropertyDescriptions: @[labelProperty, parentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic parents;
@end
