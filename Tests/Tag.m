#import "Tag.h"

@implementation Tag

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *tagEntity = [ETEntityDescription descriptionWithName: @"Tag"];
    [tagEntity setParent: (id)@"Anonymous.COGroup"];

    ETPropertyDescription *tagLabelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                type: (id)@"Anonymous.NSString"];
    [tagLabelProperty setPersistent: YES];

    ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];
    [contentsProperty setPersistent: YES];

    ETPropertyDescription *childTagsProperty =
    [ETPropertyDescription descriptionWithName: @"childTags" type: (id)@"Anonymous.Tag"];
    [childTagsProperty setPersistent: YES];
    [childTagsProperty setMultivalued: YES];
    [childTagsProperty setOrdered: NO];
    
    ETPropertyDescription *parentTagProperty =
    [ETPropertyDescription descriptionWithName: @"parentTag" type: (id)@"Anonymous.Tag"];
    [parentTagProperty setOpposite: childTagsProperty];
    [parentTagProperty setIsContainer: YES];
    
    [tagEntity setPropertyDescriptions: A(tagLabelProperty, contentsProperty, childTagsProperty, parentTagProperty)];
    return tagEntity;
}

- (NSString *)contentKey
{
	return @"contents";
}

@dynamic label;
@dynamic contents;
@dynamic parentTag;
@dynamic childTags;

@end
