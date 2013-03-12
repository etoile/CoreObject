#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COPersistentRoot.h"
#import "COStore.h"
#import "TestCommon.h"


@implementation TestCommon

// NOTE: The Xcode project includes a test suite limited to the store tests
#ifndef STORE_TEST

+ (void) setUpMetamodel
{
	// Outline item entity
	{
		ETEntityDescription *outlineEntity = [ETEntityDescription descriptionWithName: @"OutlineItem"];
		[outlineEntity setParent: (id)@"Anonymous.COContainer"];
		
		ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
																		  type: (id)@"Anonymous.NSString"];

		ETPropertyDescription *contentsProperty = 
			[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
	
		[contentsProperty setMultivalued: YES];
		[contentsProperty setOrdered: YES];

		ETPropertyDescription *parentContainerProperty = 
			[ETPropertyDescription descriptionWithName: @"parentContainer" type: (id)@"Anonymous.OutlineItem"];
		
		[parentContainerProperty setIsContainer: YES];
		[parentContainerProperty setMultivalued: NO];
		[parentContainerProperty setOpposite: (id)@"Anonymous.OutlineItem.contents"];

		ETPropertyDescription *parentCollectionsProperty = 
			[ETPropertyDescription descriptionWithName: @"parentCollections" type: (id)@"Anonymous.Tag"];

		[parentCollectionsProperty setMultivalued: YES];
		[parentCollectionsProperty setOpposite: (id)@"Anonymous.Tag.contents"];

		[outlineEntity setPropertyDescriptions: A(labelProperty, contentsProperty, parentContainerProperty, parentCollectionsProperty)];
		[[[outlineEntity propertyDescriptions] mappedCollection] setPersistent: YES];

		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: outlineEntity];
	}
	
	// Tag entity
	{
		ETEntityDescription *tagEntity = [ETEntityDescription descriptionWithName: @"Tag"];	
		[tagEntity setParent: (id)@"Anonymous.COGroup"];
		
		ETPropertyDescription *tagLabelProperty = [ETPropertyDescription descriptionWithName: @"label"
																		  type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];

		ETPropertyDescription *contentsProperty = 
			[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
		[contentsProperty setMultivalued: YES];
		[contentsProperty setOrdered: NO];

		[tagEntity setPropertyDescriptions: A(tagLabelProperty, contentsProperty)];
		[[[tagEntity propertyDescriptions] mappedCollection] setPersistent: YES];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: tagEntity];
	}
	
	// Person entity
	{
		ETEntityDescription *personEntity = [ETEntityDescription descriptionWithName: @"Person"];	
		[personEntity setParent: (id)@"Anonymous.COObject"];
		
		ETPropertyDescription *spouseProperty = [ETPropertyDescription descriptionWithName: @"spouse"
																					  type: (id)@"Anonymous.Person"];
		[spouseProperty setMultivalued: NO];
		[spouseProperty setOpposite: (id)@"Anonymous.Person.spouse"]; // This is a 1:1 relationship

		ETPropertyDescription *personNameProperty = [ETPropertyDescription descriptionWithName: @"name"
																						type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
		
		[personEntity setPropertyDescriptions: A(spouseProperty, personNameProperty)];
		[[[personEntity propertyDescriptions] mappedCollection] setPersistent: YES];

		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: personEntity];
	}
	
	// Bezier point entity
	{
		
		
		
	}
	
	// Bezier path entity
	{
		
		
	}
	
	// Text Attribute entity
	{
		
	}
	
	// Text Fragment entity
	{

	}
	
	// Text Tree entity
	{
		
	}
	
	[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
}

+ (void) setUp
{
	[self setUpMetamodel];
}

#endif

- (Class)storeClass
{
	return STORE_CLASS;
}

- (NSURL *)storeURL
{
	return STORE_URL;
}

- (void)instantiateNewContextAndStore
{
	[self discardContextAndStore];

	store = [[[self storeClass] alloc] initWithURL: [self storeURL]];

#ifdef STORE_TEST
	ctx = (id)[[NSNull null] retain];
#else
	ctx = [[COEditingContext alloc] initWithStore: store];
#endif
}

- (id)init
{
	SUPERINIT;
	/* Delete existing db file in case -dealloc didn't run */
	[self deleteStore];
	[self instantiateNewContextAndStore];
	return self;
}

- (void)discardContextAndStore
{
	DESTROY(ctx);
	DESTROY(store);
}

- (void)deleteStore
{
	if ([[NSFileManager defaultManager] fileExistsAtPath: [[self storeURL] path]] == NO)
		 return;

	NSError *error = nil;
	[[NSFileManager defaultManager] removeItemAtPath: [[self storeURL] path]
	                                           error: &error];
	assert(error == nil);
}

- (void)dealloc
{
	assert(ctx != nil);

	[self discardContextAndStore];
	[self deleteStore];
	[super dealloc];
}

@end


@implementation CORevision (TestCommon)

- (NSDictionary *)allValuesAndPropertiesForObjectUUID: (ETUUID *)aUUID
{
	return [self valuesForProperties: nil ofObjectUUID: aUUID fromRevision: nil];
}

@end


@implementation COEditingContext (TestCommon)

- (id)insertObject: (COObject *)sourceObject
{
	COPersistentRoot *context = [self makePersistentRoot];
	COObject *rootObject = [context insertObject: sourceObject withRelationshipConsistency: YES newUUID: NO];

	[context setRootObject: rootObject];

	return rootObject;
}

- (id)insertObjectCopy: (COObject *)sourceObject
{
	COPersistentRoot *context = [self makePersistentRoot];
	COObject *rootObject = [context insertObject: sourceObject withRelationshipConsistency: YES newUUID: YES];
	
	[context setRootObject: rootObject];
	
	return rootObject;
}

@end
