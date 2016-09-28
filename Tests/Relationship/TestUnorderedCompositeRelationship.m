/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestUnorderedCompositeRelationship : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
    Folder *parent;
    Folder *child1;
    Folder *child2;
}

@end


@implementation TestUnorderedCompositeRelationship

- (id)init
{
    self = [super init];

    persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Folder"];
    parent = persistentRoot.rootObject;
    parent.label = @"Parent";
    UKObjectsEqual([NSSet set], parent.contents);

    child1 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Folder"];
    child2 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Folder"];
    child1.label = @"Child1";
    child2.label = @"Child2";
    parent.contents = S(child1, child2);

    [ctx commit];

    return self;
}

- (void)testBasic
{
    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           Folder *testParent = testProot.rootObject;

           UKObjectKindOf(testParent.contents, NSSet);
           NSArray *sortedChildren = [testParent.contents sortedArrayUsingDescriptors:
               @[[NSSortDescriptor sortDescriptorWithKey: @"label"
                                               ascending: YES]]];

           Folder *testChild1 = sortedChildren[0];
           Folder *testChild2 = sortedChildren[1];

           UKIntsEqual(2, sortedChildren.count);

           UKObjectsEqual(@"Parent", testParent.label);
           UKObjectsSame(testParent, testChild1.parent);
           UKObjectsSame(testParent, testChild2.parent);
           UKObjectsEqual(@"Child1", testChild1.label);
           UKObjectsEqual(@"Child2", testChild2.label);
       }];
}

- (void)testAddAndRemoveChildren
{
    Folder *child3 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Folder"];
    child3.label = @"Child3";

    UKNil(child3.parent);

    [parent insertObject: child3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [parent removeObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

    UKObjectsEqual(S(child2, child3), parent.contents);

    UKNil(child1.parent);
    UKObjectsSame(parent, child2.parent);
    UKObjectsSame(parent, child3.parent);

    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           Folder *testParent = testProot.rootObject;

           UKObjectKindOf(testParent.contents, NSSet);
           NSArray *sortedChildren = [testParent.contents sortedArrayUsingDescriptors:
               @[[NSSortDescriptor sortDescriptorWithKey: @"label"
                                               ascending: YES]]];

           Folder *testChild2 = sortedChildren[0];
           Folder *testChild3 = sortedChildren[1];

           UKIntsEqual(2, sortedChildren.count);

           UKObjectsEqual(@"Parent", testParent.label);
           UKObjectsSame(testParent, testChild2.parent);
           UKObjectsSame(testParent, testChild3.parent);
           UKObjectsEqual(@"Child2", testChild2.label);
           UKObjectsEqual(@"Child3", testChild3.label);
       }];
}

- (void)testMoveChildren
{
    Folder *parent2 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Folder"];
    parent2.label = @"Parent2";

    UKObjectsEqual([NSSet set], parent2.contents);

    [parent2 insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

    UKObjectsEqual(S(child2), parent.contents);
    UKObjectsEqual(S(child1), parent2.contents);

    UKObjectsSame(parent, child2.parent);
    UKObjectsSame(parent2, child1.parent);
}

- (void)testIllegalDirectModificationOfCollection
{
    UKObjectsEqual(S(child1, child2), parent.contents);
    UKRaisesException([(NSMutableSet *)parent.contents removeObject: child1]);
}

- (void)testNullDisallowedInCollection
{
    UKRaisesException([parent setContents: S([NSNull null])]);
}

- (void)testCompositeCycleWithOneObject
{
    parent.contents = S(parent);

    UKRaisesException([ctx commit]);
}

- (void)testCompositeCycleWithOneObjectWithNoCOObjectSubclass
{
    registerFolderWithNoClassEntityDescriptionIfNeeded();

    ETEntityDescription *entity = [[ETModelDescriptionRepository mainRepository] descriptionForName: @"FolderWithNoClass"];
    UKTrue([[entity propertyDescriptionForName: @"contents"] isComposite]);
    UKTrue([[entity propertyDescriptionForName: @"parent"] isContainer]);

    COObjectGraphContext *graph = [COObjectGraphContext new];
    COObject *a = [graph insertObjectWithEntityName: @"FolderWithNoClass"];
    COObject *b = [graph insertObjectWithEntityName: @"FolderWithNoClass"];
    COPersistentRoot *proot = [ctx insertNewPersistentRootWithRootObject: a];

    [a setValue: S(a) forProperty: @"contents"];

    UKRaisesException([ctx commit]);
}

@end
