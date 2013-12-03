#import "UnivaluedAttributeModel.h"

@implementation UnivaluedAttributeModel

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnivaluedAttributeModel"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	[entity setPropertyDescriptions: @[labelProperty]];
	
    return entity;
}

@dynamic label;

@end