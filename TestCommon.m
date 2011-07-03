#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COStore.h"
#import "TestCommon.h"

@implementation UKRunner (TestSuiteSetUp)

+ (void) setUpMetamodel
{
	// HACK: make sure COObject's metamodel is set up
	[COObject class];
	
	// Outline item entity
	{
		ETEntityDescription *outlineEntity = [ETEntityDescription descriptionWithName: @"OutlineItem"];
		[outlineEntity setParent: (id)@"Anonymous.COContainer"];
		
		ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
																		  type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
		
		[outlineEntity setPropertyDescriptions: A(labelProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: outlineEntity];
	}
	
	// Tag entity
	{
		ETEntityDescription *tagEntity = [ETEntityDescription descriptionWithName: @"Tag"];	
		[tagEntity setParent: (id)@"Anonymous.COCollection"];
		
		ETPropertyDescription *tagLabelProperty = [ETPropertyDescription descriptionWithName: @"label"
																		  type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
		
		[tagEntity setPropertyDescriptions: A(tagLabelProperty)];
		
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

@end

COEditingContext *NewContext()
{
	COStore *store = [[[COStore alloc] initWithURL: STORE_URL] autorelease];
	assert(store != nil);
	return [[COEditingContext alloc] initWithStore: store];
}

void TearDownContext(COEditingContext *ctx)
{
	assert(ctx != nil);
	[ctx release];
	DELETE_STORE;
}