/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "Tag.h"

@implementation Tag

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];

    if (![entity.name isEqual: [Tag className]])
        return entity;

    ETPropertyDescription *tagLabelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                typeName: @"NSString"];
    tagLabelProperty.persistent = YES;

    ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" typeName: @"OutlineItem"];
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = NO;
    contentsProperty.persistent = YES;

    ETPropertyDescription *childTagsProperty =
    [ETPropertyDescription descriptionWithName: @"childTags" typeName: @"Tag"];
    childTagsProperty.multivalued = YES;
    childTagsProperty.ordered = NO;
    childTagsProperty.persistent = YES;
    
    ETPropertyDescription *parentTagProperty =
    [ETPropertyDescription descriptionWithName: @"parentTag" typeName: @"Tag"];
    parentTagProperty.opposite = childTagsProperty;
    parentTagProperty.derived = YES;
    
    ETAssert(childTagsProperty.isComposite);
    ETAssert(parentTagProperty.isContainer);
    
    entity.propertyDescriptions = @[tagLabelProperty, contentsProperty, childTagsProperty, parentTagProperty];
    return entity;
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
