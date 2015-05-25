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


@interface TestCrossPersistentRootUnorderedRelationshipWithOpposite : EditingContextTestCase <UKTest>
{
	UnorderedGroupWithOpposite *group1;
	UnorderedGroupContent *item1;
	UnorderedGroupContent *item2;
	UnorderedGroupContent *otherItem1;
}

@end

@implementation TestCrossPersistentRootUnorderedRelationshipWithOpposite

- (id)init
{
	SUPERINIT;
	group1 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupWithOpposite"].rootObject;
	item1 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupContent"].rootObject;
	item1.label = @"current";
	item2 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupContent"].rootObject;
	group1.contents = S(item1, item2);
	[ctx commit];
	otherItem1 = [item1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherItem1.label = @"other";
	[ctx commit];
	return self;
}

#define CHECK_BLOCK_ARGS COEditingContext *testCtx, UnorderedGroupWithOpposite *testGroup1, UnorderedGroupContent *testItem1, UnorderedGroupContent *testItem2, UnorderedGroupWithOpposite *testCurrentGroup1, UnorderedGroupContent *testCurrentItem1, UnorderedGroupContent *testCurrentItem2, BOOL isNewContext

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
		
		UnorderedGroupWithOpposite *testCurrentGroup1 = testPersistentRoot.currentBranch.rootObject;
		UnorderedGroupContent *testCurrentItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].currentBranch.rootObject;
		UnorderedGroupContent *testCurrentItem2 =
			[testCtx persistentRootForUUID: item2.persistentRoot.UUID].currentBranch.rootObject;
		
		block(testCtx, testGroup1, testItem1, testItem2, testCurrentGroup1, testCurrentItem1, testCurrentItem2, isNewContext);
	}];
}

- (void)testSourcePersistentRootDeletion
{
	group1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		// Check that the relationship cache knows the inverse relationship,
		// even though it is not used in the metamodel (non-public API)
		// TODO: Move this test in no opposite tests
		UKObjectsEqual(S(testGroup1, testCurrentGroup1), [testItem1 referringObjects]);
		UKTrue(testItem1.parentGroups.isEmpty);

		// Bidirectional cross persistent root relationships are limited to the
		// tracking branch, this means item1 in the non-tracking current branch
		// doesn't appear in testCurrentGroup1.contents and doesn't refer to it
		// with an inverse relationship.
		// Bidirectional cross persistent root relationships are supported
		// accross current branches, but materialized accross tracking branches
		// in memory (they are not visible accross the current branches in memory).
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		// TODO: Move this test in no opposite tests
		UKTrue([testCurrentItem1 referringObjects].isEmpty);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

@end
