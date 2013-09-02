#import "TextItem.h"
#import "Document.h"

@implementation TextItem

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"TextItem"];
    [entity setParent: (id)@"DocumentItem"];
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
    [labelProperty setPersistent: YES];
    [entity setPropertyDescriptions: A(labelProperty)];
    return entity;
}

/* Accessor Methods */

@dynamic label;

@end
