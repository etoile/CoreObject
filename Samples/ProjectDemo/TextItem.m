#import "TextItem.h"
#import "Document.h"

@implementation TextItem

+ (void)initialize
{
	if (self == [TextItem class])
	{
		ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"TextItem"];
		
		[Document class]; // FIXME: ugly hack to ensure the DocumentItem (superentity of OutlineItem) is registered
		[entity setParent: @"DocumentItem"];
		
		ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
																					 type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
		
		[entity setPropertyDescriptions: A(labelProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: entity];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: entity
																   forClass: self];
		
		[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
	}
}

/* Accessor Methods */

@dynamic label;

@end
