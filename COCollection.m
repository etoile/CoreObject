#import "COCollection.h"

@implementation COCollection

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COCollection className]] == NO) 
		return collection;
	
	[collection setParent: (id)@"Anonymous.COObject"];
	
	ETPropertyDescription *collectionContentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.COObject"];
	[collectionContentsProperty setMultivalued: YES];
	[collectionContentsProperty setOpposite: (id)@"Anonymous.COObject.parentCollections"]; // FIXME: just 'parentCollections' should work...
	[collectionContentsProperty setOrdered: NO];
	[collectionContentsProperty setPersistent: YES];

	[collection setPropertyDescriptions: A(collectionContentsProperty)];

	return collection;
}

- (BOOL) isOrdered
{
	return NO;
}

- (NSArray *) contentArray
{
	return [[self content] allObjects];
}

@end