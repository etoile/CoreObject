#import "UnorderedGroupContent.h"

@implementation UnorderedGroupContent

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnorderedGroupContent"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *parentGroupsProperty = [ETPropertyDescription descriptionWithName: @"parentGroups"
																						type: (id)@"Anonymous.UnorderedGroupWithOpposite"];
    [parentGroupsProperty setMultivalued: YES];
    [parentGroupsProperty setOrdered: NO];
	[parentGroupsProperty setOpposite: (id)@"Anonymous.UnorderedGroupWithOpposite.contents"];
	
	[entity setPropertyDescriptions: @[labelProperty, parentGroupsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic parentGroups;
@end