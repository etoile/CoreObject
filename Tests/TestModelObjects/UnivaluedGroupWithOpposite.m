#import "UnivaluedGroupWithOpposite.h"

@implementation UnivaluedGroupWithOpposite

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnivaluedGroupWithOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
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