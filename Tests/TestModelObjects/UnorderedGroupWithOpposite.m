#import "UnorderedGroupWithOpposite.h"

@implementation UnorderedGroupWithOpposite

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnorderedGroupWithOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.UnorderedGroupContent"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];
	[contentsProperty setOpposite: (id)@"Anonymous.UnorderedGroupContent.parentGroups"];
	
	[entity setPropertyDescriptions: @[labelProperty, contentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;
@end
