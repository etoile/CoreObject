/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestObjectGraphContext : NSObject <UKTest> {
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

- (OutlineItem *) addObjectWithLabel: (NSString *)label toContext: (COObjectGraphContext *)aCtx
{
    OutlineItem *obj = [aCtx insertObjectWithEntityName: @"OutlineItem"];
	obj.label = label;
    return obj;
}


- (OutlineItem *) addObjectWithLabel: (NSString *)label toObject: (OutlineItem *)dest
{
    OutlineItem *obj = [self addObjectWithLabel: label toContext: [dest objectGraphContext]];
    [dest insertObject: obj atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    return obj;
}

- (void)testCopyingBetweenContextsWithNoStoreAdvanced
{
	COObjectGraphContext *ctx2 = [COObjectGraphContext objectGraphContext];
   
    OutlineItem *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    [ctx2 setRootObject: root2];
        
	OutlineItem *parent = [self addObjectWithLabel: @"Shopping" toObject: root1];
	OutlineItem *child = [self addObjectWithLabel: @"Groceries" toObject: parent];
	OutlineItem *subchild = [self addObjectWithLabel: @"Pizza" toObject: child];
    
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
   
    OutlineItem *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    [ctx2 setRootObject: root2];
    
    OutlineItem *o1 = [self addObjectWithLabel: @"Shopping" toObject: root1];
	OutlineItem *o2 = [self addObjectWithLabel: @"Gift" toObject: o1];
    UKNotNil(o1);
    
    ETUUID *o1copyUUID = [copier copyItemWithUUID: [o1 UUID]
                                            fromGraph: ctx1
                                              toGraph: ctx2];

    ETUUID *o1copy2UUID = [copier copyItemWithUUID: [o1 UUID]
                                            fromGraph: ctx1
                                              toGraph: ctx2]; // copy o1 into ctx2 a second time

    UKObjectsNotEqual(o1copyUUID, o1copy2UUID);
    
    OutlineItem *o1copy = [ctx2 loadedObjectForUUID: o1copyUUID];
    OutlineItem *o1copy2 = [ctx2 loadedObjectForUUID: o1copy2UUID];
    
    OutlineItem *o2copy = [[o1copy valueForKey: @"contents"] firstObject];
	OutlineItem *o2copy2 = [[o1copy2 valueForKey: @"contents"] firstObject];
    
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

- (void) testItemUUIDsWithInsertedObject
{
	UKObjectsEqual(S([root1 UUID]), SA([ctx1 itemUUIDs]));
	
    OutlineItem *tag1 = [ctx1 insertObjectWithEntityName: @"Tag"];
	
	UKObjectsEqual(S([root1 UUID], [tag1 UUID]), SA([ctx1 itemUUIDs]));
	UKNotNil([ctx1 itemForUUID: [tag1 UUID]]);
}

- (void)testAddItem
{
	COMutableItem *mutableItem = [COMutableItem item];
    [mutableItem setValue: @"OutlineItem" forAttribute: kCOObjectEntityNameProperty type: kCOTypeString];
    [ctx1 insertOrUpdateItems: A(mutableItem)];
    OutlineItem *object = [ctx1 loadedObjectForUUID: [mutableItem UUID]];
    
    [mutableItem setValue: @"hello" forAttribute: kCOLabel type: kCOTypeString];
    
    // Ensure the change did not affect object in ctx1
    
    UKObjectsEqual(@"hello", [mutableItem valueForAttribute: kCOLabel]);
    UKNil([object valueForKey: kCOLabel]);
}

- (void)testChangeTrackingBasic
{
	COObjectGraphContext *ctx2 = [[COObjectGraphContext alloc] init];
    [ctx2 setRootObject: [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"]];
	OutlineItem *root = [ctx2 rootObject];
    
    UKObjectsEqual(S(root), [ctx2 insertedObjects]);
    UKObjectsEqual([NSSet set], [ctx2 updatedObjects]);
    
    OutlineItem *root2 = [self addObjectWithLabel: @"root2" toContext: ctx2];
    //[ctx2 setRootObject: root2];
    
    // This modifies root2, but since root2 is still newly inserted, we don't
    // count it as modified
    OutlineItem *list1 = [self addObjectWithLabel: @"List1" toObject: root2];

    
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
	
	OutlineItem *root2 = [self addObjectWithLabel: @"root1" toContext: ctx1];
    UKRaisesException([ctx1 setRootObject: root2]);
}

@end
