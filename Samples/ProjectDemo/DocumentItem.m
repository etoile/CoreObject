#import "DocumentItem.h"

@implementation DocumentItem

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *docItemEntity = [self newBasicEntityDescription];
    
    ETPropertyDescription *documentProperty = [ETPropertyDescription descriptionWithName: @"document"
                                                                                    type: (id)@"Document"];
	[documentProperty setDerived: YES];
    [docItemEntity setPropertyDescriptions: A(documentProperty)];
    
    return docItemEntity;
}

@dynamic document;

@end
