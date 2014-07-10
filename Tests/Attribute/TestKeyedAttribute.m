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

// TODO: We should possibly add a ownerUUID attribute to dictionary items,
// and use an assertion in -addItem:markAsInserted: that ensure the loading
// item graph contains the owner UUID each time an additional item is encountered.
//
// if ([anItem isAdditionalItem])
// {
//   ETAssert([[_loadingItemGraph itemUUIDs] containsObject: [anItem ownerUUID]]);
//   return;
// }
//
// Or model the dictionary relationship as a to-one bidirectional and implicitly
// composite.
- (void)testItemGraphProtocol
{
	ETUUID *dictUUID = [[[model additionalStoreItemUUIDs] allValues] firstObject];
	COItem *dictItem = [[model objectGraphContext] itemForUUID: dictUUID];
	COItem *modelItem = [[model objectGraphContext] itemForUUID: [model UUID]];

	UKObjectsEqual(dictUUID, [dictItem UUID]);
	UKStringsEqual(@"CODictionary", [dictItem valueForAttribute: kCOObjectEntityNameProperty]);

	UKObjectsEqual([model UUID], [modelItem UUID]);
	UKObjectsEqual(dictUUID, [modelItem valueForAttribute: @"entries"]);

	COMutableItem *newDictItem = [dictItem mutableCopy];
	
	/* Dictionary Item Insertion */
	
	[newDictItem setValue: @"tic"
	         forAttribute: @"sound"
	                 type: kCOTypeString];

	[[model objectGraphContext] insertOrUpdateItems: A(newDictItem)];

	UKObjectsEqual(D(@"tic", @"sound"), [model valueForProperty: @"entries"]);
	
	/* Dictionary Item Update */
	
	[newDictItem setValue: @"boum"
	         forAttribute: @"sound"
	                 type: kCOTypeString];

	[[model objectGraphContext] insertOrUpdateItems: A(newDictItem)];
	
	UKObjectsEqual(D(@"boum", @"sound"), [model valueForProperty: @"entries"]);

	/* Model Item Update */
	
	[[model objectGraphContext] insertOrUpdateItems: A(modelItem)];

	UKObjectsEqual(D(@"boum", @"sound"), [model valueForProperty: @"entries"]);
	
	/* Mixed Item Update */

	[newDictItem setValue: @"here"
	         forAttribute: @"location"
	                 type: kCOTypeString];

	[[model objectGraphContext] insertOrUpdateItems: A(newDictItem, modelItem)];

	UKObjectsEqual(D(@"boum", @"sound", @"here", @"location"), [model valueForProperty: @"entries"]);
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
	
	UKObjectsEqual(S(model.UUID), [[model objectGraphContext] insertedObjectUUIDs]);

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
