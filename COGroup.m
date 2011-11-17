#import "COGroup.h"

@implementation COGroup

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COGroup className]] == NO) 
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
/*
+ (id) allObjectGroup
{
	return [COGroup
}

+ (void) registerLibrary: (COGroup *)aGroup forType: (NSString *)libraryType
{

}

+ (COGroup *) libraryForType: (NSString *)libraryType
{

}

+ (id) photoLibrary
{
	return [self libraryForType: kCOLibraryTypePhoto];
}

+ (id) musicLibrary
{
	return [self libraryForType: kCOLibraryTypeMusic];
}*/

- (BOOL) isOrdered
{
	return NO;
}

- (NSArray *) contentArray
{
	return [[self content] allObjects];
}

@end

@implementation COSmartGroup

@synthesize targetGroup;

@end
