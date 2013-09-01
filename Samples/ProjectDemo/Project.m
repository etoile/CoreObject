#import "Project.h"

@implementation Project

+ (void)initialize
{
	if (self == [Project class])
	{
		ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"Project"];
		
		ETPropertyDescription *documentsProperty = [ETPropertyDescription descriptionWithName: @"documents"
																						 type: (id)@"Document"];
		[documentsProperty setMultivalued: YES];

		[Tag class];
		ETPropertyDescription *tagsProperty = [ETPropertyDescription descriptionWithName: @"tags"
																						 type: (id)@"Tag"];
		[tagsProperty setMultivalued: YES];
		
		[entity setPropertyDescriptions: A(documentsProperty, tagsProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: entity];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: entity
																   forClass: self];
		
		[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
	}
}

@dynamic documents;
@dynamic tags;

- (void) addDocument: (Document *)document
{
    [[self mutableSetValueForKey: @"document"] addObject: document];
}

- (void) removeDocument: (Document *)document
{
    [[self mutableSetValueForKey: @"document"] removeObject: document];
}

- (void) addTag: (Tag *)tag
{
	[[self mutableSetValueForKey: @"tags"] addObject: tag];
}

- (void) removeTag: (Tag *)tag
{
	[[self mutableSetValueForKey: @"tags"] removeObject: tag];
}

@end
