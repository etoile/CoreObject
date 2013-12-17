/*
	Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

	Date:  October 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "CODictionary.h"
#import "COObjectGraphContext+Private.h"

/**
 * Tests a keyed collection from NSString : NSString
 */
@interface TestKeyedAttribute : EditingContextTestCase <UKTest>
{
	KeyedAttributeModel *model;
}
@end

@implementation TestKeyedAttribute

- (id)init
{
	SUPERINIT;
	model = [[ctx insertNewPersistentRootWithEntityName: @"KeyedAttributeModel"] rootObject];
	return self;
}

- (void)testAdditionalStoreItemUUIDs
{
	NSArray *keyedProperties = [[model additionalStoreItemUUIDs] allKeys];

	UKIntsEqual(1, [keyedProperties count]);
	UKStringsEqual(@"entries", [keyedProperties firstObject]);
}

/**
 * Dictionaries are always marked as damaged, and (de)serialized at the same
 * time than their owner object. As a result, deserializing a single object 
 * and no other objects, either the model or the dictionary using 
 * -[COObjectGraphContext insertOrUpdateItems:], is a border case. 
 * 
 * For now, we don't support it to prevent breaking -awakeFromDeserialization 
 * (all non-relationship collections must be deserialized and valid inside 
 * -awakeFromDeserialization).
 *
 * It is possible to respect -[COItemGraph insertOrUpdatedItems:] in all cases, 
 * but this means some extra complexity in COObjectGraphContext, and no 
 * reports/exceptions about incorrect additional item loading (a dictionary item 
 * missing an owner or the reverse).
 */
- (void)testItemGraphProtocol
{
	ETUUID *dictUUID = [[[model additionalStoreItemUUIDs] allValues] firstObject];
	COItem *dictItem = [[model objectGraphContext] itemForUUID: dictUUID];
	COItem *modelItem = [[model objectGraphContext] itemForUUID: [model UUID]];

	UKObjectsEqual(dictUUID, [dictItem UUID]);
	UKStringsEqual(@"CODictionary", [dictItem valueForAttribute: kCOObjectEntityNameProperty]);

	UKObjectsEqual([model UUID], [modelItem UUID]);
	UKObjectsEqual(dictUUID, [modelItem valueForAttribute: @"entries"]);
	
	/* Test Dictionary Item Insertion */

	[model setValue: D(@"boum", @"sound") forProperty: @"entries"];
	
	// TODO: We should possibly add a ownerUUID attribute to dictionary items,
	// and use an assertion in -addItem:markAsInserted: that ensure the loading
	// item graph contains the owner UUID each time an additional item is encountered.
	//
	// if ([anItem isAdditionalItem])
	// {
	//   ETAssert([[_loadingItemGraph itemUUIDs] containsObject: [anItem ownerUUID]]);
	//   return;
	// }
	UKDoesNotRaiseException([[model objectGraphContext] insertOrUpdateItems: A(dictItem)]);
	UKObjectsEqual(D(@"boum", @"sound"), [model valueForProperty: @"entries"]);

	/* Test KeyedAttributeModel Item Insertion */

	[model setValue: D(@"boum", @"sound") forProperty: @"entries"];
	
	UKRaisesException([[model objectGraphContext] insertOrUpdateItems: A(modelItem)]);
	UKObjectsEqual(D(@"boum", @"sound"), [model valueForProperty: @"entries"]);
}

- (void)testKeyedAttributeModelInitialization
{
	[ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: [model persistentRoot]
	                                           inBlock:
	^ (COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		KeyedAttributeModel *testModel = [testPersistentRoot rootObject];

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
		KeyedAttributeModel *testModel = [testPersistentRoot rootObject];

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

- (void)testNullDisallowedInCollection
{
	UKRaisesException([model setEntries: @{@"Test" : [NSNull null]}]);
}

@end
