#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COStore.h"
#import "TestCommon.h"


@implementation TestCommon

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

- (Class)storeClass
{
	return STORE_CLASS;
}

@end

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
