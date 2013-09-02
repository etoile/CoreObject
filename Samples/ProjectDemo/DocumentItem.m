#import "DocumentItem.h"

@implementation DocumentItem

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *docItemEntity = [ETEntityDescription descriptionWithName: @"DocumentItem"];
    [docItemEntity setParent: (id)@"COObject"];
    
    ETPropertyDescription *documentProperty = [ETPropertyDescription descriptionWithName: @"document"
                                                                                    type: (id)@"Document"];
    [documentProperty setIsContainer: YES];
    
    [docItemEntity setPropertyDescriptions: A(documentProperty)];
    
    return docItemEntity;
}

@dynamic document;

@end
