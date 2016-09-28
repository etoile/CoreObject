#import <EtoileFoundation/EtoileFoundation.h>

#import "Tag.h"

@implementation Tag

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *tag = [self newBasicEntityDescription];

    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];

    [tag setPropertyDescriptions: A(labelProperty)];
    return tag;
}

/* Accessor Methods */

@dynamic label;

@end
