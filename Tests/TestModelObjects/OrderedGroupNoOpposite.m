/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "OrderedGroupNoOpposite.h"

@implementation OrderedGroupNoOpposite

static NSUInteger DeallocCalls;

+ (NSUInteger) countOfDeallocCalls
{
    return DeallocCalls;
}

- (void) dealloc
{
    DeallocCalls++;
}

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
    
    if (![entity.name isEqual: [OrderedGroupNoOpposite className]])
        return entity;
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
    
    ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
                                                                                    typeName: @"COObject"];
    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = YES;
    
    entity.propertyDescriptions = @[labelProperty, contentsProperty];
    
    return entity;
}

@dynamic label;
@dynamic contents;

@end
