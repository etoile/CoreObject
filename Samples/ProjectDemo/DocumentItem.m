#import "DocumentItem.h"

@implementation DocumentItem

+ (void)initialize
{
	if (self == [DocumentItem class])
	{
		ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
		
		// DocumentItem entity (super-entity of OutlineItem, DraawingItem, TextItem)
		{
			ETEntityDescription *docItemEntity = [ETEntityDescription descriptionWithName: @"DocumentItem"];
			
			ETPropertyDescription *documentProperty = [ETPropertyDescription descriptionWithName: @"document"
																							type: (id)@"Document"];
			[documentProperty setIsContainer: YES];
			
			[docItemEntity setPropertyDescriptions: A(documentProperty)];
			
			[repo addUnresolvedDescription: docItemEntity];
            
            
            [repo setEntityDescription: docItemEntity
							  forClass: [DocumentItem class]];
		}
		
        [[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
	}
}

@dynamic document;

@end
