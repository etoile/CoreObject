#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COPersistentRoot.h"
#import "COSQLiteStore.h"
#import "TestCommon.h"

NSString * const kCOLabel = @"label";
NSString * const kCOContents = @"contents";
NSString * const kCOParent = @"parentContainer";


@implementation COSQLiteStoreTestCase

- (id) init
{
    self = [super init];
    
    [[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL];
    store = [[COSQLiteStore alloc] initWithURL: STORE_URL];
    
    return self;
}

+ (NSUInteger) sizeOfPath: (NSString *)aPath
{
    NSUInteger result = 0;
    for (NSString *subpath in [[NSFileManager defaultManager] subpathsAtPath: aPath])
    {
		NSError *error = nil;
        NSDictionary *attribs = [[NSFileManager defaultManager] attributesOfItemAtPath: [aPath stringByAppendingPathComponent: subpath] error: &error];
		assert(attribs != nil && error == nil);
        result += [[attribs objectForKey: NSFileSize] longLongValue];
    }
    return result;
}

- (void) dealloc
{
    [store release];
    
    //NSLog(@"Store size is %lld K", (long long)[COSQLiteStoreTestCase sizeOfPath: [STORE_URL path]] / 1024);
    
    [[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL];
    
    [super dealloc];
}

@end

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
        [labelProperty setPersistent: YES];

		ETPropertyDescription *contentsProperty = 
			[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
	
        [contentsProperty setPersistent: YES];
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


		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: outlineEntity];
	}
	
	// Tag entity
	{
		ETEntityDescription *tagEntity = [ETEntityDescription descriptionWithName: @"Tag"];	
		[tagEntity setParent: (id)@"Anonymous.COGroup"];
		
		ETPropertyDescription *tagLabelProperty = [ETPropertyDescription descriptionWithName: @"label"
																		  type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
        [tagLabelProperty setPersistent: YES];

		ETPropertyDescription *contentsProperty = 
			[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
		[contentsProperty setMultivalued: YES];
		[contentsProperty setOrdered: NO];
        [contentsProperty setPersistent: YES];

		[tagEntity setPropertyDescriptions: A(tagLabelProperty, contentsProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: tagEntity];
	}
	
	// Person entity
    
    // We can't / don't want to support this
    
//	{
//		ETEntityDescription *personEntity = [ETEntityDescription descriptionWithName: @"Person"];	
//		[personEntity setParent: (id)@"Anonymous.COObject"];
//		
//		ETPropertyDescription *spouseProperty = [ETPropertyDescription descriptionWithName: @"spouse"
//																					  type: (id)@"Anonymous.Person"];
//		[spouseProperty setMultivalued: NO];
//		[spouseProperty setOpposite: (id)@"Anonymous.Person.spouse"]; // This is a 1:1 relationship
//
//		ETPropertyDescription *personNameProperty = [ETPropertyDescription descriptionWithName: @"name"
//																						type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
//		
//		[personEntity setPropertyDescriptions: A(spouseProperty, personNameProperty)];
//		[[[personEntity propertyDescriptions] mappedCollection] setPersistent: YES];
//
//		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: personEntity];
//	}
	
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
