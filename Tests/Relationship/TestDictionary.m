#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "CODictionary.h"
#import "COObjectGraphContext+Private.h"

@interface Model : COObject
@property (nonatomic, strong) NSDictionary *entries;
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

/**
 * Tests a keyed collection from NSString : NSString
 */
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

- (void)testModelInitialization
{
	[ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: [model persistentRoot]
	                                           inBlock:
	^ (COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		Model *testModel = [testPersistentRoot rootObject];

		UKObjectsEqual([NSDictionary dictionary], [testModel valueForProperty: @"entries"]);
	}];
}

- (void)testSetContent
{
	[model setValue: D(@"boum", @"sound") forProperty: @"entries"];
	
	UKObjectsEqual(S(model), [[model objectGraphContext] insertedObjects]);

	[ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: [model persistentRoot]
	                                           inBlock:
	^ (COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		Model *testModel = [testPersistentRoot rootObject];

		UKObjectsEqual(D(@"boum", @"sound"), [testModel valueForProperty: @"entries"]);
	}];
}

- (void)testIllegalDirectModificationOfCollection
{
	UKRaisesException([(NSMutableDictionary *)[model entries] setObject: @"pear" forKey: @"fruit"]);
	
	model.entries = @{@"name" : @"John" };
	
	UKRaisesException([(NSMutableDictionary *)[model entries] setObject: @"pear" forKey: @"fruit"]);
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
