#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
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

	pool = [NSAutoreleasePool new];
	store = [[[self storeClass] alloc] initWithURL: STORE_URL];

#ifdef STORE_TEST
	ctx = (id)[[NSNull null] retain];
#else
	ctx = [[COEditingContext alloc] initWithStore: store];
#endif
}

- (id)init
{
	SUPERINIT;
	[self instantiateNewContextAndStore];
	return self;
}

- (void)discardContextAndStore
{
	DESTROY(pool);
	DESTROY(ctx);
	DESTROY(store);
}

- (void)deleteStore
{
	[[NSFileManager defaultManager] removeFileAtPath: [STORE_URL path] handler: nil];
}

- (void)dealloc
{
	assert(ctx != nil);

	[self discardContextAndStore];
	[self deleteStore];
	[super dealloc];
}

@end

#ifndef STORE_TEST
COEditingContext *NewContext(COStore* store)
{
	return [[COEditingContext alloc] initWithStore: store];
}

void TearDownContext(COEditingContext *ctx)
{
	assert(ctx != nil);
	[ctx release];
	DELETE_STORE;
}
#endif
