#import "Project.h"

@implementation Project

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"Project"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *documentsProperty = [ETPropertyDescription descriptionWithName: @"documents"
                                                                                     type: (id)@"Document"];
    [documentsProperty setPersistent: YES];
    [documentsProperty setMultivalued: YES];
    [documentsProperty setOpposite: (id)@"Document.project"];
    [documentsProperty setOrdered: NO];

    ETPropertyDescription *tagsProperty = [ETPropertyDescription descriptionWithName: @"tags"
                                                                                type: (id)@"Tag"];
    [tagsProperty setMultivalued: YES];
    [tagsProperty setPersistent: YES];
    
    [entity setPropertyDescriptions: A(documentsProperty, tagsProperty)];
	return entity;
}

@dynamic documents;
@dynamic tags;

- (void) addDocument_hack: (Document *)document
{
    [[self mutableSetValueForKey: @"documents"] addObject: document];
}

- (void) removeDocument: (Document *)document
{
    [[self mutableSetValueForKey: @"documents"] removeObject: document];
}

- (void) addTag: (Tag *)tag
{
	[[self mutableSetValueForKey: @"tags"] addObject: tag];
}

- (void) removeTag: (Tag *)tag
{
	[[self mutableSetValueForKey: @"tags"] removeObject: tag];
}

- (NSArray *) documentsSorted
{
	NSArray *unsorted = [self.documents allObjects];
	
	return [unsorted sortedArrayUsingDescriptors:
			@[[[NSSortDescriptor alloc] initWithKey:@"name" ascending: YES]]];
}

@end
