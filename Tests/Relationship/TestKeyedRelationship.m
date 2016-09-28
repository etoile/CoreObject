/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

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
    model = [ctx insertNewPersistentRootWithEntityName: @"KeyedRelationshipModel"].rootObject;
    pear = [model.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    pear.label = @"Pear";
    banana = [model.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    banana.label = @"Banana";
    return self;
}

- (void)testModelInitialization
{
    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: model.persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testPersistentRoot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           KeyedRelationshipModel *testModel = testPersistentRoot.rootObject;

           UKObjectsEqual(@{},
                          [testModel valueForProperty: @"entries"]);
       }];
}

- (void)testSetContent
{
    model.entries = @{@"pear": pear, @"banana": banana};

    UKObjectsEqual(S(model.UUID, pear.UUID, banana.UUID),
                   model.objectGraphContext.insertedObjectUUIDs);

    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: model.persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testPersistentRoot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           KeyedRelationshipModel *testModel = testPersistentRoot.rootObject;
           OutlineItem *testPear = testModel.entries[@"pear"];
           UKNotNil(testPear);
           UKObjectsEqual(@"Pear", testPear.label);

           OutlineItem *testBanana = testModel.entries[@"banana"];
           UKNotNil(testBanana);
           UKObjectsEqual(@"Banana", testBanana.label);

           UKObjectsEqual((@{@"pear": testPear,
                             @"banana": testBanana}),
                          [testModel valueForProperty: @"entries"]);
       }];
}

- (void)testIllegalDirectModificationOfCollection
{
    UKRaisesException(((NSMutableDictionary *)[model entries])[@"fruit"] = pear);

    model.entries = @{@"fruit": banana};

    UKRaisesException(((NSMutableDictionary *)[model entries])[@"fruit"] = pear);
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

    UKObjectsEqual((@{@"pear": pear, @"banana": banana}), [model entries]);

    [model removeObject: nil
                atIndex: ETUndeterminedIndex
                   hint: [ETKeyValuePair pairWithKey: @"pear" value: nil]
            forProperty: @"entries"];

    UKObjectsEqual((@{@"banana": banana}), [model entries]);
}

- (void)testSerializationRoundTrip
{
    UKObjectsEqual([model entries], [model roundTripValueForProperty: @"entries"]);

    [ctx commit];
    [self checkPersistentRootWithExistingAndNewContext: model.persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           UKObjectsEqual([model entries],
                          [testProot.rootObject entries]);
       }];
}

- (void)testNullDisallowedInCollection
{
    UKRaisesException([model setEntries: @{@"test": [NSNull null]}]);
}

@end
