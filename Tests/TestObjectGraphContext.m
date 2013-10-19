#import "TestCommon.h"

@interface TestObjectGraphContext : NSObject <UKTest> {
    COCopier *copier;
    COObjectGraphContext *ctx1;
    COObject *root1;
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
    [ctx1 setRootObject: root1];
    
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
    //UKNil([emptyContext rootObject]);
}

- (COObject *) addObjectWithLabel: (NSString *)label toContext: (COObjectGraphContext *)aCtx
{
    COObject *obj = [aCtx insertObjectWithEntityName: @"OutlineItem"];

    [obj setValue: label
           forProperty: kCOLabel];
    
    return obj;
}


- (COObject *) addObjectWithLabel: (NSString *)label toObject: (COObject *)dest
{
    COObject *obj = [self addObjectWithLabel: label toContext: [dest objectGraphContext]];
    [dest insertObject: obj atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    return obj;
}

- (void)testCopyingBetweenContextsWithNoStoreAdvanced
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext objectGraphContext];
   
    COObject *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    [ctx2 setRootObject: root2];
        
	COObject *parent = [self addObjectWithLabel: @"Shopping" toObject: root1];
	COObject *child = [self addObjectWithLabel: @"Groceries" toObject: parent];
	COObject *subchild = [self addObjectWithLabel: @"Pizza" toObject: child];
    
    UKObjectsEqual(S([[ctx1 rootObject] UUID], [parent UUID], [child UUID], [subchild UUID]),
                   [NSSet setWithArray: [ctx1 itemUUIDs]]);
    
    UKObjectsEqual(S([[ctx2 rootObject] UUID]),
                   [NSSet setWithArray: [ctx2 itemUUIDs]]);
    
    // Do the copy
    
    ETUUID *parentCopyUUID = [copier copyItemWithUUID: [parent UUID]
                                            fromGraph: ctx1
                                              toGraph: ctx2];

    UKObjectsNotEqual(parentCopyUUID, [parent UUID]);
    UKIntsEqual(4, [[ctx2 itemUUIDs] count]);
    
    // Remember, we aggressively rename everything when copying across
    // contexts now.
    UKFalse([[NSSet setWithArray: [ctx2 itemUUIDs]] intersectsSet:
             S([parent UUID], [child UUID], [subchild UUID])]);
}

- (void)testCopyingBetweenContextsCornerCases
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext objectGraphContext];
   
    COObject *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    [ctx2 setRootObject: root2];
    
    COObject *o1 = [self addObjectWithLabel: @"Shopping" toObject: root1];
	COObject *o2 = [self addObjectWithLabel: @"Gift" toObject: o1];
    UKNotNil(o1);
    
    ETUUID *o1copyUUID = [copier copyItemWithUUID: [o1 UUID]
                                            fromGraph: ctx1
                                              toGraph: ctx2];

    ETUUID *o1copy2UUID = [copier copyItemWithUUID: [o1 UUID]
                                            fromGraph: ctx1
                                              toGraph: ctx2]; // copy o1 into ctx2 a second time

    UKObjectsNotEqual(o1copyUUID, o1copy2UUID);
    
    COObject *o1copy = [ctx2 objectWithUUID: o1copyUUID];
    COObject *o1copy2 = [ctx2 objectWithUUID: o1copy2UUID];
    
    COObject *o2copy = [[o1copy valueForKey: @"contents"] firstObject];
	COObject *o2copy2 = [[o1copy2 valueForKey: @"contents"] firstObject];
    
    UKObjectsNotEqual([o1 UUID], [o1copy UUID]);
    UKObjectsNotEqual([o2 UUID], [o2copy UUID]);
    UKObjectsNotEqual([o1 UUID], [o1copy2 UUID]);
    UKObjectsNotEqual([o2 UUID], [o2copy2 UUID]);
}

- (void)testItemForUUID
{
    COItem *root1Item = [ctx1 itemForUUID: [root1 UUID]];
    
    // Check that changes in the COObject don't propagate to the item
    
    [root1 setValue: @"another label" forProperty: kCOLabel];
    
    UKObjectsEqual(@"root1", [root1Item valueForAttribute: kCOLabel]);
    UKObjectsEqual(@"another label", [root1 valueForKey: kCOLabel]);
    
    // Check that we can't change the COItem
    
    UKRaisesException([(COMutableItem *)root1Item setValue: @"foo" forAttribute: kCOLabel type: kCOTypeString]);
}

- (void)testAddItem
{
	COMutableItem *mutableItem = [COMutableItem item];
    [mutableItem setValue: @"OutlineItem" forAttribute: kCOObjectEntityNameProperty type: kCOTypeString];
    [ctx1 insertOrUpdateItems: A(mutableItem)];
    COObject *object = [ctx1 objectWithUUID: [mutableItem UUID]];
    
    [mutableItem setValue: @"hello" forAttribute: kCOLabel type: kCOTypeString];
    
    // Ensure the change did not affect object in ctx1
    
    UKObjectsEqual(@"hello", [mutableItem valueForAttribute: kCOLabel]);
    UKNil([object valueForKey: kCOLabel]);
}

- (void)testMovingWithinContext
{    
    COObject *list1 = [self addObjectWithLabel: @"List1" toObject: root1];
	COObject *list2 = [self addObjectWithLabel: @"List2" toObject: root1];    
    COObject *itemA = [self addObjectWithLabel: @"ItemA" toObject: list1];
	COObject *itemB = [self addObjectWithLabel: @"ItemB" toObject: list2];
    
    UKObjectsEqual(A(itemA), [list1 valueForKey: kCOContents]);
    UKObjectsEqual(A(itemB), [list2 valueForKey: kCOContents]);
    UKObjectsSame(list1, [itemA valueForKey: kCOParent]);
    UKObjectsSame(list2, [itemB valueForKey: kCOParent]);
    
    // move itemA to list2
    
    [list2 setValue: A(itemA, itemB) forProperty: kCOContents];

    UKObjectsSame(list2, [itemA valueForKey: kCOParent]);
    UKObjectsEqual([NSArray array], [list1 valueForKey: kCOContents]);
    UKObjectsEqual(A(itemA, itemB), [list2 valueForKey: kCOContents]);
}

- (void) testManyToMany
{    
    COObject *tag1 = [ctx1 insertObjectWithEntityName: @"Tag"];
    COObject *tag2 = [ctx1 insertObjectWithEntityName: @"Tag"];
    COObject *tag3 = [ctx1 insertObjectWithEntityName: @"Tag"];
    [tag1 setValue: @"tag1" forProperty: kCOLabel];
    [tag2 setValue: @"tag2" forProperty: kCOLabel];
    [tag3 setValue: @"tag3" forProperty: kCOLabel];
    
    COObject *o1 = [ctx1 insertObjectWithEntityName: @"OutlineItem"];
    COObject *o2 = [ctx1 insertObjectWithEntityName: @"OutlineItem"];
    [o1 setValue: @"o1" forProperty: kCOLabel];
    [o2 setValue: @"o2" forProperty: kCOLabel];
    
    [tag1 insertObject:o1 atIndex:ETUndeterminedIndex hint:nil forProperty:kCOContents];
    [tag2 insertObject:o1 atIndex:ETUndeterminedIndex hint:nil forProperty:kCOContents];
    
	UKObjectsEqual(S(tag1, tag2),   [o1 valueForProperty: @"parentCollections"]);
	UKObjectsEqual([NSSet set], [o2 valueForProperty: @"parentCollections"]);

    [tag3 insertObject:o1 atIndex:ETUndeterminedIndex hint:nil forProperty:kCOContents];
    
    UKObjectsEqual(S(tag1, tag2, tag3), [o1 valueForProperty: @"parentCollections"]);
    UKObjectsEqual([NSSet set], [o2 valueForProperty: @"parentCollections"]);
    
    [tag2 insertObject:o2 atIndex:ETUndeterminedIndex hint:nil forProperty:kCOContents];

	UKObjectsEqual(S(tag1, tag2, tag3), [o1 valueForProperty: @"parentCollections"]);
	UKObjectsEqual(S(tag2),         [o2 valueForProperty: @"parentCollections"]);
}

- (void)testChangeTrackingBasic
{
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
    [ctx2 setRootObject: [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"]];
	COObject *root = [ctx2 rootObject];
    
    UKObjectsEqual(S(root), [ctx2 insertedObjects]);
    UKObjectsEqual([NSSet set], [ctx2 updatedObjects]);
    
    COObject *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    //[ctx2 setRootObject: root2];
    
    // This modifies root2, but since root2 is still newly inserted, we don't
    // count it as modified
    COObject *list1 = [self addObjectWithLabel: @"List1" toObject: root2];

    
    UKObjectsEqual(S(root, list1, root2), [ctx2 insertedObjects]);
    UKObjectsEqual([NSSet set], [ctx2 updatedObjects]);
    
    [ctx2 clearChangeTracking];
    
    UKObjectsEqual([NSSet set], [ctx2 insertedObjects]);
    UKObjectsEqual([NSSet set], [ctx2 updatedObjects]);
    
    // After calling -clearChangeTracking, further changes to those recently inserted
    // objects count as modifications.
    
    [root2 setValue: @"test" forProperty: kCOLabel];
    
    UKObjectsEqual([NSSet set], [ctx2 insertedObjects]);
    UKObjectsEqual(S(root2), [ctx2 updatedObjects]);
}

- (void)testRelationshipsForNewInstance
{
	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	UKObjectsEqual([NSArray array], [o1 valueForProperty: kCOContents]);
	UKNil([o1 valueForProperty: kCOParent]);
	UKObjectsEqual([NSSet set], [o1 valueForProperty: @"parentCollections"]);

	COObject *t1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];

	UKObjectsEqual([NSSet set], [t1 valueForProperty: kCOContents]);
	UKObjectsEqual([NSSet set], [t1 valueForProperty: @"childTags"]);
	UKNil([t1 valueForProperty: @"parentTag"]);
}

- (void)testBasicRelationshipIntegrity
{
	// Test one-to-many relationships
	
	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[o1 setValue: A(o2) forProperty: kCOContents];
	[o2 setValue: A(o3) forProperty: kCOContents];
    
	UKNil([o1 valueForProperty: kCOParent]);
	UKObjectsEqual(o1, [o2 valueForProperty: kCOParent]);
	UKObjectsEqual(o2, [o3 valueForProperty: kCOParent]);
	UKObjectsEqual([NSArray array], [o3 valueForProperty: kCOContents]);
    
	// Test many-to-many relationships
	
	COObject *t1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COObject *t2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COObject *t3 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	
	[t1 insertObject: o1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[t2 insertObject: o1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	UKObjectsEqual(S(t1, t2), [o1 valueForProperty: @"parentCollections"]);
	
	[t2 insertObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[t3 insertObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	UKObjectsEqual(S(o1), [t1 valueForProperty: @"contents"]);
	UKObjectsEqual(S(o1, o2), [t2 valueForProperty: @"contents"]);
	UKObjectsEqual(S(o2), [t3 valueForProperty: @"contents"]);
}

- (void)testRelationshipIntegrityForMove
{
	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[o1 setValue: A(o2) forProperty: @"contents"];
	[o3 setValue: A(o2) forProperty: @"contents"]; // should add o2 to o3's contents, and remove o2 from o1
	UKObjectsEqual([NSArray array], [o1 valueForProperty: @"contents"]);
	UKObjectsEqual(A(o2), [o3 valueForProperty: @"contents"]);
    
	// Check that removing an object from a group nullifys that object's parent group pointer
	
	[o3 removeObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	UKNil([o2 valueForProperty: @"parentContainer"]);
	
	// Now test moving by modifying the multivalued side of the relationship
	
	COContainer *o4 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *o5 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *o6 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[o5 addObject: o4];
	[o6 addObject: o4]; // Should move o4 from o5 to o6
	UKObjectsEqual([NSArray array], [o5 contentArray]);
	UKObjectsEqual(A(o4), [o6 contentArray]);
	UKObjectsSame(o6, [o4 valueForProperty: @"parentContainer"]);
}

- (void)testRelationshipIntegrityMarksDamage
{
	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *o3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
    [ctx1 clearChangeTracking];
    UKObjectsEqual([NSSet set], [ctx1 changedObjects]);
    
	[o1 setValue: A(o2) forProperty: @"contents"];
    UKObjectsEqual(S(o1), [ctx1 changedObjects]);
    
    [ctx1 clearChangeTracking];
	
	[o3 setValue: A(o2) forProperty: @"contents"]; // should add o2 to o3's contents, and remove o2 from o1
    UKObjectsEqual(S(o1, o3), [ctx1 changedObjects]);

    [ctx1 clearChangeTracking];
    
	[o3 removeObject: o2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"]; // should make o2's parentContainer nil
	UKObjectsEqual(S(o3), [ctx1 changedObjects]);
}

- (void)testShoppingList
{
	COObject *workspace = [self addObjectWithLabel: @"Workspace" toObject: root1];
	COObject *document1 = [self addObjectWithLabel: @"Document1" toObject: workspace];
	COObject *group1 = [self addObjectWithLabel: @"Group1" toObject: document1];
	COObject *leaf1 = [self addObjectWithLabel: @"Leaf1" toObject: group1];
	COObject *leaf2 = [self addObjectWithLabel: @"Leaf2" toObject: group1];
	COObject *group2 = [self addObjectWithLabel: @"Group2" toObject: document1];
	COObject *leaf3 = [self addObjectWithLabel: @"Leaf3" toObject: group2];
	
	COObject *document2 = [self addObjectWithLabel: @"Document2" toObject: workspace];

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
	UKObjectsEqual([NSArray array], [document2 valueForKey: kCOContents]);
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
    
    COMutableItem *group1item = [[ctx1 itemForUUID: [group1 UUID]] mutableCopy];
    COMutableItem *group2item = [[ctx1 itemForUUID: [group2 UUID]] mutableCopy];
    [group1item setValue: @[] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    [group2item setValue: @[[child UUID]] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    
    [ctx1 insertOrUpdateItems: @[group1item, group2item]];
    
    // Check that inverses were recalculated
    
    UKObjectsSame(group2, [child parentContainer]);
}

- (void) testRootObjectIsSetOnceOnly
{
	UKObjectsEqual(root1, [ctx1 rootObject]);
	
	COObject *root2 = [self addObjectWithLabel: @"root1" toContext: ctx1];
    UKRaisesException([ctx1 setRootObject: root2]);
}

// Done up to this line....
#if 0

- (void) testSubtreeBasic
{
	UKNotNil([root1 UUID]);
	UKNil([root1 valueForProperty: kCOParent]);
	UKObjectsSame(root1, [root1 rootObject]);
	
    COObject *t2 = [root1 addObjectToContents: [self itemWithLabel: @"t2"]];
	
	UKObjectsSame(root1, [t2 parentObject]);
	UKObjectsSame(root1, [t2 rootObject]);
	UKNil([root1 parentObject]);
	UKObjectsSame(root1, [root1 rootObject]);
	
	UKTrue([root1 containsObject: t2]);
	UKObjectsEqual(S([root1 UUID], [t2 UUID]), [root1 allObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID]), [root1 allDescendentObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID]), [root1 directDescendentObjectUUIDs]);
	UKObjectsEqual(S(t2), [root1 valueForKey: kCOContents]);
	UKIntsEqual(2, [[root1 allStoreItems] count]);
	UKIntsEqual(1, [[t2 allObjectUUIDs] count]);
	UKTrue(t2 == [root1 descendentobjectWithUUID: [t2 UUID]]);
	UKObjectsEqual([COItemPath pathWithItemUUID: [root1 UUID]
                        unorderedCollectionName: kCOContents
                                           type: kCOTypeCompositeReference | kCOTypeSet],
                   [root1 itemPathOfDescendentObjectWithUUID: [t2 UUID]]);
	
    COObject *t3 = [t2 addObjectToContents: [self itemWithLabel: @"t3"]];
	
	UKTrue([root1 containsObject: t3]);
	UKObjectsEqual(S([root1 UUID], [t2 UUID], [t3 UUID]), [root1 allObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID], [t3 UUID]), [root1 allDescendentObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID]), [root1 directDescendentObjectUUIDs]);
	UKObjectsEqual(S(t2), [root1 valueForKey: kCOContents]);
	UKIntsEqual(3, [[root1 allStoreItems] count]);
	UKIntsEqual(2, [[t2 allObjectUUIDs] count]);
	UKObjectsSame(t3, [root1 descendentobjectWithUUID: [t3 UUID]]);
	UKObjectsEqual([COItemPath pathWithItemUUID: [t2 UUID]
                        unorderedCollectionName: kCOContents
                                           type: kCOTypeCompositeReference | kCOTypeSet],
                   [root1 itemPathOfDescendentObjectWithUUID: [t3 UUID]]);
}

- (void) testSubtreeCreationFromItems
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
    COObject *t1 = [ctx1 rootObject];
    COObject *t2 = [t1 addObjectToContents: [self itemWithLabel: @"t2"]];
    [t2 addObjectToContents: [self itemWithLabel: @"t3"]];

    COEditingContext *t1copyCtx = [COEditingContext editingContextWithItemTree: [COItemTree itemTreeWithItems: [[t1 allStoreItems] allObjects]
                                                                                                     rootItemUUID: [t1 UUID]]];
    

    COEditingContext *t2copyCtx = [COEditingContext editingContextWithItemTree: [COItemTree itemTreeWithItems: [[t2 allStoreItems] allObjects]
                                                                                                     rootItemUUID: [t2 UUID]]];
    
	UKObjectsEqual(t1, [t1copyCtx rootObject]);
    UKObjectsEqual(t2, [t2copyCtx rootObject]);
}


- (void) testSubtreeCreationFromItemsWithInnerItemUsedTwice
{
	COMutableItem *parent = [COMutableItem item];
	COMutableItem *child1 = [COMutableItem item];
	COMutableItem *child2 = [COMutableItem item];
	COMutableItem *shared = [COMutableItem item];
	
	[parent setValue: S([child1 UUID], [child2 UUID]) forKey: kCOContents type: kCOTypeCompositeReference | kCOTypeSet];
	[child1 setValue: [shared UUID] forKey: @"shared" type: kCOTypeCompositeReference];
	[child2 setValue: [shared UUID] forKey: @"shared" type: kCOTypeCompositeReference];
	
	// illegal, because "shared" is embedded in two places
	
	UKRaisesException([COSubtree subtreeWithItemSet: S(parent, child1, child2, shared) rootUUID: [parent UUID]]);
}

#endif

@end
