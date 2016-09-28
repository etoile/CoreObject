/*
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  November 2010
    License:  MIT  (see COPYING)
 */

#import "COGroup.h"

@implementation COGroup

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *collection = [self newBasicEntityDescription];

    // For subclasses that don't override -newEntityDescription, we must not add the 
    // property descriptions that we will inherit through the parent
    if (![collection.name isEqual: [COGroup className]])
        return collection;

    ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COGroup"
                                   description: @"Core Object Group"
                              supertypeStrings: @[]
                                      typeTags: @{}];
    ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

    [collection setLocalizedDescription: _(@"Group")];

    ETPropertyDescription *objects =
        [self contentPropertyDescriptionWithName: @"objects"
                                            type: @"COObject"
                                        opposite: nil];

    collection.propertyDescriptions = @[objects];

    return collection;
}

- (BOOL)isGroup
{
    return YES;
}

@end
