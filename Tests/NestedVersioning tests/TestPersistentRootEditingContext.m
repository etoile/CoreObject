#import "TestCommon.h"

@interface TestPersistentRootEditingContext : NSObject <UKTest> {
	
}

@end

@implementation  TestPersistentRootEditingContext

- (void) testBasic
{
	COStore *store = setupStore();
	
	//	
	// 1. set up the root context
	//	
	
	COPersistentRootEditingContext *ctx = [store rootContext];
	
	// at this point the context is empty.
	// in particular, it has no persistentRootTree, which means it contains no embedded objets.
	// this means we can't commit.
	
	UKNil([ctx persistentRootTree]);
	
	COSubtree *iroot = [COSubtree subtree];
	
	[ctx setPersistentRootTree: iroot];
	
	//	
	// 2.  set up a nested persistent root
	//
	
	COSubtree *nestedDocumentRootItem = [COSubtree subtree];
	[nestedDocumentRootItem setPrimitiveValue: @"red"
								 forAttribute: @"color"
										 type: kCOStringType];
	
	COSubtree *u1Tree = [[COSubtreeFactory factory] createPersistentRootWithRootItem: nestedDocumentRootItem
																		 displayName: @"My Document"
																			   store: store];
	[iroot addTree: u1Tree];
	
	
	UKIntsEqual(1, [[[COSubtreeFactory factory] branchesOfPersistentRoot: u1Tree] count]);
	
	//
	// 2b. create another branch
	//
	
	COSubtree *u1BranchA = [[COSubtreeFactory factory] currentBranchOfPersistentRoot: u1Tree];
	COSubtree *u1BranchB = [[COSubtreeFactory factory] createBranchOfPersistentRoot: u1Tree];
	
	[u1BranchA setPrimitiveValue: @"Development Branch" forAttribute: @"name" type: kCOStringType];
	[u1BranchB setPrimitiveValue: @"Stable Branch" forAttribute: @"name" type: kCOStringType];	
	
	UKObjectsEqual(u1BranchA, [[COSubtreeFactory factory] currentBranchOfPersistentRoot: u1Tree]);
	UKObjectsEqual(S(u1BranchA, u1BranchB), [[COSubtreeFactory factory] branchesOfPersistentRoot: u1Tree]);
	
	
	[[COSubtreeFactory factory] setCurrentBranch: u1BranchB
							   forPersistentRoot: u1Tree];
	
	UKObjectsEqual(u1BranchB, [[COSubtreeFactory factory] currentBranchOfPersistentRoot: u1Tree]);
	
	[[COSubtreeFactory factory] setCurrentBranch: u1BranchA
							   forPersistentRoot: u1Tree];
	
	UKObjectsEqual(u1BranchA, [[COSubtreeFactory factory] currentBranchOfPersistentRoot: u1Tree]);
	
	//
	// 2c. create another persistent root containing a copy of u1BranchB
	//
	
	COSubtree *u2 = [[COSubtreeFactory factory] persistentRootByCopyingBranch:  u1BranchB];
	[iroot addTree: u2];
	
	//
	// 2d. commit changes
	//
	
	COUUID *firstVersion = [ctx commitWithMetadata: nil];
	UKNotNil(firstVersion);
	UKObjectsEqual(firstVersion, [store rootVersion]);
	
	
	//
	// 3. Now open an embedded context on the document
	//
	
	COPersistentRootEditingContext *ctx2 = [ctx editingContextForEditingEmbdeddedPersistentRoot: u1Tree];
	UKNotNil(ctx2);
	UKObjectsEqual([nestedDocumentRootItem UUID], [[ctx2 persistentRootTree] UUID]);
	
	//
	// 4. Try making a commit in the document
	//
	
	COSubtree *nestedDocCtx2 = [ctx2 persistentRootTree];
	//UKObjectsEqual(nestedDocumentRootItem, nestedDocCtx2);
	
	[nestedDocCtx2 setPrimitiveValue: @"green"
						forAttribute: @"color"
								type: kCOStringType];
	
	COUUID *commitInNestedDocCtx2 = [ctx2 commitWithMetadata: nil];
	
	UKNotNil(commitInNestedDocCtx2);
	
	
	//
	// 5. Reopen store and check that we read back the same data
	//
	
	[store release];
	
	
	COStore *store2 = [[COStore alloc] initWithURL: [NSURL fileURLWithPath: STOREPATH]];
	
	COPersistentRootEditingContext *testctx1 = [store2 rootContext];
	
	u1Tree = [[testctx1 persistentRootTree] subtreeWithUUID: [u1Tree UUID]];
	u1BranchB = [[testctx1 persistentRootTree] subtreeWithUUID: [u1BranchB  UUID]];
	u2 = [[testctx1 persistentRootTree] subtreeWithUUID: [u2 UUID]];
	
	{
		COPersistentRootEditingContext *testctx2 = [testctx1 editingContextForEditingEmbdeddedPersistentRoot: u1Tree];
		
		COSubtree *item = [testctx2 persistentRootTree];
		UKStringsEqual(@"green", [item valueForAttribute: @"color"]);
		UKObjectsEqual(nestedDocCtx2, item);
	}
	
	{
		COPersistentRootEditingContext *testctx2 = [testctx1 editingContextForEditingBranchOfPersistentRoot: u1BranchB];
		COSubtree *item = [testctx2 persistentRootTree];
		UKStringsEqual(@"red", [item valueForAttribute: @"color"]);
		//UKObjectsEqual(nestedDocumentRootItem, item);
	}
	
	{
		COPersistentRootEditingContext *testctx2 = [testctx1 editingContextForEditingEmbdeddedPersistentRoot: u2];
		COSubtree *item = [testctx2 persistentRootTree];
		UKStringsEqual(@"red", [item valueForAttribute: @"color"]);
		//UKObjectsEqual(nestedDocumentRootItem, item);
	}
	
	
	//
	// 6. GC the store
	// 
	
	NSUInteger commitsBefore = [[store2 allCommitUUIDs] count];
	[store2 gc];
	NSUInteger commitsAfter = [[store2 allCommitUUIDs] count];
	UKTrue(commitsAfter < commitsBefore);
	
	
	[store2 release];	
}


- (void)testInsertObject
{
	COEditingContext *ctx = NewContext();
	UKFalse([ctx hasChanges]);
	
	
	COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	UKNotNil(obj);
	UKTrue([obj isKindOfClass: [COObject class]]);
	
	NSArray *expectedProperties = [NSArray arrayWithObjects: @"parentContainer", @"parentCollections", @"contents", @"label", nil];
	UKObjectsEqual([NSSet setWithArray: expectedProperties],
				   [NSSet setWithArray: [obj persistentPropertyNames]]);
    
	UKObjectsSame(obj, [ctx objectWithUUID: [obj UUID]]);
	
	UKTrue([ctx hasChanges]);
	
	UKNotNil([obj valueForProperty: @"parentCollections"]);
	UKNotNil([obj valueForProperty: @"contents"]);
	
	TearDownContext(ctx);
}

- (void)testBasicPersistence
{
	COUUID *objUUID;
	
	{
		COStore *store = [[COStore alloc] initWithURL: STORE_URL];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
		COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
		objUUID = [[obj UUID] retain];
		[obj setValue: @"Hello" forProperty: @"label"];
		[ctx commit];
		[ctx release];
		[store release];
	}
	
	{
		COStore *store = [[COStore alloc] initWithURL: STORE_URL];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
		COObject *obj = [ctx objectWithUUID: objUUID];
		UKNotNil(obj);
		NSArray *expectedProperties = [NSArray arrayWithObjects: @"parentContainer", @"parentCollections", @"contents", @"label", nil];
		UKObjectsEqual([NSSet setWithArray: expectedProperties],
					   [NSSet setWithArray: [obj persistentPropertyNames]]);
		UKStringsEqual(@"Hello", [obj valueForProperty: @"label"]);
		[ctx release];
		[store release];
	}
	[objUUID release];
	DELETE_STORE;
}


- (void)testDiscardChanges
{
	COEditingContext *ctx = NewContext();
    
	UKFalse([ctx hasChanges]);
    
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COUUID *u1 = [[o1 UUID] retain];
	
	// FIXME: It's not entirely clear what this should do
	[ctx discardAllChanges];
	UKNil([ctx objectWithUUID: u1]);
	
	UKFalse([ctx hasChanges]);
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[o2 setValue: @"hello" forProperty: @"label"];
	[ctx commit];
	UKObjectsEqual(@"hello", [o2 valueForProperty: @"label"]);
	
	[o2 setValue: @"bye" forProperty: @"label"];
	[ctx discardAllChanges];
	UKObjectsEqual(@"hello", [o2 valueForProperty: @"label"]);
	
	TearDownContext(ctx);
}

- (void)testCopyingBetweenContextsWithNoStoreSimple
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
    
	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[o1 setValue: @"Shopping" forProperty: @"label"];
	
	COObject *o1copy = [ctx2 insertObject: o1];
	UKNotNil(o1copy);
	UKObjectsSame(ctx1, [o1 editingContext]);
	UKObjectsSame(ctx2, [o1copy editingContext]);
	UKStringsEqual(@"Shopping", [o1copy valueForProperty: @"label"]);
    
	[ctx1 release];
	[ctx2 release];
}

@end