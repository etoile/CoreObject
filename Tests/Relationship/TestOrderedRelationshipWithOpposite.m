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
	
	UKObjectsEqual(S(group1, group2), [item1 parentGroups]);
	UKObjectsEqual(S(group1), [item2 parentGroups]);

	// Make some changes
	
	group2.contents = @[item1, item2];

	UKObjectsEqual(S(group1, group2), [item2 parentGroups]);
	
	group1.contents = @[item2];

	UKObjectsEqual(S(group2), [item1 parentGroups]);
	
	// Reload in another graph
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	OrderedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	OrderedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	OrderedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	OrderedGroupContent *item2ctx2 = [ctx2 loadedObjectForUUID: [item2 UUID]];
	
	UKObjectsEqual((@[item2ctx2]), [group1ctx2 contents]);
	UKObjectsEqual((@[item1ctx2, item2ctx2]), [group2ctx2 contents]);
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item2ctx2 parentGroups]);
	UKObjectsEqual(S(group2ctx2), [item1ctx2 parentGroups]);
	
	// Check the relationship cache
	UKObjectsEqual(S(group2), [item1 referringObjects]);
	UKObjectsEqual(S(group1, group2), [item2 referringObjects]);
	
	UKObjectsEqual(S(group2ctx2), [item1ctx2 referringObjects]);
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item2ctx2 referringObjects]);
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
	
	UKRaisesException([group1 setContents: A([NSNull null])]);
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
}

@end

@implementation TestCrossPersistentRootOrderedRelationshipWithOpposite

- (id)init
{
	SUPERINIT;

	group1 = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupWithOpposite"].rootObject;
	item1 = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupContent"].rootObject;
	item1.label = @"current";
	item2 = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupContent"].rootObject;
	group1.label = @"current";
	group1.contents = A(item1, item2);
	[ctx commit];

	otherItem1 = [item1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherItem1.label = @"other";
	otherGroup1 = [group1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherGroup1.label = @"other";
	[ctx commit];

	return self;
}

#define CHECK_BLOCK_ARGS COEditingContext *testCtx, OrderedGroupWithOpposite *testGroup1, OrderedGroupContent *testItem1, OrderedGroupContent *testItem2, OrderedGroupContent *testOtherItem1, OrderedGroupWithOpposite *testOtherGroup1, OrderedGroupWithOpposite *testCurrentGroup1, OrderedGroupContent *testCurrentItem1, OrderedGroupContent *testCurrentItem2, OrderedGroupContent *testCurrentOtherItem1, OrderedGroupWithOpposite *testCurrentOtherGroup1, BOOL isNewContext

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
	
		block(testCtx, testGroup1, testItem1, testItem2, testOtherItem1, testOtherGroup1, testCurrentGroup1, testCurrentItem1, testCurrentItem2, testCurrentOtherItem1, testCurrentOtherGroup1, isNewContext);
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
	group1.contents = A(otherItem1, item2);
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
	group1.contents = A(otherItem1, item2);
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
	group1.contents = A(otherItem1, item2);
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(A(testItem2), testGroup1.contents);
		UKTrue(testOtherItem1.parentGroups.isEmpty);

		UKObjectsEqual(A(testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentOtherItem1.parentGroups.isEmpty);

	}];
}

- (void)testTargetBranchUndeletionForReferenceToSpecificBranch
{
	group1.contents = A(otherItem1, item2);
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
	otherGroup1.contents = A(item1, item2);
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(A(testItem1, testItem2), testOtherGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);
		
		UKObjectsEqual(A(testItem1, testItem2), testCurrentOtherGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

- (void)testSourcePersistentRootUndeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = A(item1, item2);
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
		
		UKObjectsEqual(A(testItem1, testItem2), testCurrentOtherGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testSourceBranchDeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = A(item1, item2);
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
	otherGroup1.contents = A(item1, item2);
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

@end
