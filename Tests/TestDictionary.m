#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "CODictionary.h"

@interface Model : COObject
@property (nonatomic, strong) CODictionary *entries;
@end

@implementation Model

@dynamic entries;

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *object = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add 
	// the property descriptions that we will inherit through the parent
	if ([[object name] isEqual: [Model className]] == NO)
		return object;


	ETPropertyDescription *entries =
		[ETPropertyDescription descriptionWithName: @"entries" type: (id)@"NSString"];
	[entries setMultivalued: YES];
	[entries setKeyed: YES];
	[entries setPersistent: YES];

	[object addPropertyDescription: entries];

	return object;
}

@end


@interface TestDictionary : EditingContextTestCase <UKTest>
{
	Model *model;
}
@end

@implementation TestDictionary

- (id)init
{
	SUPERINIT;
	model = [[ctx insertNewPersistentRootWithEntityName: @"Model"] rootObject];
	return self;
}

- (void)testDirectMutation
{
	[[model entries] setObject: @"pear" forKey: @"fruit"];
	[[model entries] setObject: @"leak" forKey: @"vegetable"];
	
	UKObjectsEqual(@"pear", [[model entries] objectForKey: @"fruit"]);
	UKObjectsEqual(@"leak", [[model entries] objectForKey: @"vegetable"]);
	UKObjectsEqual(S(@"fruit", @"vegetable"), SA([[model entries] allKeys]));
	UKObjectsEqual(S(@"pear", @"leak"), SA([[model entries] allValues]));

	[[model entries] removeObjectForKey: @"vegetable"];

	UKObjectsEqual(@"pear", [[model entries] objectForKey: @"fruit"]);
	UKNil([[model entries] objectForKey: @"vegetable"]);
	
	[[model entries] removeAllObjects];

	UKTrue([[model entries] isEmpty]);
}

- (void)testMutation
{
	[model insertObject: @"pear"
	            atIndex: ETUndeterminedIndex
	               hint: [ETKeyValuePair pairWithKey: @"fruit" value: @"pear"]
	        forProperty: @"entries"];

	[model insertObject: @"leak"
	            atIndex: ETUndeterminedIndex
	               hint: [ETKeyValuePair pairWithKey: @"vegetable" value: @"leak"]
	        forProperty: @"entries"];

	UKObjectsEqual(D(@"pear", @"fruit", @"leak", @"vegetable"), [[model entries] content]);

	[model removeObject: nil
	            atIndex: ETUndeterminedIndex
	               hint: [ETKeyValuePair pairWithKey: @"fruit" value: nil]
	        forProperty: @"entries"];
			
	UKObjectsEqual(D(@"leak", @"vegetable"), [[model entries] content]);
}

- (void)testSerializationRoundTrip
{
	UKObjectsEqual([model entries], [model roundTripValueForProperty: @"entries"]);
	
	[ctx commit];
	[self checkPersistentRootWithExistingAndNewContext: [model persistentRoot]
	                                           inBlock:
	^ (COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	{
		UKObjectsEqual([model entries], [[testProot rootObject] entries]);
	}];
}

@end
