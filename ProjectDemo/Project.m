#import "Project.h"

@implementation Project

@synthesize delegate; // notification hack - remove when we can use KVO

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

- (NSSet*) documents
{
	[self willAccessValueForProperty: @"documents"];
	return documents;
}
- (void) addDocument: (Document *)document
{
	[self willChangeValueForProperty: @"documents"];
	[documents addObject: document];
	[self didChangeValueForProperty: @"documents"];
	
	[delegate projectDocumentsDidChange: self]; // notification hack - remove when we can use KVO
}
- (void) removeDocument: (Document *)document
{
	[self willChangeValueForProperty: @"documents"];
	[documents removeObject: document];
	[self didChangeValueForProperty: @"documents"];
	
	[delegate projectDocumentsDidChange: self];// notification hack - remove when we can use KVO
}

- (NSSet*) tags
{
	[self willAccessValueForProperty: @"tags"];
	return tags;
}
- (void) addTag: (Tag *)tag
{
	[self willChangeValueForProperty: @"tags"];
	[tags addObject: tag];
	[self didChangeValueForProperty: @"tags"];
}
- (void) removeTag: (Tag *)tag
{
	[self willChangeValueForProperty: @"tags"];
	[tags removeObject: tag];
	[self didChangeValueForProperty: @"tags"];
}

- (void)didAwaken
{
	[delegate projectDocumentsDidChange: self];// notification hack - remove when we can use KVO
}

@end
