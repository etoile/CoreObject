#import "OutlineItem.h"

@implementation OutlineItem

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *outlineEntity = [ETEntityDescription descriptionWithName: @"OutlineItem"];
    [outlineEntity setParent: (id)@"Anonymous.COContainer"];
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
    
    ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
	
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: YES];
    
    ETPropertyDescription *parentContainerProperty =
    [ETPropertyDescription descriptionWithName: @"parentContainer" type: (id)@"Anonymous.OutlineItem"];
    
    [parentContainerProperty setIsContainer: YES];
    [parentContainerProperty setMultivalued: NO];
    [parentContainerProperty setOpposite: (id)@"Anonymous.OutlineItem.contents"];
    
    ETPropertyDescription *parentCollectionsProperty =
    [ETPropertyDescription descriptionWithName: @"parentCollections" type: (id)@"Anonymous.Tag"];
    
    [parentCollectionsProperty setMultivalued: YES];
    [parentCollectionsProperty setOpposite: (id)@"Anonymous.Tag.contents"];
    
    [outlineEntity setPropertyDescriptions: A(labelProperty, contentsProperty, parentContainerProperty, parentCollectionsProperty)];

    return outlineEntity;
}

@dynamic label;
@dynamic contents;
@dynamic parentContainer;
@dynamic parentCollections;

@end
