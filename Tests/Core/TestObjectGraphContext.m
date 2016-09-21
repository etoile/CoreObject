/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestObjectGraphContext : EditingContextTestCase <UKTest> {
    COCopier *copier;
    COObjectGraphContext *ctx1;
    OutlineItem *root1;
}

@end

@implementation TestObjectGraphContext

- (id) init
{
    self = [super init];
    copier = [[COCopier alloc] init];
    
    /* Create a context which uses the main model repository. In +[EditingContextTestCase setUp], 
       we add OutlineItem and other metamodels to the main repository. */
    ctx1 = [[COObjectGraphContext alloc] init];
    root1 = [self addObjectWithLabel: @"root1" toContext: ctx1];
    ctx1.rootObject = root1;
    
    return self;
}

- (void)dealloc
{
    root1 = nil;
    
}

- (void)testCreate
{
	COObjectGraphContext *emptyContext = [COObjectGraphContext objectGraphContext];
	UKNotNil(emptyContext);
    //UKNil(emptyContext.rootObject);
}

- (void)testCustomModelDescriptionRepository
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];

	ctx1 = [COObjectGraphContext objectGraphContextWithModelDescriptionRepository: repo];
	ctx1.rootObject = [self addObjectWithLabel: @"root" toContext: ctx1];

	UKRaisesException([ctx insertNewPersistentRootWithRootObject: ctx1.rootObject]);
	
	ctx = [[COEditingContext alloc] initWithStore: store modelDescriptionRepository: repo];

	UKDoesNotRaiseException([ctx insertNewPersistentRootWithRootObject: ctx1.rootObject]);
}

- (OutlineItem *) addObjectWithLabel: (NSString *)label toContext: (COObjectGraphContext *)aCtx
{
    OutlineItem *obj = [aCtx insertObjectWithEntityName: @"OutlineItem"];
	obj.label = label;
    return obj;
}


- (OutlineItem *) addObjectWithLabel: (NSString *)label toObject: (OutlineItem *)dest
{
    OutlineItem *obj = [self addObjectWithLabel: label toContext: dest.objectGraphContext];
    [dest insertObject: obj atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    return obj;
}

- (void)testCopyingBetweenContextsWithNoStoreAdvanced
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext objectGraphContext];
   
    OutlineItem *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    ctx2.rootObject = root2;
        
	OutlineItem *parent = [self addObjectWithLabel: @"Shopping" toObject: root1];
	OutlineItem *child = [self addObjectWithLabel: @"Groceries" toObject: parent];
	OutlineItem *subchild = [self addObjectWithLabel: @"Pizza" toObject: child];
    
    UKObjectsEqual(S([ctx1.rootObject UUID], parent.UUID, child.UUID, subchild.UUID),
                   [NSSet setWithArray: ctx1.itemUUIDs]);
    
    UKObjectsEqual(S([ctx2.rootObject UUID]),
                   [NSSet setWithArray: ctx2.itemUUIDs]);
    
    // Do the copy
    
    ETUUID *parentCopyUUID = [copier copyItemWithUUID: parent.UUID
                                            fromGraph: ctx1
                                              toGraph: ctx2];

    UKObjectsNotEqual(parentCopyUUID, parent.UUID);
    UKIntsEqual(4, ctx2.itemUUIDs.count);
    
    // Remember, we aggressively rename everything when copying across
    // contexts now.
    UKFalse([[NSSet setWithArray: ctx2.itemUUIDs] intersectsSet:
             S(parent.UUID, child.UUID, subchild.UUID)]);
}

- (void)testCopyingBetweenContextsCornerCases
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext objectGraphContext];
   
    OutlineItem *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    ctx2.rootObject = root2;
    
    OutlineItem *o1 = [self addObjectWithLabel: @"Shopping" toObject: root1];
	OutlineItem *o2 = [self addObjectWithLabel: @"Gift" toObject: o1];
    UKNotNil(o1);
    
    ETUUID *o1copyUUID = [copier copyItemWithUUID: o1.UUID
                                            fromGraph: ctx1
                                              toGraph: ctx2];

    ETUUID *o1copy2UUID = [copier copyItemWithUUID: o1.UUID
                                            fromGraph: ctx1
                                              toGraph: ctx2]; // copy o1 into ctx2 a second time

    UKObjectsNotEqual(o1copyUUID, o1copy2UUID);
    
    OutlineItem *o1copy = [ctx2 loadedObjectForUUID: o1copyUUID];
    OutlineItem *o1copy2 = [ctx2 loadedObjectForUUID: o1copy2UUID];
    
    OutlineItem *o2copy = [[o1copy valueForKey: @"contents"] firstObject];
	OutlineItem *o2copy2 = [[o1copy2 valueForKey: @"contents"] firstObject];
    
    UKObjectsNotEqual(o1.UUID, o1copy.UUID);
    UKObjectsNotEqual(o2.UUID, o2copy.UUID);
    UKObjectsNotEqual(o1.UUID, o1copy2.UUID);
    UKObjectsNotEqual(o2.UUID, o2copy2.UUID);
}

- (void)testItemForUUID
{
    COItem *root1Item = [ctx1 itemForUUID: root1.UUID];
    
    // Check that changes in the COObject don't propagate to the item
    
    [root1 setValue: @"another label" forProperty: kCOLabel];
    
    UKObjectsEqual(@"root1", [root1Item valueForAttribute: kCOLabel]);
    UKObjectsEqual(@"another label", [root1 valueForKey: kCOLabel]);
    
    // Check that we can't change the COItem
    
    UKRaisesException([(COMutableItem *)root1Item setValue: @"foo" forAttribute: kCOLabel type: kCOTypeString]);
}

- (void) testItemUUIDsWithInsertedObject
{
	UKObjectsEqual(S(root1.UUID), SA(ctx1.itemUUIDs));
	
    OutlineItem *tag1 = [ctx1 insertObjectWithEntityName: @"Tag"];
	
	UKObjectsEqual(S(root1.UUID, tag1.UUID), SA(ctx1.itemUUIDs));
	UKNotNil([ctx1 itemForUUID: tag1.UUID]);
}

#pragma mark - -insertOrUpdateItems: and -setItemGraph:

- (void) testSetItemGraphOnEmptyContextDoesNotCopyGarbage
{
	OutlineItem *child = [self addObjectWithLabel: @"child" toObject: root1];
	OutlineItem *garbage = [self addObjectWithLabel: @"garbage" toContext: ctx1];
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	UKFalse(ctx2.hasChanges);
	
	[ctx2 setItemGraph: ctx1];
	UKObjectsEqual(S(root1.UUID, child.UUID), SA(ctx2.itemUUIDs));
	UKObjectsEqual(@"root1", [[ctx2 loadedObjectForUUID: root1.UUID] label]);
	UKObjectsEqual(@"child", [[ctx2 loadedObjectForUUID: child.UUID] label]);
	UKNil([ctx2 loadedObjectForUUID: garbage.UUID]);
	UKFalse(ctx2.hasChanges);
}

- (void) testSetItemGraphLackingRootItem
{
	
}

- (void)testInsertItemWithInsertOrUpdateItems
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	UKFalse(ctx1.hasChanges);
	
	ETEntityDescription *entity = [ctx1.modelDescriptionRepository descriptionForName: @"OutlineItem"];
	COMutableItem *mutableItem = [COMutableItem item];
    mutableItem.entityName = entity.name;
	mutableItem.packageName = entity.owner.name;
	mutableItem.packageVersion = entity.owner.version;
    [ctx1 insertOrUpdateItems: A(mutableItem)];
	
	UKTrue(ctx1.hasChanges);
	UKObjectsEqual(S(mutableItem.UUID), ctx1.insertedObjectUUIDs);
	UKObjectsEqual(S(), ctx1.updatedObjectUUIDs);
	
    OutlineItem *object = [ctx1 loadedObjectForUUID: mutableItem.UUID];
    
    [mutableItem setValue: @"hello" forAttribute: kCOLabel type: kCOTypeString];
    
    // Ensure the change did not affect object in ctx1
    
    UKObjectsEqual(@"hello", [mutableItem valueForAttribute: kCOLabel]);
    UKNil([object valueForKey: kCOLabel]);
}

- (void)testUpdateItemWithInsertOrUpdateItems
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	UKFalse(ctx1.hasChanges);
	
	COMutableItem *mutableItem = [[ctx1 itemForUUID: root1.UUID] mutableCopy];
    [mutableItem setValue: @"test" forAttribute: kCOLabel type: kCOTypeString];
    [ctx1 insertOrUpdateItems: A(mutableItem)];
	
	UKTrue(ctx1.hasChanges);
	UKObjectsEqual(S(), ctx1.insertedObjectUUIDs);
	UKObjectsEqual(S(root1.UUID), ctx1.updatedObjectUUIDs);
	
    UKObjectsSame(root1, [ctx1 loadedObjectForUUID: mutableItem.UUID]);
}

#pragma mark -

- (void)testChangeTrackingBasic
{
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
    ctx2.rootObject = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *root = ctx2.rootObject;

    UKObjectsEqual(S(root.UUID), [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual([NSSet set], [ctx2 updatedObjectUUIDs]);
    
    OutlineItem *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    //[ctx2 setRootObject: root2];
    
    // This modifies root2, but since root2 is still newly inserted, we don't
    // count it as modified
    OutlineItem *list1 = [self addObjectWithLabel: @"List1" toObject: root2];

    
    UKObjectsEqual(S(root.UUID, list1.UUID, root2.UUID), [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual([NSSet set], [ctx2 updatedObjectUUIDs]);
    
    [ctx2 acceptAllChanges];
    
    UKObjectsEqual([NSSet set], [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual([NSSet set], [ctx2 updatedObjectUUIDs]);
    
    // After calling -acceptAllChanges, further changes to those recently inserted
    // objects count as modifications.
    
    [root2 setValue: @"test" forProperty: kCOLabel];
    
    UKObjectsEqual([NSSet set], [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual(S(root2.UUID), [ctx2 updatedObjectUUIDs]);
}

- (void)testShoppingList
{
	OutlineItem *workspace = [self addObjectWithLabel: @"Workspace" toObject: root1];
	OutlineItem *document1 = [self addObjectWithLabel: @"Document1" toObject: workspace];
	OutlineItem *group1 = [self addObjectWithLabel: @"Group1" toObject: document1];
	OutlineItem *leaf1 = [self addObjectWithLabel: @"Leaf1" toObject: group1];
	OutlineItem *leaf2 = [self addObjectWithLabel: @"Leaf2" toObject: group1];
	OutlineItem *group2 = [self addObjectWithLabel: @"Group2" toObject: document1];
	OutlineItem *leaf3 = [self addObjectWithLabel: @"Leaf3" toObject: group2];
	
	OutlineItem *document2 = [self addObjectWithLabel: @"Document2" toObject: workspace];

    UKNil([root1 valueForKey: kCOParent]);
    UKObjectsSame(root1, [workspace valueForKey: kCOParent]);
    UKObjectsSame(workspace, [document1 valueForKey: kCOParent]);
	UKObjectsSame(document1, [group1 valueForKey: kCOParent]);
    UKObjectsSame(group1, [leaf1 valueForKey: kCOParent]);
    UKObjectsSame(group1, [leaf2 valueForKey: kCOParent]);
    UKObjectsSame(document1, [group2 valueForKey: kCOParent]);
    UKObjectsSame(group2, [leaf3 valueForKey: kCOParent]);
	UKObjectsSame(workspace, [document2 valueForKey: kCOParent]);

	UKObjectsEqual(A(document1, document2), [workspace valueForKey: kCOContents]);
	UKObjectsEqual(A(group1, group2), [document1 valueForKey: kCOContents]);
	UKObjectsEqual(@[], [document2 valueForKey: kCOContents]);
	UKObjectsEqual(A(leaf1, leaf2), [group1 valueForKey: kCOContents]);
	UKObjectsEqual(A(leaf3), [group2 valueForKey: kCOContents]);
    
	// Now make some changes
    
    [group2 insertObject: leaf2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [document2 insertObject: group2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
		
	UKObjectsSame(workspace, [document1 valueForKey: kCOParent]);
	UKObjectsSame(workspace, [document2 valueForKey: kCOParent]);
	UKObjectsSame(document1, [group1 valueForKey: kCOParent]);
	UKObjectsSame(document2, [group2 valueForKey: kCOParent]);
	UKObjectsSame(group1, [leaf1 valueForKey: kCOParent]);
	UKObjectsSame(group2, [leaf2 valueForKey: kCOParent]);
	UKObjectsSame(group2, [leaf3 valueForKey: kCOParent]);
	UKObjectsEqual(A(document1, document2), [workspace valueForKey: kCOContents]);
	UKObjectsEqual(A(group1), [document1 valueForKey: kCOContents]);
	UKObjectsEqual(A(group2), [document2 valueForKey: kCOContents]);
	UKObjectsEqual(A(leaf1), [group1 valueForKey: kCOContents]);
	UKObjectsEqual(A(leaf3, leaf2), [group2 valueForKey: kCOContents]);
    
    // Test JSON roundtrip
    
    NSData *data = COItemGraphToJSONData(ctx1);
    COItemGraph *graph = COItemGraphFromJSONData(data);
    
    UKTrue(COItemGraphEqualToItemGraph(ctx1, graph));
    UKObjectsEqual(root1.UUID, [graph rootItemUUID]);
    UKObjectsEqual([root1 storeItem], [graph itemForUUID: root1.UUID]);
    
    // Test binary roundtrip

    NSData *bindata = COItemGraphToBinaryData(ctx1);
    COItemGraph *bingraph = COItemGraphFromBinaryData(bindata);
    
    UKTrue(COItemGraphEqualToItemGraph(ctx1, bingraph));
    UKObjectsEqual(root1.UUID, [bingraph rootItemUUID]);
    UKObjectsEqual([root1 storeItem], [bingraph itemForUUID: root1.UUID]);
    
    // TODO: We should have tests for COItemGraphEqualToItemGraph since we
    // rely on it in checking the correctness of COItemGraphToJSONData
    // and COItemGraphToBinaryData
}

- (void) testRelationshipInverseAfterInsertOrUpdateItems
{
    OutlineItem *group1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    OutlineItem *group2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    OutlineItem *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [root1 insertObject: group1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [root1 insertObject: group2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [group1 insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    UKObjectsSame(group1, [child parentContainer]);
    
    // Move child from group1 to group2 at the COItem level
    
    COMutableItem *group1item = [[ctx1 itemForUUID: group1.UUID] mutableCopy];
    COMutableItem *group2item = [[ctx1 itemForUUID: group2.UUID] mutableCopy];
    [group1item setValue: @[] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    [group2item setValue: @[child.UUID] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    
    [ctx1 insertOrUpdateItems: @[group1item, group2item]];
    
    // Check that inverses were recalculated
    
    UKObjectsSame(group2, [child parentContainer]);
}

- (void) testRootObjectIsSetOnceOnly
{
	UKObjectsEqual(root1, ctx1.rootObject);
	
	OutlineItem *root2 = [self addObjectWithLabel: @"root1" toContext: ctx1];
    UKRaisesException([ctx1 setRootObject: root2]);
	
	// Test changing through -setItemGraph:
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	OutlineItem *root3 = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
	
	UKRaisesException([ctx1 setItemGraph: ctx2]);
}

/**
 * Adds two parent/child object pairs, that are not referred to by the root
 * object, so they will get garbage collected.
 */
- (void) addGarbageToObjectGraphContext
{
	OrderedGroupWithOpposite *parent1 = [[OrderedGroupWithOpposite alloc] initWithObjectGraphContext: ctx1];
	OrderedGroupContent *child1 = [[OrderedGroupContent alloc] initWithObjectGraphContext: ctx1];
	OrderedGroupContent *child2 = [[OrderedGroupContent alloc] initWithObjectGraphContext: ctx1];
	OrderedGroupWithOpposite *parent2 = [[OrderedGroupWithOpposite alloc] initWithObjectGraphContext: ctx1];
	parent1.contents = @[child1];
	parent2.contents = @[child2];
}

/**
 * This is carefully set up to trigger a message-to-deallocated-instance
 * bug that existed in -removeUnreachableObjects.
 */
- (void) doTestGarbageCollection
{
	@autoreleasepool {
		UKIntsEqual(1, [[ctx1 loadedObjects] count]);
		
		[self addGarbageToObjectGraphContext];
		
		UKTrue([[ctx1 loadedObjects] count] > 1);
	}
	
	[ctx1 removeUnreachableObjects];

	@autoreleasepool {
		UKIntsEqual(1, [[ctx1 loadedObjects] count]);
	}
}

- (void) testGarbageCollection
{
	for (NSUInteger i = 0; i<10; i++)
	{
		[self doTestGarbageCollection];
	}
}

#pragma mark - COObjectGraphContextObjectsDidChangeNotification

- (void) testObjectsDidChangeNotificationNotPostedAfterInsert
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	
	__block OutlineItem *child1;
	[self checkBlock: ^{
		child1 = [[OutlineItem alloc] initWithObjectGraphContext: ctx1];
	} doesNotPostNotification: COObjectGraphContextObjectsDidChangeNotification];
}

- (void) testObjectsDidChangeNotificationNotPostedAfterEdit
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	
	OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: ctx1];
	[self checkBlock: ^{
		root1.label = @"Test";
		root1.contents = @[child1];
		child1.label = @"Hello world";
	} doesNotPostNotification: COObjectGraphContextObjectsDidChangeNotification];
}

- (void) testObjectsDidChangeNotificationPostedAfterInsert
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	
	OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: ctx1];
	
	[self checkBlock: ^{
		[ctx1 acceptAllChanges];
	} postsNotification: COObjectGraphContextObjectsDidChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ COInsertedObjectsKey : S(child1.UUID),
						 COUpdatedObjectsKey : S() }];
}

- (void) testObjectsDidChangeNotificationPostedAfterUpdate
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	
	root1.label = @"Root item";
	
	[self checkBlock: ^{
		[ctx1 acceptAllChanges];
	} postsNotification: COObjectGraphContextObjectsDidChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ COInsertedObjectsKey : S(),
						 COUpdatedObjectsKey : S(root1.UUID) }];
}

- (void) testObjectsDidChangeNotificationPostedAfterInsertAndUpdate
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	
	OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: ctx1];
	child1.label = @"child1";
	root1.contents = @[child1];
	
	[self checkBlock: ^{
		[ctx1 acceptAllChanges];
	} postsNotification: COObjectGraphContextObjectsDidChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ COInsertedObjectsKey : S(child1.UUID),
						 COUpdatedObjectsKey : S(root1.UUID) }]; /* N.B. child1.UUID is not in the updated set */
}

- (void) testNotificationAfterDiscardForTransientContext
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	
	OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: ctx1];
	child1.label = @"child1";
	root1.contents = @[child1];
	
	[self checkBlock: ^{
		[ctx1 discardAllChanges];
	} postsNotification: COObjectGraphContextObjectsDidChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ COInsertedObjectsKey : S(),
						 COUpdatedObjectsKey : S() }];
	
	// TODO: See comment in -testNotificationAfterDiscardForPersistentContext
}

- (void) testNotificationAfterDiscardForPersistentContext
{
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
	[proot commit];
	
	COObjectGraphContext *persistentCtx = proot.objectGraphContext;
	OutlineItem *persistentCtxRoot = persistentCtx.rootObject;
	UKFalse(persistentCtx.hasChanges);
	
	OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: persistentCtx];
	child1.label = @"child1";
	persistentCtxRoot.contents = @[child1];
	
	[self checkBlock: ^{
		[ctx1 discardAllChanges];
	} postsNotification: COObjectGraphContextObjectsDidChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ COInsertedObjectsKey : S(),
						 COUpdatedObjectsKey : S() }];

	// TODO: Not sure what is best:
	// a) the above (COObjectGraphContextObjectsDidChangeNotification, object sets are empty)
	// b) a new notification COObjectGraphContextObjectsDidDiscardChangesNotification
	// c) no notification
	//
	// In a way we don't need to send a notification, since we're just reverting
	// to the state when the last notification was sent.
}

- (void) testNotificationAfterSetItemGraph
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init

	// Make some changes in a copy of ctx1
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
	[ctx2 setItemGraph: ctx1];
	OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
	child1.label = @"child1";
	((OutlineItem *)ctx2.rootObject).contents = @[child1];
	
	[self checkBlock: ^{
		// Load those changes into ctx1. Should post a notifcation.
		[ctx1 setItemGraph: ctx2];
	} postsNotification: COObjectGraphContextObjectsDidChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ COInsertedObjectsKey : S(child1.UUID),
						 COUpdatedObjectsKey : S(root1.UUID) }];
}

- (void) testNotificationAfterInsertOrUpdateItems
{
	[ctx1 acceptAllChanges]; // TODO: Move to test -init
	
	// Make some changes in a copy of ctx1
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
	[ctx2 setItemGraph: ctx1];
	OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
	child1.label = @"child1";
	((OutlineItem *)ctx2.rootObject).contents = @[child1];
	
	NSArray *exportedItems = @[[ctx2 itemForUUID: ctx2.rootItemUUID],
							   [ctx2 itemForUUID: child1.UUID]];
	
	[self checkBlock: ^{
		// Load those changes into ctx1 using -insertOrUpdateItems:. Should not post a notifcation.
		[ctx1 insertOrUpdateItems: exportedItems];
	} doesNotPostNotification: COObjectGraphContextObjectsDidChangeNotification];
	
	[self checkBlock: ^{
		[ctx1 acceptAllChanges];
	} postsNotification: COObjectGraphContextObjectsDidChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ COInsertedObjectsKey : S(child1.UUID),
						 COUpdatedObjectsKey : S(root1.UUID) }];
}

#pragma mark - COObjectGraphContextWillRelinquishObjectsNotification

- (void) testWillRelinquishObjectsNotification
{
	OutlineItem *garbage = [[OutlineItem alloc] initWithObjectGraphContext: ctx1];
	
	[self checkBlock: ^{
		[ctx1 removeUnreachableObjects];
	} postsNotification: COObjectGraphContextWillRelinquishObjectsNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: @{ CORelinquishedObjectsKey : @[garbage] }];
}

- (void) testRelinquishOnDealloc
{
	[self checkBlock: ^{
		@autoreleasepool {
			COObjectGraphContext *testCtx = [COObjectGraphContext new];
			OutlineItem *child1 = [[OutlineItem alloc] initWithObjectGraphContext: testCtx];
			child1.label = @"child1";
			testCtx.rootObject = child1;
		}
	} postsNotification: COObjectGraphContextWillRelinquishObjectsNotification
			  withCount: 1
			 fromObject: nil
		   withUserInfo: nil];
}

#pragma mark - COObjectGraphContextWillRelinquishObjectsNotification

- (void) testBeginEndBatchNotification
{
	COObjectGraphContext *altCtx = [COObjectGraphContext new];
	[altCtx setItemGraph: ctx1];
	OutlineItem *obj1 = [[OutlineItem alloc] initWithObjectGraphContext: altCtx];
	OutlineItem *obj2 = [[OutlineItem alloc] initWithObjectGraphContext: altCtx];
	((OutlineItem *)altCtx.rootObject).contents = @[obj1];
	obj1.contents = @[obj2];
		
	// FIXME: These are not very good tests
	
	[self checkBlock: ^{
		[ctx1 setItemGraph: altCtx];
	} postsNotification: COObjectGraphContextBeginBatchChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: nil];
	
	[self checkBlock: ^{
		[ctx1 setItemGraph: altCtx];
	} postsNotification: COObjectGraphContextEndBatchChangeNotification
		   withCount: 1
		  fromObject: ctx1
		withUserInfo: nil];
}

- (void) testAddUnchangedItem
{
	[ctx1 acceptAllChanges];
	UKFalse(ctx1.hasChanges);
	
	COItem *rootItem = [ctx1 itemForUUID: ctx1.rootItemUUID];
	
	// Should be a no-op
	[ctx1 insertOrUpdateItems: @[rootItem]];
	
#if 0
	UKFalse(ctx1.hasChanges);
#endif
}

- (void) testCrossContextReferenceSerializedAsNull
{
    COObjectGraphContext *ctx2 = [COObjectGraphContext new];
    
    OutlineItem *ctx2root = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
    ctx2root.label = @"ctx2root";
    
    // create a link from ctx1 to ctx2
    [root1 addObject: ctx2root];
    
    // TODO: Perhaps attempting to serialize this should throw an exception?
    COItem *item = root1.storeItem;
    NSArray *itemContentsArray = [item valueForAttribute: @"contents"];
    UKIntsEqual(1, itemContentsArray.count);
    UKObjectsEqual([NSNull null], itemContentsArray[0]);
}

- (void) testCrossContextReferencedObjectGraphContextDeallocated
{
	@autoreleasepool {
		COObjectGraphContext *ctx2 = [COObjectGraphContext new];
		
		OutlineItem *ctx2root = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
		ctx2root.label = @"ctx2root";
		ctx2.rootObject = ctx2root;

		// create a link from ctx1 to ctx2
		[root1 addObject: ctx2root];
		
		UKObjectsNotSame(ctx1, ctx2root.objectGraphContext);
		UKObjectsEqual(ctx2root, root1.contents[0]);
		
		NSLog(@"%@", ctx1.items);
	}
	
	// check that ctx1 is still valid?
	
	UKTrue([root1.contents isEmpty]);
	
	NSLog(@"%@", ctx1.detailedDescription);
}

- (void) testCrossContextReferencedObjectDeallocatedWithTwoReferences
{
	// add a child in ctx1
	OutlineItem *ctx1obj = [[OutlineItem alloc] initWithObjectGraphContext: ctx1];
	ctx1obj.label = @"ctx1obj";
	
	// create a ctx2
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	OutlineItem *ctx2root = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
	ctx2root.label = @"ctx2root";
	ctx2.rootObject = ctx2root;
	
	// create a ctx3
	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	OutlineItem *ctx3root = [[OutlineItem alloc] initWithObjectGraphContext: ctx3];
	ctx3root.label = @"ctx3root";
	ctx3.rootObject = ctx3root;
	
	// create a link from ctx1 to ctx2 and 3
	[ctx1obj addObject: ctx2root];
	[ctx1obj addObject: ctx3root];

	UKObjectsSame(ctx1obj, [ctx2root parentContainer]);
	UKObjectsSame(ctx1obj, [ctx3root parentContainer]);
	
	[ctx1 removeUnreachableObjects];
	
	UKNil([ctx2root parentContainer]);
	UKNil([ctx3root parentContainer]);
}

- (void) testCrossContextReferencedObjectDeallocated
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	
	OutlineItem *ctx2root = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
	ctx2root.label = @"ctx2root";
	ctx2.rootObject = ctx2root;
	
	OutlineItem *ctx2obj = [[OutlineItem alloc] initWithObjectGraphContext: ctx2];
	ctx2obj.label = @"ctx2obj";

	// create a link from ctx1 to ctx2
	[root1 addObject: ctx2obj];
	
	NSArray *ctx1ig = ctx1.items;
	UKFalse([root1.contents isEmpty]);
	
	// GC ctx2obj (it's not set as the root object)
	UKFalse([ctx2obj isZombie]);
	[ctx2 removeUnreachableObjects];
	UKTrue([ctx2obj isZombie]);
	
	// check that ctx1 is still valid?
	UKTrue([root1.contents isEmpty]);
	
	// It should serialize to COBrokenPath
	COItem *item = root1.storeItem;
	NSArray *itemContentsArray = [item valueForAttribute: @"contents"];
	UKIntsEqual(1, itemContentsArray.count);
	UKTrue([itemContentsArray[0] isBroken]);
}

@end
