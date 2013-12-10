#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"
#import "COPrimitiveCollection.h"

/**
 * Tests ordered composite relationships.
 * Note that composites are always inner references, and always have an opposite
 * (enforced by the metamodel).
 */
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

- (void) testDuplicatesAutomaticallyRemoved
{
	parent.contents = @[child2, child2, child1, child1, child1, child2];
	UKTrue(([@[child2, child1] isEqual: parent.contents]
			|| [@[child1, child2] isEqual: parent.contents]));
}

- (void) testIllegalDirectModificationOfCollection
{
	// Test that an exception is raised when modifying when we last set the array using a setter
	UKObjectsEqual((@[child1, child2]), parent.contents);
	UKRaisesException([(NSMutableArray *)parent.contents removeObjectAtIndex: 1]);
	
	// Test that an exception is raised when modifying after deserialization
	
	// TODO: Rewrite in a cleaner way
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
	[ctx2 setItemGraph: parent.objectGraphContext];
	UKObjectsEqual((@[[child1 UUID], [child2 UUID]]), [[[[ctx2 rootObject] contents] mappedCollection] UUID]);
	UKRaisesException([(NSMutableArray *)[[ctx2 rootObject] contents] removeObjectAtIndex: 1]);
}

/**
 * The difficulty with detecting cycles is, we want to allow them temporarily
 * during -setItemGraph:.
 *
 * e.g. suppose the graph is "A contains B", and we load a replacement graph
 * where "B contains A". If item B is processed first, the graph will have
 * a temporary cycle until A is reloaded, at which point the problem will be
 * fixed. So we don't want to run cycle detection in -didChangeValueForProperty:
 * because it would be tripped in that case.
 */
- (void) testCompositeCycleWithThreeObjects
{
	UKTrue([parent isRoot]);
	UKObjectsEqual((@[child1, child2]), parent.contents);
	
	child1.contents = @[child2];	
	UKObjectsEqual((@[child1]), parent.contents); /* since adding child2 to child1 moved it */

	child2.contents = @[parent]; /* attempt to create a cycle... */

	UKRaisesException([ctx commit]);
}

- (void) testCompositeCycleWithOneObject
{
	parent.contents = @[parent];
	
	UKRaisesException([ctx commit]);
}

- (void)testNullDisallowedInCollection
{
	UKRaisesException([parent setContents: A([NSNull null])]);
}

@end


@interface TestTransientOrderedCompositeRelationship : EditingContextTestCase <UKTest>
{
	TransientOutlineItem *parent;
	TransientOutlineItem *child;
}
@end

@implementation TestTransientOrderedCompositeRelationship

- (id)init
{
	SUPERINIT;
	parent = [[ctx insertNewPersistentRootWithEntityName: @"TransientOutlineItem"] rootObject];
	child = [[TransientOutlineItem alloc] initWithObjectGraphContext: [parent objectGraphContext]];
	return self;
}

- (void)testInit
{
	[self checkVariableStorageCollectionForProperty: @"contents"];
}

- (void)checkVariableStorageCollectionForProperty: (NSString *)aProperty
{
	id <ETCollection> children = [parent valueForVariableStorageKey: aProperty];

	UKObjectKindOf(children, NSMutableArray);
	UKFalse([children conformsToProtocol: @protocol(COPrimitiveCollection)]);
}

- (void)testMutateChildren
{
	[parent addObject: child];
	
	[self checkVariableStorageCollectionForProperty: @"contents"];

	UKObjectsEqual(A(child), parent.contents);
	UKNil(child.parentContainer);
}

- (void)testSetParent
{
	child.parentContainer = parent;

	[self checkVariableStorageCollectionForProperty: @"contents"];

	UKTrue([parent.contents isEmpty]);
	UKObjectsEqual(parent, child.parentContainer);
}

- (void)testReplaceChildren
{
	parent.contents = A(child);

	[self checkVariableStorageCollectionForProperty: @"contents"];

	UKObjectsEqual(A(child), parent.contents);
	UKNil(child.parentContainer);
}

@end
