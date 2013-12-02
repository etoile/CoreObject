#import "TestCommon.h"

@interface KeyedRelationshipModel : COObject
@property (nonatomic, strong) NSDictionary *entries;
@end

@implementation KeyedRelationshipModel

@dynamic entries;

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *object = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add 
	// the property descriptions that we will inherit through the parent
	if ([[object name] isEqual: [KeyedRelationshipModel className]] == NO)
		return object;

	ETPropertyDescription *entries =
		[ETPropertyDescription descriptionWithName: @"entries" type: (id)@"COObject"];
	[entries setMultivalued: YES];
	[entries setKeyed: YES];
	[entries setPersistent: YES];

	[object addPropertyDescription: entries];

	return object;
}

@end

/**
 * Tests a keyed collection from { NSString : COObject }, no oppposite.
 */
@interface TestKeyedRelationship : EditingContextTestCase <UKTest>
{
	KeyedRelationshipModel *model;
	OutlineItem *pear;
	OutlineItem *banana;
}
@end

@implementation TestKeyedRelationship

- (id)init
{
	SUPERINIT;
	model = [[ctx insertNewPersistentRootWithEntityName: @"KeyedRelationshipModel"] rootObject];
	pear = [[model objectGraphContext] insertObjectWithEntityName: @"OutlineItem"];
	pear.label = @"Pear";
	banana = [[model objectGraphContext] insertObjectWithEntityName: @"OutlineItem"];
	banana.label = @"Banana";
	return self;
}

- (void)testModelInitialization
{
	[ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: [model persistentRoot]
	                                           inBlock:
	^ (COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		KeyedRelationshipModel *testModel = [testPersistentRoot rootObject];

		UKObjectsEqual([NSDictionary dictionary], [testModel valueForProperty: @"entries"]);
	}];
}

- (void)testSetContent
{
	model.entries = @{ @"pear" : pear, @"banana" : banana };
	
	UKObjectsEqual(S(model, pear, banana), [[model objectGraphContext] insertedObjects]);

	[ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: [model persistentRoot]
	                                           inBlock:
	^ (COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		KeyedRelationshipModel *testModel = [testPersistentRoot rootObject];
		OutlineItem *testPear = testModel.entries[@"pear"];
		UKNotNil(testPear);
		UKObjectsEqual(@"Pear", testPear.label);
		
		OutlineItem *testBanana = testModel.entries[@"banana"];
		UKNotNil(testBanana);
		UKObjectsEqual(@"Banana", testBanana.label);
		
		UKObjectsEqual((@{ @"pear" : testPear, @"banana" : testBanana }), [testModel valueForProperty: @"entries"]);
	}];
}

- (void)testIllegalDirectModificationOfCollection
{
	UKRaisesException([(NSMutableDictionary *)[model entries] setObject: pear forKey: @"fruit"]);
	
	model.entries = @{@"fruit" : banana};
	
	UKRaisesException([(NSMutableDictionary *)[model entries] setObject: pear forKey: @"fruit"]);
}

- (void)testMutation
{
	[model insertObject: pear
	            atIndex: ETUndeterminedIndex
	               hint: [ETKeyValuePair pairWithKey: @"pear" value: pear]
	        forProperty: @"entries"];

	[model insertObject: banana
	            atIndex: ETUndeterminedIndex
	               hint: [ETKeyValuePair pairWithKey: @"banana" value: banana]
	        forProperty: @"entries"];

	UKObjectsEqual((@{ @"pear" : pear, @"banana" : banana }), [model entries]);

	[model removeObject: nil
	            atIndex: ETUndeterminedIndex
	               hint: [ETKeyValuePair pairWithKey: @"pear" value: nil]
	        forProperty: @"entries"];
			
	UKObjectsEqual((@{ @"banana" : banana }), [model entries]);
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
