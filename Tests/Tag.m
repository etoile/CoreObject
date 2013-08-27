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

    [tagEntity setPropertyDescriptions: A(tagLabelProperty, contentsProperty)];
    return tagEntity;
}

@dynamic label;
@dynamic contents;

@end
