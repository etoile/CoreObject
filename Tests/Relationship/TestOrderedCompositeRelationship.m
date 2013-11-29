#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestOrderedCompositeRelationship : EditingContextTestCase <UKTest>
{
	COPersistentRoot *persistentRoot;
	OutlineItem *parent;
	OutlineItem *child1;
	OutlineItem *child2;
}
@end

@implementation TestOrderedCompositeRelationship

- (id) init
{
	self = [super init];
	
	persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
	parent = [persistentRoot rootObject];
	parent.label = @"Parent";
	UKObjectsEqual(@[], parent.contents);
	
	child1 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"OutlineItem"];
	child2 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"OutlineItem"];
	child1.label = @"Child1";
	child2.label = @"Child2";
	parent.contents = @[child1, child2];
	
	[ctx commit];
	
	return self;
}

- (void)testBasic
{
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OutlineItem *testParent = testProot.rootObject;
		 OutlineItem *testChild1 = testParent.contents[0];
		 OutlineItem *testChild2 = testParent.contents[1];
		 
		 UKIntsEqual(2, [testParent.contents count]);
		 
		 UKObjectsEqual(@"Parent", testParent.label);
		 UKObjectsSame(testParent, testChild1.parentContainer);
		 UKObjectsSame(testParent, testChild2.parentContainer);
		 UKObjectsEqual(@"Child1", testChild1.label);
		 UKObjectsEqual(@"Child2", testChild2.label);
	 }];
}

- (void)testAddAndRemoveChildren
{
	OutlineItem *child3 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"OutlineItem"];
	child3.label = @"Child3";

	UKNil(child3.parentContainer);

	[parent addObject: child3];
	[parent removeObject: child1];
	
	UKObjectsEqual((@[child2, child3]), parent.contents);
	
	UKNil(child1.parentContainer);
	UKObjectsSame(parent, child2.parentContainer);
	UKObjectsSame(parent, child3.parentContainer);
	
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OutlineItem *testParent = testProot.rootObject;
		 OutlineItem *testChild2 = testParent.contents[0];
		 OutlineItem *testChild3 = testParent.contents[1];
		 
		 UKIntsEqual(2, [testParent.contents count]);
		 
		 UKObjectsEqual(@"Parent", testParent.label);
		 UKObjectsSame(testParent, testChild2.parentContainer);
		 UKObjectsSame(testParent, testChild3.parentContainer);
		 UKObjectsEqual(@"Child2", testChild2.label);
		 UKObjectsEqual(@"Child3", testChild3.label);
	 }];
}

- (void)testMoveChildren
{
	OutlineItem *parent2 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"OutlineItem"];
	parent2.label = @"Parent2";
	
	UKObjectsEqual(@[], parent2.contents);
	
	[parent2 addObject: child1];
	
	UKObjectsEqual((@[child2]), parent.contents);
	UKObjectsEqual((@[child1]), parent2.contents);
	
	UKObjectsSame(parent, child2.parentContainer);
	UKObjectsSame(parent2, child1.parentContainer);
}

@end
