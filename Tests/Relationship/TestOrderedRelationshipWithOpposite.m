/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestOrderedRelationshipWithOpposite : NSObject <UKTest>
@end

@implementation TestOrderedRelationshipWithOpposite

- (void) testOrderedGroupWithOpposite
{
    COObjectGraphContext *ctx = [COObjectGraphContext new];
    OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
    OrderedGroupWithOpposite *group2 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
    OrderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
    OrderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
    
    group1.contents = @[item1, item2];
    group2.contents = @[item1];
    
    UKObjectsEqual(S(group1, group2), item1.parentGroups);
    UKObjectsEqual(S(group1), item2.parentGroups);

    // Make some changes
    
    group2.contents = @[item1, item2];

    UKObjectsEqual(S(group1, group2), item2.parentGroups);
    
    group1.contents = @[item2];

    UKObjectsEqual(S(group2), item1.parentGroups);
    
    // Reload in another graph
    
    COObjectGraphContext *ctx2 = [COObjectGraphContext new];
    [ctx2 setItemGraph: ctx];
    
    OrderedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: group1.UUID];
    OrderedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: group2.UUID];
    OrderedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: item1.UUID];
    OrderedGroupContent *item2ctx2 = [ctx2 loadedObjectForUUID: item2.UUID];
    
    UKObjectsEqual((@[item2ctx2]), group1ctx2.contents);
    UKObjectsEqual((@[item1ctx2, item2ctx2]), group2ctx2.contents);
    UKObjectsEqual(S(group1ctx2, group2ctx2), item2ctx2.parentGroups);
    UKObjectsEqual(S(group2ctx2), item1ctx2.parentGroups);
    
    // Check the relationship cache
    UKObjectsEqual(S(group2), item1.referringObjects);
    UKObjectsEqual(S(group1, group2), item2.referringObjects);
    
    UKObjectsEqual(S(group2ctx2), item1ctx2.referringObjects);
    UKObjectsEqual(S(group1ctx2, group2ctx2), item2ctx2.referringObjects);
}

- (void) testDuplicatesAutomaticallyRemoved
{
    COObjectGraphContext *ctx = [COObjectGraphContext new];
    OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
    OrderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
    OrderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
    
    group1.contents = @[item1, item2, item1, item1, item1, item2];
    UKTrue(([@[item2, item1] isEqual: group1.contents]
            || [@[item1, item2] isEqual: group1.contents]));
}

- (void) testIllegalDirectModificationOfCollection
{
    COObjectGraphContext *ctx = [COObjectGraphContext new];
    OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
    OrderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
    OrderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"OrderedGroupContent"];
    
    group1.contents = @[item1, item2];
    
    UKRaisesException([(NSMutableArray *)group1.contents removeObjectAtIndex: 1]);
}

- (void)testNullDisallowedInCollection
{
    COObjectGraphContext *ctx = [COObjectGraphContext new];
    OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
    
    UKRaisesException([group1 setContents: @[[NSNull null]]]);
}

- (void) testWrongEntityTypeInCollection
{
    COObjectGraphContext *ctx = [COObjectGraphContext new];
    OrderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"OrderedGroupWithOpposite"];
    OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
    
    UKRaisesException(group1.contents = @[item1]);
}

@end


/**
 * For some general code comments that apply to all tests, see
 * -testTargetPersistentRootUndeletion, -testSourcePersistentRootUndeletion and
 * -testSourcePersistentRootUndeletionForReferenceToSpecificBranch.
 */
@interface TestCrossPersistentRootOrderedRelationshipWithOpposite : EditingContextTestCase <UKTest>
{
    OrderedGroupWithOpposite *group1;
    OrderedGroupContent *item1;
    OrderedGroupContent *item2;
    OrderedGroupContent *otherItem1;
    OrderedGroupWithOpposite *otherGroup1;
    
    // Convenience - persistent root UUIDs
    ETUUID *group1uuid;
    ETUUID *item1uuid;
    ETUUID *item2uuid;
}

@end

@implementation TestCrossPersistentRootOrderedRelationshipWithOpposite

- (id)init
{
    SUPERINIT;
    
    ctx.unloadingBehavior = COEditingContextUnloadingBehaviorManual;

    @autoreleasepool {
        group1 = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupWithOpposite"].rootObject;
        item1 = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupContent"].rootObject;
        item1.label = @"current";
        item2 = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupContent"].rootObject;
        group1.label = @"current";
        group1.contents = @[item1, item2];
        [ctx commit];

        otherItem1 = [item1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
        otherItem1.label = @"other";
        otherGroup1 = [group1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
        otherGroup1.label = @"other";
        [ctx commit];
    }

    group1uuid = group1.persistentRoot.UUID;
    item1uuid = item1.persistentRoot.UUID;
    item2uuid = item2.persistentRoot.UUID;
    
    return self;
}

#define CHECK_BLOCK_ARGS COEditingContext *testCtx, OrderedGroupWithOpposite *testGroup1, OrderedGroupContent *testItem1, OrderedGroupContent *testItem2, OrderedGroupContent *testOtherItem1, OrderedGroupWithOpposite *testOtherGroup1, OrderedGroupWithOpposite *testCurrentGroup1, OrderedGroupContent *testCurrentItem1, OrderedGroupContent *testCurrentItem2, BOOL isNewContext

- (void)checkPersistentRootsWithExistingAndNewContextInBlock: (void (^)(CHECK_BLOCK_ARGS))block
{
    [self checkPersistentRootWithExistingAndNewContext: group1.persistentRoot
                                               inBlock:
     ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
    {
        OrderedGroupWithOpposite *testGroup1 = testPersistentRoot.rootObject;
        OrderedGroupContent *testItem1 =
            [testCtx persistentRootForUUID: item1.persistentRoot.UUID].rootObject;
        OrderedGroupContent *testItem2 =
            [testCtx persistentRootForUUID: item2.persistentRoot.UUID].rootObject;
        OrderedGroupContent *testOtherItem1 =
            [testItem1.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
        OrderedGroupWithOpposite *testOtherGroup1 =
            [testGroup1.persistentRoot branchForUUID: otherGroup1.branch.UUID].rootObject;
        
        OrderedGroupWithOpposite *testCurrentGroup1 = testPersistentRoot.currentBranch.rootObject;
        OrderedGroupContent *testCurrentItem1 =
            [testCtx persistentRootForUUID: item1.persistentRoot.UUID].currentBranch.rootObject;
        OrderedGroupContent *testCurrentItem2 =
            [testCtx persistentRootForUUID: item2.persistentRoot.UUID].currentBranch.rootObject;
        OrderedGroupContent *testCurrentOtherItem1 =
            [testCtx persistentRootForUUID: otherItem1.persistentRoot.UUID].currentBranch.rootObject;
        OrderedGroupWithOpposite *testCurrentOtherGroup1 =
            [testCtx persistentRootForUUID: otherGroup1.persistentRoot.UUID].currentBranch.rootObject;
    
        UKObjectsSame(testCurrentGroup1, testCurrentOtherGroup1);
        UKObjectsSame(testCurrentItem1, testCurrentOtherItem1);
        
        block(testCtx, testGroup1, testItem1, testItem2, testOtherItem1, testOtherGroup1, testCurrentGroup1, testCurrentItem1, testCurrentItem2, isNewContext);
    }];
}

#pragma mark - Relationship Target Deletion Tests

- (void)testTargetPersistentRootDeletion
{
    item1.persistentRoot.deleted = YES;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem2), testGroup1.contents);
        UKTrue(testItem1.parentGroups.isEmpty);

        UKObjectsEqual(A(testItem2), testCurrentGroup1.contents);
        UKTrue(testCurrentItem1.parentGroups.isEmpty);
    }];
}

- (void)testTargetPersistentRootUndeletion
{
    item1.persistentRoot.deleted = YES;
    [ctx commit];
    
    item1.persistentRoot.deleted = NO;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem1, testItem2), testGroup1.contents);
        UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

        // Bidirectional cross persistent root relationships are limited to the
        // tracking branch, this means item1 in the non-tracking current branch
        // doesn't appear in testCurrentGroup1.contents and doesn't refer to it
        // with an inverse relationship (-referringObjectsForPropertyInTarget:
        // simulates it though).
        // Bidirectional cross persistent root relationships are supported
        // accross current branches, but materialized accross tracking branches
        // in memory (they are not visible accross the current branches in memory).
        UKObjectsEqual(A(testItem1, testItem2), testCurrentGroup1.contents);
        UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
    }];
}

- (void)testTargetPersistentRootDeletionForReferenceToSpecificBranch
{
    group1.contents = @[otherItem1, item2];
    [ctx commit];

    item1.persistentRoot.deleted = YES;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem2), testGroup1.contents);
        UKTrue(testItem1.parentGroups.isEmpty);
        
        UKObjectsEqual(A(testItem2), testCurrentGroup1.contents);
        UKTrue(testCurrentItem1.parentGroups.isEmpty);
    }];
}

- (void)testTargetPersistentRootUndeletionForReferenceToSpecificBranch
{
    group1.contents = @[otherItem1, item2];
    [ctx commit];

    item1.persistentRoot.deleted = YES;
    [ctx commit];
    
    item1.persistentRoot.deleted = NO;
    [ctx commit];
    
    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKStringsEqual(@"other", testOtherItem1.label);
        UKStringsEqual(@"current", testItem1.label);
        UKObjectsEqual(A(testOtherItem1, testItem2), testGroup1.contents);
        UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
        
        UKObjectsEqual(A(testOtherItem1, testItem2), testCurrentGroup1.contents);
        UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
    }];
}

/**
 * The current branch cannot be deleted, so we cannot write a test method
 * -testTargetBranchDeletion analog to -testTargetPersistentRootDeletion
 */
- (void)testTargetBranchDeletionForReferenceToSpecificBranch
{
    group1.contents = @[otherItem1, item2];
    [ctx commit];
    
    otherItem1.branch.deleted = YES;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem2), testGroup1.contents);
        UKTrue(testOtherItem1.parentGroups.isEmpty);

        UKObjectsEqual(A(testItem2), testCurrentGroup1.contents);
        UKTrue(testCurrentItem1.parentGroups.isEmpty);

    }];
}

- (void)testTargetBranchUndeletionForReferenceToSpecificBranch
{
    group1.contents = @[otherItem1, item2];
    [ctx commit];
    
    otherItem1.branch.deleted = YES;
    [ctx commit];

    otherItem1.branch.deleted = NO;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKStringsEqual(@"other", testOtherItem1.label);
        UKStringsEqual(@"current", testItem1.label);
        UKObjectsEqual(A(testOtherItem1, testItem2), testGroup1.contents);
        UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);

        UKObjectsEqual(A(testOtherItem1, testItem2), testCurrentGroup1.contents);
        UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
    }];
}


#pragma mark - Relationship Source Deletion Tests

- (void)testSourcePersistentRootDeletion
{
    group1.persistentRoot.deleted = YES;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem1, testItem2), testGroup1.contents);
        UKTrue(testItem1.parentGroups.isEmpty);

        UKObjectsEqual(A(testItem1, testItem2), testCurrentGroup1.contents);
        UKTrue(testCurrentItem1.parentGroups.isEmpty);
    }];
}

- (void)testSourcePersistentRootUndeletion
{
    group1.persistentRoot.deleted = YES;
    [ctx commit];

    group1.persistentRoot.deleted = NO;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem1, testItem2), testGroup1.contents);
        // testCurrentGroup1 and testOtherGroup1 present in -referringObjects are hidden by -referringObjectsForPropertyInTarget:
        UKObjectsEqual(S(testGroup1), testItem1.parentGroups);
         
        UKObjectsEqual(A(testItem1, testItem2), testCurrentGroup1.contents);
        // testGroup1 missing from -referringObjects is added by -referringObjectsForPropertyInTarget:
        UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
    }];
}

- (void)testSourcePersistentRootDeletionForReferenceToSpecificBranch
{
    otherGroup1.contents = @[item1, item2];
    [ctx commit];

    otherGroup1.persistentRoot.deleted = YES;
    [ctx commit];

    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem1, testItem2), testOtherGroup1.contents);
        UKTrue(testItem1.parentGroups.isEmpty);
        
        UKObjectsEqual(A(testItem1, testItem2), testCurrentGroup1.contents);
        UKTrue(testCurrentItem1.parentGroups.isEmpty);
    }];
}

- (void)testSourcePersistentRootUndeletionForReferenceToSpecificBranch
{
    otherGroup1.contents = @[item1, item2];
    [ctx commit];

    otherGroup1.persistentRoot.deleted = YES;
    [ctx commit];
    
    otherGroup1.persistentRoot.deleted = NO;
    [ctx commit];
    
    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKStringsEqual(@"other", testOtherGroup1.label);
        UKStringsEqual(@"current", testGroup1.label);
        UKObjectsEqual(A(testItem1, testItem2), testOtherGroup1.contents);
        // Bidirectional inverse multivalued relationship always point to a
        // single source object owned by the tracking branch, even when the
        // relationship source object exist in multiple branches.
        // For a parent-to-child relationship, reporting every branch source
        // object as a distinct parent doesn't make sense, since conceptually
        // they are all the same parent from the child viewpoint.
        UKObjectsEqual(S(testGroup1), testItem1.parentGroups);
        
        UKObjectsEqual(A(testItem1, testItem2), testCurrentGroup1.contents);
        UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
    }];
}

- (void)testSourceBranchDeletionForReferenceToSpecificBranch
{
    otherGroup1.contents = @[item1, item2];
    [ctx commit];
    
    otherGroup1.branch.deleted = YES;
    [ctx commit];
    
    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKObjectsEqual(A(testItem1, testItem2), testOtherGroup1.contents);
        // The tracking branch is not deleted, so testItem1 parent is untouched,
        // see comment in -testSourcePersistentRootUndeletionForReferenceToSpecificBranch
        UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

        UKObjectsEqual(A(testItem1, testItem2), testCurrentGroup1.contents);
        UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
    }];
}

- (void)testSourceBranchUndeletionForReferenceToSpecificBranch
{
    otherGroup1.contents = @[item1, item2];
    [ctx commit];
    
    otherGroup1.branch.deleted = YES;
    [ctx commit];
    
    otherGroup1.branch.deleted = NO;
    [ctx commit];
    
    [self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
    {
        UKStringsEqual(@"other", testOtherItem1.label);
        UKStringsEqual(@"current", testItem1.label);
        UKObjectsEqual(A(testItem1, testItem2), testGroup1.contents);
        UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

        UKObjectsEqual(A(testItem1, testItem2), testCurrentGroup1.contents);
        UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
    }];
}

- (void) testTargetPersistentRootLazyLoading
{
    COEditingContext *ctx2 = [self newContext];
    
    // First, all persistent roots should be unloaded.
    UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
    UKFalse(ctx2.hasChanges);
    
    // Load group1
    OrderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
    UKObjectsEqual(@"current", group1ctx2.label);
    
    // Ensure both persistent roots are still unloaded
    UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
    UKFalse(ctx2.hasChanges);
    
    // Access collection to trigger loading
    OrderedGroupContent *item1ctx2 = group1ctx2.contents[0];
    OrderedGroupContent *item2ctx2 = group1ctx2.contents[1];
    UKObjectsEqual(item1.UUID, item1ctx2.UUID);
    UKObjectsEqual(item2.UUID, item2ctx2.UUID);
    UKNotNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
    UKNotNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
    UKFalse(ctx2.hasChanges);

    COPath *item1Path = [COPath pathWithPersistentRoot: item1uuid];
    COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];

    UKNil([ctx2.deadRelationshipCache referringObjectsForPath: item1Path]);
    UKNil([ctx2.deadRelationshipCache referringObjectsForPath: item2Path]);
}

- (void)testTargetBranchLazyLoading
{
    COPath *otherItem1Path = [COPath pathWithPersistentRoot: item1uuid
                                                     branch: otherItem1.branch.UUID];
    COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];
    
    group1.contents = @[otherItem1, item2];
    [ctx commit];
    
    COEditingContext *ctx2 = [self newContext];
    
    // First, all persistent roots should be unloaded.
    UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
    UKFalse(ctx2.hasChanges);
    
    // Load group1
    OrderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
    UKObjectsEqual(@"current", group1ctx2.label);
    
    // Check group1ctx2.contents without triggering loading
    UKNotNil(otherItem1.branch.UUID);
    UKObjectsEqual(A(otherItem1Path, item2Path), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
    
    UKObjectsEqual(A(group1ctx2), [[ctx2.deadRelationshipCache referringObjectsForPath: otherItem1Path] allObjects]);
    UKObjectsEqual(A(group1ctx2), [[ctx2.deadRelationshipCache referringObjectsForPath: item2Path] allObjects]);
    
    // Ensure item1 persistent root is still unloaded
    UKNil([ctx2 loadedPersistentRootForUUID: item1.persistentRoot.UUID]);
    UKFalse(ctx2.hasChanges);
    
    // Load item1, but not the other branch yet
    OrderedGroupContent *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
    UKObjectsEqual(item1.UUID, item1ctx2.UUID);
    UKNotNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
    UKObjectsEqual(A(otherItem1Path, item2Path), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
    UKFalse(ctx2.hasChanges);
    
    // Finally load the other branch.
    // This should trigger group1ctx2 to unfault its reference.
    OrderedGroupContent *otherItem1ctx2 = [item1ctx2.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
    UKObjectsEqual(A(otherItem1ctx2), [group1ctx2 serializableValueForStorageKey: @"contents"]);
    UKObjectsEqual(A(otherItem1ctx2, item2Path), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
    UKFalse(ctx2.hasChanges);

    UKNil([ctx2.deadRelationshipCache referringObjectsForPath: otherItem1Path]);
    UKObjectsEqual(A(group1ctx2), [[ctx2.deadRelationshipCache referringObjectsForPath: item2Path] allObjects]);
}

- (void) testSourcePersistentRootLazyLoading
{
    COEditingContext *ctx2 = [self newContext];
    
    // First, all persistent roots should be unloaded.
    UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
    UKFalse(ctx2.hasChanges);
    
    // Load item1
    OrderedGroupContent *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
    
    // Because group1 is not currently loaded, we have no way of
    // knowing that it has a cross-reference to item1.
    // So item1ctx2.parentGroups is currently empty.
    // This is sort of a leak in the abstraction of lazy loading.
    UKObjectsEqual(S(), item1ctx2.parentGroups);
    
    // Load group1
    OrderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
    UKObjectsEqual(@"current", group1ctx2.label);
    
    // That should have updated the parentGroups property
    UKObjectsEqual(S(group1ctx2), item1ctx2.parentGroups);
    
    UKFalse(ctx2.hasChanges);

    COPath *item1Path = [COPath pathWithPersistentRoot: item1uuid];
    COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];
    
    UKNil([ctx2.deadRelationshipCache referringObjectsForPath: item1Path]);
    UKObjectsEqual(A(group1ctx2), [[ctx2.deadRelationshipCache referringObjectsForPath: item2Path] allObjects]);
}

- (void) testSourcePersistentRootLazyLoadingReverseOrder
{
    COEditingContext *ctx2 = [self newContext];
    
    // First, all persistent roots should be unloaded.
    UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
    UKNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
    UKFalse(ctx2.hasChanges);
    
    // Load group1
    OrderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;

    // Ensure the references are faulted
    UKObjectsEqual(A([COPath pathWithPersistentRoot: item1uuid],
                     [COPath pathWithPersistentRoot: item2uuid]), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
    
    // Load item1
    OrderedGroupContent *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
    
    // Check that the reference in group1 was unfaulted by the loading of item1
    UKObjectsEqual(A(item1ctx2,
                     [COPath pathWithPersistentRoot: item2uuid]), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
    
    UKObjectsEqual(S(group1ctx2), item1ctx2.parentGroups);
    
    UKFalse(ctx2.hasChanges);

    COPath *item1Path = [COPath pathWithPersistentRoot: item1uuid];
    COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];
    
    UKNil([ctx2.deadRelationshipCache referringObjectsForPath: item1Path]);
    UKObjectsEqual(A(group1ctx2), [[ctx2.deadRelationshipCache referringObjectsForPath: item2Path] allObjects]);
}

- (void)testSourcePersistentRootUnloadingOnDeletion
{
    ctx.unloadingBehavior = COEditingContextUnloadingBehaviorOnDeletion;

    @autoreleasepool {
        item1.persistentRoot.deleted = YES;
        [ctx commit];
        item1 = nil;
    }

    UKObjectsEqual(A([COPath pathWithPersistentRoot: item1uuid], item2),
                   [[group1 serializableValueForStorageKey: @"contents"] allReferences]);

    @autoreleasepool {
        group1.persistentRoot.deleted = YES;
        [ctx commit];
        group1 = nil;
    }

    UKTrue(item2.parentGroups.isEmpty);

    group1 = [ctx persistentRootForUUID: group1uuid].rootObject;

    UKObjectsEqual(A([COPath pathWithPersistentRoot: item1uuid], item2),
                   [[group1 serializableValueForStorageKey: @"contents"] allReferences]);

    // Force lazy loading of item1
    NSArray *reloadedContents = group1.contents;
    item1 = [ctx persistentRootForUUID: item1uuid].rootObject;

    UKObjectsEqual(A(item2), reloadedContents);
    // group1 is deleted so it's hidden by the incoming relationship cache
    UKTrue(item2.parentGroups.isEmpty);
}

- (void)testSourcePersistentRootManualUnloading
{
    @autoreleasepool {
        [ctx unloadPersistentRoot: item1.persistentRoot];
        item1 = nil;
    }

    UKObjectsEqual(A([COPath pathWithPersistentRoot: item1uuid], item2),
                   [[group1 serializableValueForStorageKey: @"contents"] allReferences]);
    
    @autoreleasepool {
        [ctx unloadPersistentRoot: group1.persistentRoot];
        group1 = nil;
    }
    
    UKTrue(item2.parentGroups.isEmpty);

    group1 = [ctx persistentRootForUUID: group1uuid].rootObject;
    // Force lazy loading of item1
    NSArray *reloadedContents = group1.contents;
    item1 = [ctx persistentRootForUUID: item1uuid].rootObject;

    UKObjectsEqual(A(item1, item2), reloadedContents);
    UKObjectsEqual(S(group1), item2.parentGroups);
}

@end
