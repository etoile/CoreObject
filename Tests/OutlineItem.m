/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "OutlineItem.h"

@implementation OutlineItem

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [OutlineItem className]])
		return entity;

	ETPropertyDescription *isShared = [ETPropertyDescription descriptionWithName: @"isShared"
                                                                                 typeName: @"BOOL"];
    isShared.persistent = YES;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
    
    ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" typeName: @"OutlineItem"];
	
    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = YES;
    
    ETPropertyDescription *parentContainerProperty =
    [ETPropertyDescription descriptionWithName: @"parentContainer" typeName: @"OutlineItem"];
    
    parentContainerProperty.multivalued = NO;
	parentContainerProperty.derived = YES;
    parentContainerProperty.oppositeName = @"OutlineItem.contents";
    
    ETPropertyDescription *parentCollectionsProperty =
    [ETPropertyDescription descriptionWithName: @"parentCollections" typeName: @"Tag"];
    
    parentCollectionsProperty.multivalued = YES;
	parentCollectionsProperty.derived = YES;
    parentCollectionsProperty.oppositeName = @"Tag.contents";
	
	ETPropertyDescription *attachmentProperty =
    [ETPropertyDescription descriptionWithName: @"attachmentID" typeName: @"COAttachmentID"];
	attachmentProperty.persistent = YES;
    
    entity.propertyDescriptions = @[isShared, labelProperty, contentsProperty, parentContainerProperty, parentCollectionsProperty, attachmentProperty];

    return entity;
}

- (NSString *)contentKey
{
	return @"contents";
}

- (BOOL)isShared
{
	return [[self valueForVariableStorageKey: @"isShared"] boolValue];
}

- (void)setIsShared:(BOOL)isShared
{
	[self willChangeValueForProperty: @"isShared"];
	[self setValue: @(isShared) forVariableStorageKey: @"isShared"];
	[self didChangeValueForProperty: @"isShared"];
}

// FIXME: Fix COObject+Accessors to support overriding read-only properties as read-write
//@dynamic isShared;
@dynamic label;
@dynamic contents;
@dynamic parentContainer;
@dynamic parentCollections;
@dynamic checked;
@dynamic attachmentID;

@end


@implementation TransientOutlineItem

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [TransientOutlineItem className]])
		return entity;

    ETPropertyDescription *contentsProperty =
		[ETPropertyDescription descriptionWithName: @"contents" typeName: @"TransientOutlineItem"];

    contentsProperty.multivalued = YES;
    contentsProperty.ordered = YES;
    
    ETPropertyDescription *parentContainerProperty =
    	[ETPropertyDescription descriptionWithName: @"parentContainer" typeName: @"TransientOutlineItem"];
    
	// NOTE: For a non-persistent relationship, 'container' doesn't necessarily imply 'derived'
    parentContainerProperty.multivalued = NO;
    parentContainerProperty.oppositeName = @"TransientOutlineItem.contents";
       
    entity.propertyDescriptions = @[contentsProperty, parentContainerProperty];

    return entity;
}

- (NSString *)contentKey
{
	return @"contents";
}

@dynamic contents, parentContainer;

@end
