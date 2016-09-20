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
                                                                                type: (id)@"Anonymous.NSString"];
    [tagLabelProperty setPersistent: YES];

    ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];
    [contentsProperty setPersistent: YES];

    ETPropertyDescription *childTagsProperty =
    [ETPropertyDescription descriptionWithName: @"childTags" type: (id)@"Anonymous.Tag"];
    [childTagsProperty setMultivalued: YES];
    [childTagsProperty setOrdered: NO];
	[childTagsProperty setPersistent: YES];
    
    ETPropertyDescription *parentTagProperty =
    [ETPropertyDescription descriptionWithName: @"parentTag" type: (id)@"Anonymous.Tag"];
    [parentTagProperty setOpposite: childTagsProperty];
	[parentTagProperty setDerived: YES];
	
	ETAssert(childTagsProperty.isComposite);
	ETAssert(parentTagProperty.isContainer);
    
    [entity setPropertyDescriptions: A(tagLabelProperty, contentsProperty, childTagsProperty, parentTagProperty)];
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
