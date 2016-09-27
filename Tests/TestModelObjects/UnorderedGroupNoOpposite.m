/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnorderedGroupNoOpposite.h"

@implementation UnorderedGroupNoOpposite

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
    
    if (![entity.name isEqual: [UnorderedGroupNoOpposite className]])
        return entity;

    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 typeName: @"NSString"];
    labelProperty.persistent = YES;
    
    ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
                                                                                    typeName: @"COObject"];
    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = NO;
    
    entity.propertyDescriptions = @[labelProperty, contentsProperty];
    
    return entity;
}

@dynamic label;
@dynamic contents;

@end
