/*
    Copyright (C) 2014 Quentin Mathe
 
    Date:  October 2014
    License:  MIT  (see COPYING)
 */

#import "ObjectWithTransientState.h"

@implementation ObjectWithTransientState

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];

    if (![entity.name isEqual: [ObjectWithTransientState className]])
        return entity;
    
    ETPropertyDescription *labelProperty =
        [ETPropertyDescription descriptionWithName: @"label"
                                              typeName: @"NSString"];
    ETPropertyDescription *orderedCollectionProperty =
        [ETPropertyDescription descriptionWithName: @"orderedCollection"
                                              typeName: @"NSObject"];
    orderedCollectionProperty.multivalued = YES;
    orderedCollectionProperty.ordered = YES;
    ETPropertyDescription *derivedOrderedCollectionProperty =
        [ETPropertyDescription descriptionWithName: @"derivedOrderedCollection"
                                              typeName: @"NSObject"];
    derivedOrderedCollectionProperty.multivalued = YES;
    derivedOrderedCollectionProperty.ordered = YES;
    derivedOrderedCollectionProperty.derived = YES;

    entity.propertyDescriptions = @[labelProperty, orderedCollectionProperty,
        derivedOrderedCollectionProperty];
    
    return entity;
}

@dynamic label, orderedCollection;

- (NSArray *)derivedOrderedCollection
{
    return self.orderedCollection;
}

- (void)setDerivedOrderedCollection: (NSArray *)aCollection
{
    self.orderedCollection = aCollection;
}

@end
