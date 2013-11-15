#import "TestCommon.h"

@interface TestEditingContext : NSObject <UKTest> {
    COCopier *copier;
    COObjectGraphContext *ctx1;
    COObject *root1;
}

@end


@implementation TestEditingContext

static NSString *kCOLabel = @"label";
static NSString *kCOContents = @"contents";
static NSString *kCOReferences = @"references";

- (id) init
{
    self = [super init];
    copier = [[COCopier alloc] init];
    
    ctx1 = [[COObjectGraphContext alloc] init];
    root1 = [self addObjectWithLabel: @"root1" toContext: ctx1];
    [ctx1 setRootObject: root1];
    
    return self;
}

- (void)dealloc
{
    [copier release];
    [ctx1 release];
    root1 = nil;
    
    [super dealloc];
}

- (void)testCreate
{
	COObjectGraphContext *ctx = [COObjectGraphContext editingContext];
	UKNotNil(ctx);    
    UKNil([ctx rootObject]);
}

- (COObject *) addObjectWithLabel: (NSString *)label toContext: (COObjectGraphContext *)ctx
{
    COObject *obj = [ctx insertObject];
    [obj setValue: label
     forAttribute: kCOLabel
             type: kCOTypeString];
    
    [obj setValue: S() forAttribute: kCOContents type: kCOTypeCompositeReference | kCOTypeSet];
    [obj setValue: S() forAttribute: kCOReferences type: kCOTypeReference | kCOTypeSet];
    
    return obj;
}


- (COObject *) addObjectWithLabel: (NSString *)label toObject: (COObject *)dest
{
    COObject *obj = [self addObjectWithLabel: label toContext: [dest editingContext]];    
    [self addObject: obj toObject: dest];
    return obj;
}

- (void) addReferenceToObject: (COObject *)obj toObject: (COObject *)dest
{
    // FIXME: Hack, use proper API when it is available.
    [dest setValue: [[dest valueForAttribute: kCOReferences] setByAddingObject: obj]
      forAttribute: kCOReferences];
}

- (void) addObject: (COObject *)obj toObject: (COObject *)dest
{
    // FIXME: Hack, use proper API when it is available.
    [dest setValue: [[dest valueForAttribute: kCOContents] setByAddingObject: obj]
      forAttribute: kCOContents];
}



- (void)testCopyingBetweenContextsWithNoStoreAdvanced
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext editingContext];
   
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
	COObjectGraphContext *ctx2 = [COObjectGraphContext editingContext];
   
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
    
    COObject *o1copy = [ctx2 objectForUUID: o1copyUUID];
    COObject *o1copy2 = [ctx2 objectForUUID: o1copy2UUID];
    
    COObject *o2copy = [[o1copy directDescendentObjects] anyObject];
	COObject *o2copy2 = [[o1copy2 directDescendentObjects] anyObject];
    
    UKObjectsNotEqual([o1 UUID], [o1copy UUID]);
    UKObjectsNotEqual([o2 UUID], [o2copy UUID]);
    UKObjectsNotEqual([o1 UUID], [o1copy2 UUID]);
    UKObjectsNotEqual([o2 UUID], [o2copy2 UUID]);
}

- (void)testItemForUUID
{
    COItem *root1Item = [ctx1 itemForUUID: [root1 UUID]];
    
    // Check that changes in the COObject don't propagate to the item
    
    [root1 setValue: @"another label" forAttribute: kCOLabel];
    
    UKObjectsEqual(@"root1", [root1Item valueForAttribute: kCOLabel]);
    UKObjectsEqual(@"another label", [root1 valueForAttribute: kCOLabel]);
    
    // Check that we can't change the COItem
    
    UKRaisesException([root1Item setValue: @"foo" forAttribute: kCOLabel type: kCOTypeString]);    
}

- (void)testAddItem
{
	COMutableItem *mutableItem = [COMutableItem item];
    
    [ctx1 addItem: mutableItem];
    COObject *object = [ctx1 objectForUUID: [mutableItem UUID]];
    
    [mutableItem setValue: @"hello" forAttribute: kCOLabel type: kCOTypeString];
    
    // Ensure the change did not affect object in ctx1
    
    UKObjectsEqual(@"hello", [mutableItem valueForAttribute: kCOLabel]);
    UKNil([object valueForAttribute: kCOLabel]);
}

- (void)testMovingWithinContext
{    
    COObject *list1 = [self addObjectWithLabel: @"List1" toObject: root1];
	COObject *list2 = [self addObjectWithLabel: @"List2" toObject: root1];    
    COObject *itemA = [self addObjectWithLabel: @"ItemA" toObject: list1];
	COObject *itemB = [self addObjectWithLabel: @"ItemB" toObject: list2];
    
    UKObjectsEqual([list1 directDescendentObjects], S(itemA));
    UKObjectsEqual([list2 directDescendentObjects], S(itemB));
    UKObjectsSame(list1, [itemA innerObjectParent]);
    UKObjectsSame(list2, [itemB innerObjectParent]);
    
    // move itemA to list2
    
    [list2 setValue: S(itemA, itemB) forAttribute: kCOContents];

    UKObjectsSame(list2, [itemA innerObjectParent]);
    UKObjectsEqual([list1 directDescendentObjects], [NSSet set]);
    UKObjectsEqual([list2 directDescendentObjects], S(itemA, itemB));
}


- (void)testContextCopyContextEqualityAndObjectEquality
{
    // FIXME: Fix this test
#if 0
    COObject *list1 = [self addObjectWithLabel: @"List1" toObject: root1];
    COObject *itemA = [self addObjectWithLabel: @"ItemA" toObject: list1];
    COObject *itemA1 = [self addObjectWithLabel: @"ItemA1" toObject: itemA];
    
    COObjectGraphContext *ctx2 = [ctx1 copy];
    
    UKObjectsEqual(ctx1, ctx2);
    UKObjectsEqual([ctx1 rootObject], [ctx2 rootObject]);
    
    // now make an edit in ctx2
    
    COObject *itemACtx2 = [ctx2 objectForUUID: [itemA UUID]];
    
    [itemACtx2 setValue: @"modified" forAttribute: kCOLabel type: kCOTypeString];
    
    UKObjectsNotEqual(ctx1, ctx2);
    UKObjectsNotEqual([ctx1 rootObject], [ctx2 rootObject]);
    UKObjectsNotEqual(list1, [ctx2 objectForUUID: [list1 UUID]]);
    UKObjectsNotEqual(itemA, [ctx2 objectForUUID: [itemA UUID]]);
    UKObjectsEqual(itemA1, [ctx2 objectForUUID: [itemA1 UUID]]);
    
    // undo the change
    
    [itemACtx2 setValue: @"ItemA" forAttribute: kCOLabel];
    
    UKObjectsEqual(ctx1, ctx2);
    UKObjectsEqual([ctx1 rootObject], [ctx2 rootObject]);
#endif
}

- (void) testManyToMany
{
    COObject *t1 = [self addObjectWithLabel: @"tag1" toObject: root1];
    COObject *t2 = [self addObjectWithLabel: @"tag2" toObject: root1];
    COObject *t3 = [self addObjectWithLabel: @"tag3" toObject: root1];
    
    COObject *o1 = [self addObjectWithLabel: @"object1" toObject: root1];
    COObject *o2 = [self addObjectWithLabel: @"object2" toObject: root1];
    
    [self addReferenceToObject: o1 toObject: t1];
    [self addReferenceToObject: o1 toObject: t2];

	UKObjectsEqual(S(t1, t2), [ctx1 objectsWithReferencesToObject:o1 inAttribute:kCOReferences]);
	UKObjectsEqual([NSSet set], [ctx1 objectsWithReferencesToObject:o2 inAttribute:kCOReferences]);

    [self addReferenceToObject: o1 toObject: t3];
    [self addReferenceToObject: o2 toObject: t2];

	UKObjectsEqual(S(t1, t2, t3), [ctx1 objectsWithReferencesToObject:o1 inAttribute:kCOReferences]);
	UKObjectsEqual(S(t2), [ctx1 objectsWithReferencesToObject:o2 inAttribute:kCOReferences]);
}

- (void)testCopyingBetweenContextsWithManyToMany
{
    // FIXME: Fix this test
#if 0
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
    
	COObject *tag1 = [self addObjectWithLabel: @"tag1" toObject: root1];
	COObject *child = [self addObjectWithLabel: @"OutlineItem" toObject: root1];
    
	[self addReferenceToObject: child toObject: tag1];
    
	// Copy the tag collection to ctx2.
	
    ETUUID *tag1copyUUID = [copier copyItemWithUUID: [tag1 UUID]
                                          fromGraph: ctx1
                                            toGraph: ctx2];
    UKObjectsNotEqual(tag1copyUUID, [tag1 UUID]);
    
    COObject *tag1copy = [ctx2 objectForUUID: tag1copyUUID];
    
    UKIntsEqual(2, [[ctx2 itemUUIDs] count]);
    
    NSSet *refs = [tag1copy valueForAttribute: kCOReferences];
    UKIntsEqual(1, [refs count]);
    
    COObject *childcopy = [refs anyObject];
    UKObjectsNotEqual([childcopy UUID], [child UUID]);
    UKObjectsEqual(@"OutlineItem", [childcopy valueForAttribute: kCOLabel]);
    
    // FIXME: At first glance this looks like ugly behaviour.
#endif
}

- (void)testChangeTrackingBasic
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext editingContext];
	
    UKObjectsEqual([NSSet set], [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual([NSSet set], [ctx2 modifiedObjectUUIDs]);
    
    COObject *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    [ctx2 setRootObject: root2];
    
    // This modifies root2, but since root2 is still newly inserted, we don't
    // count it as modified
    COObject *list1 = [self addObjectWithLabel: @"List1" toObject: root2];

    
    UKObjectsEqual(S([list1 UUID], [root2 UUID]), [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual([NSSet set], [ctx2 modifiedObjectUUIDs]);
    
    [ctx2 clearChangeTracking];
    
    UKObjectsEqual([NSSet set], [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual([NSSet set], [ctx2 modifiedObjectUUIDs]);
    
    // After calling -clearChangeTracking, further changes to those recently inserted
    // objects count as modifications.
    
    [root2 setValue: @"test" forAttribute: kCOLabel];
    
    UKObjectsEqual([NSSet set], [ctx2 insertedObjectUUIDs]);
    UKObjectsEqual(S([root2 UUID]), [ctx2 modifiedObjectUUIDs]);
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
    
	// Now make some changes
	
	[self addObject: leaf2 toObject: group2];
	[self addObject: group2 toObject: document2];
	
	UKObjectsSame(workspace, [document1 innerObjectParent]);
	UKObjectsSame(workspace, [document2 innerObjectParent]);
	UKObjectsSame(document1, [group1 innerObjectParent]);
	UKObjectsSame(document2, [group2 innerObjectParent]);
	UKObjectsSame(group1, [leaf1 innerObjectParent]);
	UKObjectsSame(group2, [leaf2 innerObjectParent]);
	UKObjectsSame(group2, [leaf3 innerObjectParent]);
	UKObjectsEqual(S(document1, document2), [workspace valueForAttribute: kCOContents]);
	UKObjectsEqual(S(group1), [document1 valueForAttribute: kCOContents]);
	UKObjectsEqual(S(group2), [document2 valueForAttribute: kCOContents]);
	UKObjectsEqual(S(leaf1), [group1 valueForAttribute: kCOContents]);
	UKObjectsEqual(S(leaf2, leaf3), [group2 valueForAttribute: kCOContents]);
}

// Done up to this line....
#if 0



- (void) testSubtreeCreationFromItemsWithCycle
{
	COMutableItem *parent = [COMutableItem item];
	COMutableItem *child = [COMutableItem item];
	[parent setValue: [child UUID] forAttribute: @"cycle" type: kCOTypeCompositeReference];
	[child setValue: [parent UUID] forAttribute: @"cycle" type: kCOTypeCompositeReference];
    
    UKRaisesException([COItemTree itemTreeWithItems: A(parent, child) rootItemUUID: [parent UUID]]);
}


- (void) testSubtreeBasic
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
    COObject *t1 = [ctx1 rootObject];
	
	UKNotNil([t1 UUID]);
	UKNil([t1 parentObject]);
	UKObjectsSame(t1, [t1 rootObject]);
	UKTrue([t1 containsObject: t1]);
	
    COObject *t2 = [t1 addObjectToContents: [self itemWithLabel: @"t2"]];
	
	UKObjectsSame(t1, [t2 parentObject]);
	UKObjectsSame(t1, [t2 rootObject]);
	UKNil([t1 parentObject]);
	UKObjectsSame(t1, [t1 rootObject]);
	
	UKTrue([t1 containsObject: t2]);
	UKObjectsEqual(S([t1 UUID], [t2 UUID]), [t1 allObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID]), [t1 allDescendentObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID]), [t1 directDescendentObjectUUIDs]);
	UKObjectsEqual(S(t2), [t1 directDescendentObjects]);
	UKIntsEqual(2, [[t1 allStoreItems] count]);
	UKIntsEqual(1, [[t2 allObjectUUIDs] count]);
	UKTrue(t2 == [t1 descendentObjectForUUID: [t2 UUID]]);
	UKObjectsEqual([COItemPath pathWithItemUUID: [t1 UUID]
                        unorderedCollectionName: kCOContents
                                           type: kCOTypeCompositeReference | kCOTypeSet],
                   [t1 itemPathOfDescendentObjectWithUUID: [t2 UUID]]);
	
    COObject *t3 = [t2 addObjectToContents: [self itemWithLabel: @"t3"]];
	
	UKTrue([t1 containsObject: t3]);
	UKObjectsEqual(S([t1 UUID], [t2 UUID], [t3 UUID]), [t1 allObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID], [t3 UUID]), [t1 allDescendentObjectUUIDs]);
	UKObjectsEqual(S([t2 UUID]), [t1 directDescendentObjectUUIDs]);
	UKObjectsEqual(S(t2), [t1 directDescendentObjects]);
	UKIntsEqual(3, [[t1 allStoreItems] count]);
	UKIntsEqual(2, [[t2 allObjectUUIDs] count]);
	UKObjectsSame(t3, [t1 descendentObjectForUUID: [t3 UUID]]);
	UKObjectsEqual([COItemPath pathWithItemUUID: [t2 UUID]
                        unorderedCollectionName: kCOContents
                                           type: kCOTypeCompositeReference | kCOTypeSet],
                   [t1 itemPathOfDescendentObjectWithUUID: [t3 UUID]]);
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
	
	[parent setValue: S([child1 UUID], [child2 UUID]) forAttribute: kCOContents type: kCOTypeCompositeReference | kCOTypeSet];
	[child1 setValue: [shared UUID] forAttribute: @"shared" type: kCOTypeCompositeReference];
	[child2 setValue: [shared UUID] forAttribute: @"shared" type: kCOTypeCompositeReference];
	
	// illegal, because "shared" is embedded in two places
	
	UKRaisesException([COSubtree subtreeWithItemSet: S(parent, child1, child2, shared) rootUUID: [parent UUID]]);
}

- (void) testSubtreePlistRoundTrip
{
	COSubtree *t1 = [COSubtree subtree];
	COSubtree *t2 = [COSubtree subtree];
	COSubtree *t3 = [COSubtree subtree];
	[t1 addTree: t2];
	[t2 addTree: t3];
	
	COSubtree *t1a = [COSubtree subtreeWithPlist: [t1 plist]];
	UKObjectsEqual(t1, t1a);
	
	COSubtree *t2a = [COSubtree subtreeWithPlist: [t2 plist]];
	UKObjectsEqual(t2, t2a);
}

#endif

@end
