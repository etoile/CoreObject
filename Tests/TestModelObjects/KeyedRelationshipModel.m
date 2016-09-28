/*
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import "KeyedRelationshipModel.h"

@implementation KeyedRelationshipModel

@dynamic entries;

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *object = [self newBasicEntityDescription];

    // For subclasses that don't override -newEntityDescription, we must not add
    // the property descriptions that we will inherit through the parent
    if (![object.name isEqual: [KeyedRelationshipModel className]])
        return object;

    ETPropertyDescription *entries =
        [ETPropertyDescription descriptionWithName: @"entries" typeName: @"COObject"];
    entries.multivalued = YES;
    entries.keyed = YES;
    entries.persistent = YES;

    [object addPropertyDescription: entries];

    return object;
}

@end
