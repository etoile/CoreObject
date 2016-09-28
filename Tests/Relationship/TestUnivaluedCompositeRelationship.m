/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestUnivaluedCompositeRelationship : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
    Parent *parent;
    Child *child;
}

@end


@implementation TestUnivaluedCompositeRelationship

- (id)init
{
    SUPERINIT;

    persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Parent"];
    parent = persistentRoot.rootObject;
    parent.label = @"Parent";
    UKNil(parent.child);

    child = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Child"];
    child.label = @"Child";
    parent.child = child;

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
           Parent *rootObject = testProot.rootObject;

           UKObjectsEqual(@"Parent", rootObject.label);
           UKObjectsSame(testProot.rootObject,
                         rootObject.child.parent);
           UKObjectsEqual(@"Child",
                          rootObject.child.label);
       }];
}

- (void)testSetNewChild
{
    Child *child2 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Child"];
    child2.label = @"Child2";

    UKObjectsSame(parent, child.parent);
    UKNil(child2.parent);

    parent.child = child2;

    UKNil(child.parent);
    UKObjectsSame(parent, child2.parent);

    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           Parent *rootObject = testProot.rootObject;

           UKObjectsEqual(@"Parent", rootObject.label);
           UKObjectsSame(testProot.rootObject,
                         rootObject.child.parent);
           UKObjectsEqual(@"Child2",
                          rootObject.child.label);
       }];
}

- (void)testMoveChild
{
    Parent *parent2 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Parent"];
    parent2.label = @"Parent2";

    Child *child2 = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Child"];
    child2.label = @"Child2";

    parent2.child = child2;

    UKObjectsSame(child, parent.child);
    UKObjectsSame(child2, parent2.child);
    UKObjectsSame(parent, child.parent);
    UKObjectsSame(parent2, child2.parent);

    // Move child2 to parent

    parent.child = child2;

    UKObjectsSame(child2, parent.child);
    UKNil(parent2.child);
    UKNil(child.parent);
    UKObjectsSame(parent, child2.parent);

    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           Parent *rootObject = testProot.rootObject;

           UKObjectsEqual(@"Parent", rootObject.label);
           UKObjectsSame(testProot.rootObject,
                         rootObject.child.parent);
           UKObjectsEqual(@"Child2",
                          rootObject.child.label);
       }];
}

- (void)testNullAllowedForUnivalued
{
    UKNotNil(parent.child);
    UKDoesNotRaiseException([parent setChild: nil]);
    UKNil(parent.child);
}

- (void)testNullAndNSNullEquivalent
{
    UKNotNil(parent.child);
    UKDoesNotRaiseException(parent.child = (Child *)[NSNull null]);
    UKNil(parent.child);
}

- (void)testNullCompositeDuringCompositeValidation
{
    [parent setChild: nil];
    UKDoesNotRaiseException([parent.objectGraphContext checkForCyclesInCompositeRelationshipsInChangedObjects]);
}

@end
