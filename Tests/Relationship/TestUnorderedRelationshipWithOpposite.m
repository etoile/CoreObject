/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestUnorderedRelationshipWithOpposite : NSObject <UKTest>
@end

@implementation TestUnorderedRelationshipWithOpposite

- (void) testUnorderedGroupWithOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupWithOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	UnorderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	
	group1.contents = S(item1, item2);
	group2.contents = S(item1);
	
	UKObjectsEqual(S(group1, group2), [item1 parentGroups]);
	UKObjectsEqual(S(group1), [item2 parentGroups]);
	
	// Make some changes
	
	group2.contents = S(item1, item2);
	
	UKObjectsEqual(S(group1, group2), [item2 parentGroups]);
	
	group1.contents = S(item2);
	
	UKObjectsEqual(S(group2), [item1 parentGroups]);
	
	// Reload in another graph
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnorderedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnorderedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	UnorderedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	UnorderedGroupContent *item2ctx2 = [ctx2 loadedObjectForUUID: [item2 UUID]];
	
	UKObjectsEqual(S(item2ctx2), [group1ctx2 contents]);
	UKObjectsEqual(S(item1ctx2, item2ctx2), [group2ctx2 contents]);
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item2ctx2 parentGroups]);
	UKObjectsEqual(S(group2ctx2), [item1ctx2 parentGroups]);
}

- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	UnorderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	
	group1.contents = S(item1, item2);
	
	UKRaisesException([(NSMutableSet *)group1.contents removeObject: item1]);
}

- (void)testNullDisallowedInCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	
	UKRaisesException([group1 setContents: S([NSNull null])]);
}

- (void) testWrongEntityTypeInCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	UKRaisesException([group1 setContents: S(item1)]);
}

@end


/**
 * For some general code comments that apply to all tests, see
 * -testTargetPersistentRootUndeletion, -testSourcePersistentRootUndeletion and
 * -testSourcePersistentRootUndeletionForReferenceToSpecificBranch.
 */
@interface TestCrossPersistentRootUnorderedRelationshipWithOpposite : EditingContextTestCase <UKTest>
{
	UnorderedGroupWithOpposite *group1;
	UnorderedGroupContent *item1;
	UnorderedGroupContent *item2;
	UnorderedGroupContent *otherItem1;
	UnorderedGroupWithOpposite *otherGroup1;
	
	// Convenience - persistent root UUIDs
	ETUUID *group1uuid;
	ETUUID *item1uuid;
	ETUUID *item2uuid;
}

@end

@implementation TestCrossPersistentRootUnorderedRelationshipWithOpposite

- (id)init
{
	SUPERINIT;
	
	ctx.unloadingBehavior = COEditingContextUnloadingBehaviorManual;

	group1 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupWithOpposite"].rootObject;
	item1 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupContent"].rootObject;
	item1.label = @"current";
	item2 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupContent"].rootObject;
	group1.label = @"current";
	group1.contents = S(item1, item2);
	[ctx commit];

	otherItem1 = [item1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherItem1.label = @"other";
	otherGroup1 = [group1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherGroup1.label = @"other";
	[ctx commit];
	
	group1uuid = group1.persistentRoot.UUID;
	item1uuid = item1.persistentRoot.UUID;
	item2uuid = item2.persistentRoot.UUID;
	
	return self;
}

#define CHECK_BLOCK_ARGS COEditingContext *testCtx, UnorderedGroupWithOpposite *testGroup1, UnorderedGroupContent *testItem1, UnorderedGroupContent *testItem2, UnorderedGroupContent *testOtherItem1, UnorderedGroupWithOpposite *testOtherGroup1, UnorderedGroupWithOpposite *testCurrentGroup1, UnorderedGroupContent *testCurrentItem1, UnorderedGroupContent *testCurrentItem2, BOOL isNewContext

- (void)checkPersistentRootsWithExistingAndNewContextInBlock: (void (^)(CHECK_BLOCK_ARGS))block
{
	[self checkPersistentRootWithExistingAndNewContext: group1.persistentRoot
											   inBlock:
	 ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		UnorderedGroupWithOpposite *testGroup1 = testPersistentRoot.rootObject;
		UnorderedGroupContent *testItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].rootObject;
		UnorderedGroupContent *testItem2 =
			[testCtx persistentRootForUUID: item2.persistentRoot.UUID].rootObject;
		UnorderedGroupContent *testOtherItem1 =
			[testItem1.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
		UnorderedGroupWithOpposite *testOtherGroup1 =
			[testGroup1.persistentRoot branchForUUID: otherGroup1.branch.UUID].rootObject;
		
		UnorderedGroupWithOpposite *testCurrentGroup1 = testPersistentRoot.currentBranch.rootObject;
		UnorderedGroupContent *testCurrentItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].currentBranch.rootObject;
		UnorderedGroupContent *testCurrentItem2 =
			[testCtx persistentRootForUUID: item2.persistentRoot.UUID].currentBranch.rootObject;
		UnorderedGroupContent *testCurrentOtherItem1 =
			[testCtx persistentRootForUUID: otherItem1.persistentRoot.UUID].currentBranch.rootObject;
		UnorderedGroupWithOpposite *testCurrentOtherGroup1 =
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
		UKObjectsEqual(S(testItem2), testGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);

		UKObjectsEqual(S(testItem2), testCurrentGroup1.contents);
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
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

		// Bidirectional cross persistent root relationships are limited to the
		// tracking branch, this means item1 in the non-tracking current branch
		// doesn't appear in testCurrentGroup1.contents and doesn't refer to it
		// with an inverse relationship (-referringObjectsForPropertyInTarget:
		// simulates it though).
		// Bidirectional cross persistent root relationships are supported
		// accross current branches, but materialized accross tracking branches
		// in memory (they are not visible accross the current branches in memory).
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testTargetPersistentRootDeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem2), testGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);
		
		UKObjectsEqual(S(testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

- (void)testTargetPersistentRootUndeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];
	
	item1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(S(testOtherItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
		
		UKObjectsEqual(S(testOtherItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
	}];
}

/**
 * The current branch cannot be deleted, so we cannot write a test method
 * -testTargetBranchDeletion analog to -testTargetPersistentRootDeletion
 */
- (void)testTargetBranchDeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem2), testGroup1.contents);
		UKTrue(testOtherItem1.parentGroups.isEmpty);

		UKObjectsEqual(S(testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);

	}];
}

- (void)testTargetBranchUndeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	otherItem1.branch.deleted = NO;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(S(testOtherItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);

		UKObjectsEqual(S(testOtherItem1, testItem2), testCurrentGroup1.contents);
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
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);

		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
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
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		// testCurrentGroup1 and testOtherGroup1 present in -referringObjects are hidden by -referringObjectsForPropertyInTarget:
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);
		 
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		// testGroup1 missing from -referringObjects is added by -referringObjectsForPropertyInTarget:
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testSourcePersistentRootDeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testOtherGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);
		
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

- (void)testSourcePersistentRootUndeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];
	
	otherGroup1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherGroup1.label);
		UKStringsEqual(@"current", testGroup1.label);
		UKObjectsEqual(S(testItem1, testItem2), testOtherGroup1.contents);
		// Bidirectional inverse multivalued relationship always point to a
		// single source object owned by the tracking branch, even when the
		// relationship source object exist in multiple branches.
		// For a parent-to-child relationship, reporting every branch source
		// object as a distinct parent doesn't make sense, since conceptually
		// they are all the same parent from the child viewpoint.
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);
		
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testSourceBranchDeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testOtherGroup1.contents);
		// The tracking branch is not deleted, so testItem1 parent is untouched,
		// see comment in -testSourcePersistentRootUndeletionForReferenceToSpecificBranch
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testSourceBranchUndeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	otherGroup1.branch.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
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
	UKFalse([ctx2 hasChanges]);
	
	// Load group1
	UnorderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	UKObjectsEqual(@"current", group1ctx2.label);
	
	// Ensure both persistent roots are still unloaded
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Access collection to trigger loading
	UKIntsEqual(2, group1ctx2.contents.count);
	UnorderedGroupContent *item1ctx2 = [[group1ctx2.contents objectsPassingTest:^(id obj, BOOL*stop){ return [[obj UUID] isEqual: item1.UUID]; }] anyObject];
	UnorderedGroupContent *item2ctx2 = [[group1ctx2.contents objectsPassingTest:^(id obj, BOOL*stop){ return [[obj UUID] isEqual: item2.UUID]; }] anyObject];
	UKObjectsEqual(item1.UUID, item1ctx2.UUID);
	UKObjectsEqual(item2.UUID, item2ctx2.UUID);
	UKNotNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKNotNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
	UKFalse([ctx2 hasChanges]);

	COPath *item1Path = [COPath pathWithPersistentRoot: item1uuid];
	COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];

	UKNil([[ctx2 deadRelationshipCache] referringObjectsForPath: item1Path]);
	UKNil([[ctx2 deadRelationshipCache] referringObjectsForPath: item2Path]);
}

- (void)testTargetBranchLazyLoading
{
	COPath *otherItem1Path = [COPath pathWithPersistentRoot: item1uuid
													 branch: otherItem1.branch.UUID];
	COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];
	
	group1.contents = S(otherItem1, item2);
	[ctx commit];
	
	COEditingContext *ctx2 = [self newContext];
	
	// First, all persistent roots should be unloaded.
	UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Load group1
	UnorderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	UKObjectsEqual(@"current", group1ctx2.label);
	
	// Check group1ctx2.contents without triggering loading
	UKNotNil(otherItem1.branch.UUID);
	UKObjectsEqual(S(otherItem1Path, item2Path), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
	
	UKObjectsEqual(A(group1ctx2), [[[ctx2 deadRelationshipCache] referringObjectsForPath: otherItem1Path] allObjects]);
	UKObjectsEqual(A(group1ctx2), [[[ctx2 deadRelationshipCache] referringObjectsForPath: item2Path] allObjects]);
	
	// Ensure item1 persistent root is still unloaded
	UKNil([ctx2 loadedPersistentRootForUUID: item1.persistentRoot.UUID]);
	UKFalse([ctx2 hasChanges]);
	
	// Load item1, but not the other branch yet
	UnorderedGroupContent *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
	UKObjectsEqual(item1.UUID, item1ctx2.UUID);
	UKNotNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKObjectsEqual(S(otherItem1Path, item2Path), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
	UKFalse([ctx2 hasChanges]);
	
	// Finally load the other branch.
	// This should trigger group1ctx2 to unfault its reference.
	UnorderedGroupContent *otherItem1ctx2 = [item1ctx2.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
	UKObjectsEqual(S(otherItem1ctx2), [group1ctx2 serializableValueForStorageKey: @"contents"]);
	UKObjectsEqual(S(otherItem1ctx2, item2Path), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
	UKFalse([ctx2 hasChanges]);

	UKNil([[ctx2 deadRelationshipCache] referringObjectsForPath: otherItem1Path]);
	UKObjectsEqual(A(group1ctx2), [[[ctx2 deadRelationshipCache] referringObjectsForPath: item2Path] allObjects]);
}

- (void) testSourcePersistentRootLazyLoading
{
	COEditingContext *ctx2 = [self newContext];
	
	// First, all persistent roots should be unloaded.
	UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Load item1
	UnorderedGroupContent *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
	
	// Because group1 is not currently loaded, we have no way of
	// knowing that it has a cross-reference to item1.
	// So item1ctx2.parentGroups is currently empty.
	// This is sort of a leak in the abstraction of lazy loading.
	UKObjectsEqual(S(), item1ctx2.parentGroups);
	
	// Load group1
	UnorderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	UKObjectsEqual(@"current", group1ctx2.label);
	
	// That should have updated the parentGroups property
	UKObjectsEqual(S(group1ctx2), item1ctx2.parentGroups);
	
	UKFalse([ctx2 hasChanges]);

	COPath *item1Path = [COPath pathWithPersistentRoot: item1uuid];
	COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];
	
	UKNil([[ctx2 deadRelationshipCache] referringObjectsForPath: item1Path]);
	UKObjectsEqual(A(group1ctx2), [[[ctx2 deadRelationshipCache] referringObjectsForPath: item2Path] allObjects]);
}

- (void) testSourcePersistentRootLazyLoadingReverseOrder
{
	COEditingContext *ctx2 = [self newContext];
	
	// First, all persistent roots should be unloaded.
	UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item2uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Load group1
	UnorderedGroupWithOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	
	// Ensure the references are faulted
	UKObjectsEqual(S([COPath pathWithPersistentRoot: item1uuid],
					 [COPath pathWithPersistentRoot: item2uuid]), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
	
	// Load item1
	UnorderedGroupContent *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
	
	// Check that the reference in group1 was unfaulted by the loading of item1
	UKObjectsEqual(S(item1ctx2,
					 [COPath pathWithPersistentRoot: item2uuid]), [[group1ctx2 serializableValueForStorageKey: @"contents"] allReferences]);
	
	UKObjectsEqual(S(group1ctx2), item1ctx2.parentGroups);
	
	UKFalse([ctx2 hasChanges]);

	COPath *item1Path = [COPath pathWithPersistentRoot: item1uuid];
	COPath *item2Path = [COPath pathWithPersistentRoot: item2uuid];
	
	UKNil([[ctx2 deadRelationshipCache] referringObjectsForPath: item1Path]);
	UKObjectsEqual(A(group1ctx2), [[[ctx2 deadRelationshipCache] referringObjectsForPath: item2Path] allObjects]);
}

- (void)testSourcePersistentRootUnloadingOnDeletion
{
	ctx.unloadingBehavior = COEditingContextUnloadingBehaviorOnDeletion;

	@autoreleasepool {
		item1.persistentRoot.deleted = YES;
		[ctx commit];
		item1 = nil;
	}

	UKObjectsEqual(S([COPath pathWithPersistentRoot: item1uuid], item2),
	               [[group1 serializableValueForStorageKey: @"contents"] allReferences]);

	@autoreleasepool {
		group1.persistentRoot.deleted = YES;
		[ctx commit];
		group1 = nil;
	}

	UKTrue(item2.parentGroups.isEmpty);

	group1 = [ctx persistentRootForUUID: group1uuid].rootObject;

	UKObjectsEqual(S([COPath pathWithPersistentRoot: item1uuid], item2),
	               [[group1 serializableValueForStorageKey: @"contents"] allReferences]);

	// Force lazy loading of item1
	NSSet *reloadedContents = group1.contents;
	item1 = [ctx persistentRootForUUID: item1uuid].rootObject;

	UKObjectsEqual(S(item2), reloadedContents);
	// group1 is deleted so it's hidden by the incoming relationship cache
	UKTrue(item2.parentGroups.isEmpty);
}

- (void)testSourcePersistentRootManualUnloading
{
	@autoreleasepool {
		[ctx unloadPersistentRoot: item1.persistentRoot];
		item1 = nil;
	}

	UKObjectsEqual(S([COPath pathWithPersistentRoot: item1uuid], item2),
	               [[group1 serializableValueForStorageKey: @"contents"] allReferences]);
	
	@autoreleasepool {
		[ctx unloadPersistentRoot: group1.persistentRoot];
		group1 = nil;
	}
	
	UKTrue(item2.parentGroups.isEmpty);

	group1 = [ctx persistentRootForUUID: group1uuid].rootObject;
	// Force lazy loading of item1
	NSSet *reloadedContents = group1.contents;
	item1 = [ctx persistentRootForUUID: item1uuid].rootObject;

	UKObjectsEqual(S(item1, item2), reloadedContents);
	UKObjectsEqual(S(group1), item2.parentGroups);
}

@end
