#import "Child.h"

@implementation Child

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"Child"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
   
    ETPropertyDescription *parentProperty =
    [ETPropertyDescription descriptionWithName: @"parent" type: (id)@"Anonymous.Parent"];
    
    [parentProperty setIsContainer: YES];
    [parentProperty setMultivalued: NO];
    [parentProperty setOpposite: (id)@"Anonymous.Parent.child"];
    
    [entity setPropertyDescriptions: @[labelProperty, parentProperty]];
	
    return entity;
}

@dynamic label;
@dynamic parent;

@end
