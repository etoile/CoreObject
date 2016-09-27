#import "TextItem.h"
#import "Document.h"

@implementation TextItem

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
    
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"attrString"
                                                                                 type: (id)@"COAttributedString"];
    [labelProperty setPersistent: YES];
    [entity setPropertyDescriptions: A(labelProperty)];
    return entity;
}

- (instancetype) initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
    self = [super initWithObjectGraphContext: aContext];
    self.attrString = [[COAttributedString alloc] initWithObjectGraphContext: aContext];
    return self;
}

/* Accessor Methods */

@dynamic attrString;

@end
