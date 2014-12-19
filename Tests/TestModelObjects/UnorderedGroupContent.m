/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnorderedGroupContent.h"

@implementation UnorderedGroupContent

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [UnorderedGroupContent className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *parentGroupsProperty = [ETPropertyDescription descriptionWithName: @"parentGroups"
																						type: (id)@"Anonymous.UnorderedGroupWithOpposite"];
    [parentGroupsProperty setMultivalued: YES];
    [parentGroupsProperty setOrdered: NO];
	[parentGroupsProperty setOpposite: (id)@"Anonymous.UnorderedGroupWithOpposite.contents"];
	[parentGroupsProperty setDerived: YES];
	
	[entity setPropertyDescriptions: @[labelProperty, parentGroupsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic parentGroups;
@end
