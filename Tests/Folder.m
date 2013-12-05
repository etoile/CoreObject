#import "Folder.h"

@implementation Folder

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"Folder"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.Folder"];
	
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];

    ETPropertyDescription *parentProperty =
    [ETPropertyDescription descriptionWithName: @"parent" type: (id)@"Anonymous.Folder"];
    
    [parentProperty setMultivalued: NO];
	[parentProperty setDerived: YES];
    [parentProperty setOpposite: (id)@"Anonymous.Folder.contents"];
    
    [entity setPropertyDescriptions: @[labelProperty, contentsProperty, parentProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;
@dynamic parent;

@end
