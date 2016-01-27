/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestUnivaluedRelationship : NSObject <UKTest>
@end

@implementation TestUnivaluedRelationship

/**
 * Test that an object graph of UnivaluedGroupNoOpposite can be reloaded in another
 * context. Test that one OutlineItem can be in two UnivaluedGroupNoOpposite's.
 */
- (void) testUnivaluedGroupNoOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	group1.content = item1;
	group2.content = item1;
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnivaluedGroupNoOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnivaluedGroupNoOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	OutlineItem *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	
	UKObjectsEqual(item1ctx2, [group1ctx2 content]);
	UKObjectsEqual(item1ctx2, [group2ctx2 content]);
}

- (void) testUnivaluedGroupNoOppositeOuterReference
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	
	UnivaluedGroupNoOpposite *group1 = [ctx1 insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	OutlineItem *item1 = [ctx2 insertObjectWithEntityName: @"OutlineItem"];
	
	group1.content = item1;
	
	// Check that the relationship cache knows the inverse relationship, even though it is
	// not used in the metamodel (non-public API)
	UKObjectsEqual(S(group1), [item1 referringObjects]);

	[ctx1 discardAllChanges];
	
	UKTrue([[item1 referringObjects] isEmpty]);
}

- (void) testRetainCycleMemoryLeakWithUserSuppliedSet
{
	const NSUInteger deallocsBefore = [UnivaluedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
		COObjectGraphContext *ctx = [COObjectGraphContext new];
		UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
		UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
		group1.content = group2;
		group2.content = group1;
	}
	
	const NSUInteger deallocs = [UnivaluedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void) testRetainCycleMemoryLeakWithFrameworkSuppliedSet
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	group1.content = group2;
	group2.content = group1;
	
	const NSUInteger deallocsBefore = [UnivaluedGroupNoOpposite countOfDeallocCalls];
	
	@autoreleasepool
	{
 		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		[ctx2 setItemGraph: ctx];
	}
	
	const NSUInteger deallocs = [UnivaluedGroupNoOpposite countOfDeallocCalls] - deallocsBefore;
	UKIntsEqual(2, deallocs);
}

- (void)testNullAllowedForUnivalued
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];

	UKDoesNotRaiseException([group1 setContent: nil]);
}

- (void)testNullAndNSNullEquivalent
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupNoOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	UnivaluedGroupNoOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupNoOpposite"];
	group1.content = group2;
	
	UKNotNil(group1.content);
	UKDoesNotRaiseException(group1.content = (COObject *)[NSNull null]);
	UKNil(group1.content);
}

@end

/**
 * For some general code comments that apply to all tests, see
 * -testTargetPersistentRootUndeletionh.
 *
 * For Relationship Source Deletion Tests, we test the referring objects that 
 * exist implicitly in the relationship cache, but are not exposed since the 
 * relationship is unidirectional.
 */
@interface TestCrossPersistentRootUnivaluedRelationship : EditingContextTestCase <UKTest>
{
	UnivaluedGroupNoOpposite *group1;
	OutlineItem *item1;
	OutlineItem *otherItem1;
	UnivaluedGroupNoOpposite *otherGroup1;

	// Convenience - persistent root UUIDs
	ETUUID *group1uuid;
	ETUUID *item1uuid;
}

@end

@implementation TestCrossPersistentRootUnivaluedRelationship

- (id)init
{
	SUPERINIT;
	
	ctx.unloadingBehavior = COEditingContextUnloadingBehaviorNever;

	group1 = [ctx insertNewPersistentRootWithEntityName: @"UnivaluedGroupNoOpposite"].rootObject;
	item1 = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
	item1.label = @"current";
	group1.label = @"current";
	group1.content = item1;
	[ctx commit];

	otherItem1 = [item1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherItem1.label = @"other";
	otherGroup1 = [group1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherGroup1.label = @"other";
	[ctx commit];
	
	group1uuid = group1.persistentRoot.UUID;
	item1uuid = item1.persistentRoot.UUID;

	return self;
}

#define CHECK_BLOCK_ARGS COEditingContext *testCtx, UnivaluedGroupNoOpposite *testGroup1, OutlineItem *testItem1, OutlineItem *testOtherItem1, UnivaluedGroupNoOpposite *testOtherGroup1, UnivaluedGroupNoOpposite *testCurrentGroup1, OutlineItem *testCurrentItem1, BOOL isNewContext

- (void)checkPersistentRootsWithExistingAndNewContextInBlock: (void (^)(CHECK_BLOCK_ARGS))block
{
	[self checkPersistentRootWithExistingAndNewContext: group1.persistentRoot
											   inBlock:
	 ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		UnivaluedGroupNoOpposite *testGroup1 = testPersistentRoot.rootObject;
		OutlineItem *testItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].rootObject;
		OutlineItem *testOtherItem1 =
			[testItem1.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
		UnivaluedGroupNoOpposite *testOtherGroup1 =
			[testGroup1.persistentRoot branchForUUID: otherGroup1.branch.UUID].rootObject;

		UnivaluedGroupNoOpposite *testCurrentGroup1 = testPersistentRoot.currentBranch.rootObject;
		OutlineItem *testCurrentItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].currentBranch.rootObject;
		OutlineItem *testCurrentOtherItem1 =
			[testCtx persistentRootForUUID: otherItem1.persistentRoot.UUID].currentBranch.rootObject;
		UnivaluedGroupNoOpposite *testCurrentOtherGroup1 =
			[testCtx persistentRootForUUID: otherGroup1.persistentRoot.UUID].currentBranch.rootObject;

		UKObjectsSame(testCurrentGroup1, testCurrentOtherGroup1);
		UKObjectsSame(testCurrentItem1, testCurrentOtherItem1);
		
		block(testCtx, testGroup1, testItem1, testOtherItem1, testOtherGroup1, testCurrentGroup1, testCurrentItem1, isNewContext);
	}];
}

- (void)testRelationships
{
	UnivaluedGroupNoOpposite *currentGroup1 = group1.persistentRoot.currentBranch.rootObject;

	UKObjectsEqual(item1, group1.content);
	// Check that the relationship cache knows the inverse relationship,
	// even though it is not used in the metamodel (non-public API)
	UKObjectsEqual(S(group1, currentGroup1, otherGroup1), [item1 referringObjects]);
}

- (void)testRelationshipsFromAndToCurrentBranches
{
	UnivaluedGroupNoOpposite *currentGroup1 = group1.persistentRoot.currentBranch.rootObject;
	OutlineItem *currentItem1 = item1.persistentRoot.currentBranch.rootObject;
	
	UKObjectsEqual(item1, currentGroup1.content);
	// Check that the relationship cache knows the inverse relationship,
	// even though it is not used in the metamodel (non-public API)
	UKTrue([currentItem1 referringObjects].isEmpty);
}

#pragma mark - Relationship Target Deletion Tests

- (void)testTargetPersistentRootDeletion
{
	UKObjectsSame(item1, group1.content);
	item1.persistentRoot.deleted = YES;
	UKNil(group1.content);
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKNil(testGroup1.content);
		UKTrue([testItem1 referringObjects].isEmpty);

		UKNil(testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testTargetPersistentRootDeletionThroughSeparateContext
{
	UKObjectsSame(item1, group1.content);
	
	// Perform the deletion in a separate context
	{
		COEditingContext *ctx2 = [self newContext];
		[ctx2 persistentRootForUUID: item1.persistentRoot.UUID].deleted = YES;
		
		// The cross-reference is not cleared in `ctx` yet.
		UKObjectsSame(item1, group1.content);
		
		[ctx2 commit];
	}
	
	// Wait a bit for a distributed notification to arrive to ctx
	[self wait];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKNil(testGroup1.content);
		UKTrue([testItem1 referringObjects].isEmpty);

		UKNil(testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testTargetPersistentRootUndeletion
{
	item1.persistentRoot.deleted = YES;
	[ctx commit];
	
	UKNil(group1.content);
	item1.persistentRoot.deleted = NO;
	UKObjectsSame(item1, group1.content);
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(testItem1, testGroup1.content);
		// Check that the relationship cache knows the inverse relationship,
		// even though it is not used in the metamodel (non-public API)
		UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);

		// Bidirectional cross persistent root relationships are limited to the
		// tracking branch, this means item1 in the non-tracking current branch
		// doesn't appear in testCurrentGroup1.contents and doesn't refer to it
		// with an inverse relationship (-referringObjectsForPropertyInTarget:
		// simulates it though).
		// Bidirectional cross persistent root relationships are supported
		// accross current branches, but materialized accross tracking branches
		// in memory (they are not visible accross the current branches in memory).
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testTargetPersistentRootUndeletionThroughSeparateContext
{
	item1.persistentRoot.deleted = YES;
	[ctx commit];

	// Perform the undeletion in a separate context
	{
		COEditingContext *ctx2 = [self newContext];
		[ctx2 persistentRootForUUID: item1.persistentRoot.UUID].deleted = NO;

		// The cross-reference is not restored in `ctx` yet.
		UKNil(group1.content);

		[ctx2 commit];
	}

	// Wait a bit for a distributed notification to arrive to ctx
	[self wait];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(testItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);

		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testTargetPersistentRootDeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKNil(testGroup1.content);
		UKTrue([testItem1 referringObjects].isEmpty);
		
		UKNil(testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testTargetPersistentRootUndeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];
	
	item1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(testOtherItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1), [testOtherItem1 referringObjects]);
		
		UKObjectsEqual(testOtherItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

/**
 * The current branch cannot be deleted, so we cannot write a test method
 * -testTargetBranchDeletion analog to -testTargetPersistentRootDeletion
 */
- (void)testTargetBranchDeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKNil(testGroup1.content);
		UKTrue([testOtherItem1 referringObjects].isEmpty);

		UKNil(testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testTargetBranchUndeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	otherItem1.branch.deleted = NO;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(testOtherItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1), [testOtherItem1 referringObjects]);

		UKObjectsEqual(testOtherItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

#pragma mark - Relationship Source Deletion Tests

- (void)testSourcePersistentRootDeletion
{
	group1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(testItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);

		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
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
		UKObjectsEqual(testItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);
		 
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testSourcePersistentRootDeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(testItem1, testOtherGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);
		
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testSourcePersistentRootUndeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];
	
	otherGroup1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherGroup1.label);
		UKStringsEqual(@"current", testGroup1.label);
		UKObjectsEqual(testItem1, testOtherGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);
		
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testSourceBranchDeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		 UKObjectsEqual(testItem1, testOtherGroup1.content);
		 UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);
		 
		 UKObjectsEqual(testItem1, testCurrentGroup1.content);
		 UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void)testSourceBranchUndeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	otherGroup1.branch.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(testItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1, testCurrentGroup1, testOtherGroup1), [testItem1 referringObjects]);

		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
	}];
}

- (void) testTargetPersistentRootLazyLoading
{
	COEditingContext *ctx2 = [self newContext];
	
	// First, all persistent roots should be unloaded.
	UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Load group1
	UnivaluedGroupNoOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	UKObjectsEqual(@"current", group1ctx2.label);
	
	// Ensure the persistent root is still unloaded
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Access cross reference to trigger loading
	OutlineItem *item1ctx2 = (OutlineItem *) group1ctx2.content;
	UKObjectsEqual(item1.UUID, item1ctx2.UUID);
	UKNotNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKFalse([ctx2 hasChanges]);
}

- (void)testTargetBranchLazyLoading
{
	COPath *otherItemPath = [COPath pathWithPersistentRoot: item1uuid
										   branch: otherItem1.branch.UUID];
	
	group1.content = otherItem1;
	[ctx commit];
	
	COEditingContext *ctx2 = [self newContext];
	
	// First, all persistent roots should be unloaded.
	UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Load group1
	UnivaluedGroupNoOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	UKObjectsEqual(@"current", group1ctx2.label);
	
	// Check group1ctx2.contents without triggering loading
	UKNotNil(otherItem1.branch.UUID);
	UKObjectsEqual(otherItemPath, [group1ctx2 serializableValueForStorageKey: @"content"]);
	
	NSArray *referrers = [[[ctx2 deadRelationshipCache] referringObjectsForPath: otherItemPath] allObjects];
	UKObjectsEqual(A(group1ctx2), referrers);
	
	// Ensure item1 persistent root is still unloaded
	UKNil([ctx2 loadedPersistentRootForUUID: item1.persistentRoot.UUID]);
	UKFalse([ctx2 hasChanges]);
	
	// Load item1, but not the other branch yet
	OutlineItem *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
	UKObjectsEqual(item1.UUID, item1ctx2.UUID);
	UKNotNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKObjectsEqual(otherItemPath, [group1ctx2 serializableValueForStorageKey: @"content"]);
	UKFalse([ctx2 hasChanges]);
	
	// Finally load the other branch.
	// This should trigger group1ctx2 to unfault its reference.
	OutlineItem *otherItem1ctx2 = [item1ctx2.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
	UKObjectsEqual(otherItem1ctx2, [group1ctx2 serializableValueForStorageKey: @"content"]);
	UKFalse([ctx2 hasChanges]);
}

- (void) testSourcePersistentRootLazyLoading
{
	COEditingContext *ctx2 = [self newContext];
	
	// First, all persistent roots should be unloaded.
	UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Load item1
	OutlineItem *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
	
	// Because group1 is not currently loaded, we have no way of
	// knowing that it has a cross-reference to item1.
	// So item1ctx2.parentGroups is currently empty.
	// This is sort of a leak in the abstraction of lazy loading.
	UKObjectsEqual(S(), item1ctx2.referringObjects);
	
	// Load group1
	UnivaluedGroupNoOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	UKObjectsEqual(@"current", group1ctx2.label);
	
	// That should have updated the referringObjects
	UKObjectsEqual(S(group1ctx2), item1ctx2.referringObjects);
	
	UKFalse([ctx2 hasChanges]);
}

- (void) testSourcePersistentRootLazyLoadingReverseOrder
{
	COEditingContext *ctx2 = [self newContext];
	
	// First, all persistent roots should be unloaded.
	UKNil([ctx2 loadedPersistentRootForUUID: group1uuid]);
	UKNil([ctx2 loadedPersistentRootForUUID: item1uuid]);
	UKFalse([ctx2 hasChanges]);
	
	// Load group1
	UnivaluedGroupNoOpposite *group1ctx2 = [ctx2 persistentRootForUUID: group1uuid].rootObject;
	
	// Ensure the references are faulted
	UKObjectsEqual([COPath pathWithPersistentRoot: item1uuid], [group1ctx2 serializableValueForStorageKey: @"content"]);
	
	// Load item1
	OutlineItem *item1ctx2 = [ctx2 persistentRootForUUID: item1uuid].rootObject;
	
	// Check that the reference in group1 was unfaulted by the loading of item1
	UKObjectsSame(item1ctx2, [group1ctx2 serializableValueForStorageKey: @"content"]);
	
	UKObjectsEqual(S(group1ctx2), item1ctx2.referringObjects);
	
	UKFalse([ctx2 hasChanges]);
}

@end
