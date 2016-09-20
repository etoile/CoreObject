/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestCrossPersistentRootReferences : EditingContextTestCase <UKTest>
@end

/**
 * TODO: Move these to the Relationship/ test files, and
 * rewrite them to cover multiple scenarios (univalued, ordered, unordered, keyed, unidirectional, bidirectional)
 * where needed.
 */
@implementation TestCrossPersistentRootReferences

/**
 * Most basic test of cross-persistent root references
 */
- (void) testBasic
{
    // library1 <<persistent root>>
	//  |
	//  |--photo1 // cross-persistent-root link, default branch
	//  |
	//  \--photo2 // cross-persistent-root link, default branch
	//
	// photo1 <<persistent root>>
	//
	// photo2 <<persistent root>>

    
    // 1. Set it up in memory
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1.rootObject setLabel: @"photo1"];
    
    COPersistentRoot *photo2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo2.rootObject setLabel: @"photo2"];
    
    COPersistentRoot *library = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [library.rootObject addObject: photo1.rootObject];
    [library.rootObject addObject: photo2.rootObject];
    
    UKObjectsEqual(S(photo1.rootObject, photo2.rootObject), [library.rootObject contents]);
    
    // Do the computed parentCollections properties work across persistent root boundaries?
    UKObjectsEqual(S(library.rootObject), [photo1.rootObject parentCollections]);
    UKObjectsEqual(S(library.rootObject), [photo2.rootObject parentCollections]);
    
    // Check that nothing is committed yet
    UKObjectsEqual(@[], [store persistentRootUUIDs]);
    
    [ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: library
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testLibrary, COBranch *testBranch, BOOL isNewContext)
	 {
		 NSArray *library2contents = [testLibrary.rootObject valueForKey: @"contents"];
		 UKIntsEqual(2, [library2contents count]);
		 
		 COPersistentRoot *photo1ctx2 = nil;
		 COPersistentRoot *photo2ctx2 = nil;
		 
		 for (COObject *obj in library2contents)
		 {
			 if ([[obj valueForKey: @"label"] isEqual: @"photo1"])
			 {
				 photo1ctx2 = obj.persistentRoot;
			 }
			 else if ([[obj valueForKey: @"label"] isEqual: @"photo2"])
			 {
				 photo2ctx2 = obj.persistentRoot;
			 }
		 }
		 
		 UKObjectsEqual([photo1 UUID], [photo1ctx2 UUID]);
		 UKObjectsEqual([photo2 UUID], [photo2ctx2 UUID]);
		 UKObjectsEqual([photo1.rootObject UUID], [photo1ctx2.rootObject UUID]);
		 UKObjectsEqual([photo2.rootObject UUID], [photo2ctx2.rootObject UUID]);
		 UKObjectsEqual(@"photo1", [photo1ctx2.rootObject label]);
		 UKObjectsEqual(@"photo2", [photo2ctx2.rootObject label]);
	 }];
}

- (void) testSpecificAndCurrentBranchReferenceInSet
{
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COBranch *branchA = photo1.currentBranch;
    
	OutlineItem *photo1root = photo1.rootObject;
	OutlineItem *branchAroot = branchA.rootObject;
	
	UKObjectsNotEqual(photo1root, branchAroot);
	UKFalse([photo1root hash] == [branchAroot hash]);
	
    NSSet *set = S(photo1root, branchAroot);
	UKIntsEqual(2, [set count]);
}

/*
 Verifies that when you have references to:
 
 * the current branch of photo1
 * branch A of photo1
 
 and when you change the current branch of photo1, the cross-persistent root
 reference to the current branch is updated, but the reference specifically
 to branch A remains as-is.
*/
- (void) testBranchSwitch
{
    // library1 <<persistent root>>
	//  |
	//  |--photo1 // cross-persistent-root link, default branch
	//  |
	//  \--photo1 // cross-persistent-root link, branchA
	//
	// photo1 <<persistent root, branchA>>
	//  |
	//  \--childA
	//
	// photo1 <<persistent root, branchB>>
	//  |
	//  \--childB
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COBranch *branchA = photo1.currentBranch;
    OutlineItem *photo1root = photo1.rootObject;
    photo1root.label = @"photo1, branch A";
    
    OutlineItem *childA = [photo1.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    childA.label = @"childA";
    
    [photo1root addObject: childA];
    [photo1 commit];
    
    COBranch *branchB = [photo1.currentBranch makeBranchWithLabel: @"branchB"];
    OutlineItem *photo1branchBroot = branchB.objectGraphContext.rootObject;
    photo1branchBroot.label = @"photo1, branch B";
    
    OutlineItem *childB = [photo1branchBroot.contents firstObject];
    childB.label = @"childB";
    
    [ctx commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [(Tag *)library1.rootObject setContents: S(photo1.rootObject, branchA.rootObject)];
	UKIntsEqual(2, [[library1.rootObject contents] count]);
	
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1, branch A"), [library1.rootObject valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(A(@"childA")), [library1.rootObject valueForKeyPath: @"contents.contents.label"]);
    
    // Now switch the current branch of photo1. This should automatically update the cross-persistent reference
    
    photo1.currentBranch = branchB;
    
    UKObjectsEqual(S(@"photo1, branch A", @"photo1, branch B"), [library1.rootObject valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(A(@"childA"), A(@"childB")), [library1.rootObject valueForKeyPath: @"contents.contents.label"]);
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: library1
											  inBlock: ^(COEditingContext *ctx2, COPersistentRoot *library1ctx2, COBranch *testBranch, BOOL isNewContext)
	 {
        // Test that the cross-persistent reference uses branchB when we reopen the store
        
        COPersistentRoot *photo1ctx2 = [ctx2 persistentRootForUUID: photo1.UUID];
        
        // Sanity check
        
        UKObjectsEqual([branchB UUID], [[photo1ctx2 currentBranch] UUID]);
        UKObjectsEqual(A(@"childB"), [photo1ctx2.rootObject valueForKeyPath: @"contents.label"]);
        
        // Actual test of cross-persistent-root references
        
        UKObjectsEqual(S(@"photo1, branch A", @"photo1, branch B"), [library1ctx2.rootObject valueForKeyPath: @"contents.label"]);
        UKObjectsEqual(S(A(@"childA"), A(@"childB")), [library1ctx2.rootObject valueForKeyPath: @"contents.contents.label"]);
	 }];
}

/**
 * See: "cross persistent root reference semantics.key"
 */
- (void) testPersonAndPersonGroupBranch
{
    // Group <<persistent root>>
	//  |
	//  \-- << branch A (current branch) >>
	//  | |
	//  | |-- John (current branch)
	//  | |
	//  | \-- Lucy (current branch)
	//  |
	//  \-- << branch B >>
	//    |
	//    |-- John (current branch)
	//    |
	//    \-- Lucy (current branch)
	//
	// We're interested in how the inverse (parent) pointers in John and Lucy are calculated here.
	   
	COPersistentRoot *john = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupContent"];
	OrderedGroupContent *johnRoot = john.rootObject;
	johnRoot.label = @"John";
	
	COPersistentRoot *lucy = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupContent"];
	OrderedGroupContent *lucyRoot = lucy.rootObject;
	lucyRoot.label = @"Lucy";
	
	COPersistentRoot *group = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupWithOpposite"];
	[ctx commit]; /* FIXME: HACK */
	
	COBranch *groupA = group.currentBranch;
	OrderedGroupWithOpposite *groupARoot = groupA.rootObject;
	groupARoot.label = @"GroupA";
	groupARoot.contents = @[johnRoot, lucyRoot];
	
	[ctx commit];
	
	// Setup Group branch B
	
	COBranch *groupB = [groupA makeBranchWithLabel: @"GroupB"];
	OrderedGroupWithOpposite *groupBRoot = groupB.rootObject;
	groupBRoot.label = @"GroupB";
	/* No change to groupBRoot.content */
	
	[ctx commit];
	
	// Check the current (tracking) branch context of Group
	
	[self checkPersistentRootWithExistingAndNewContext: group
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testGroupRoot = testProot.rootObject;
		 OrderedGroupContent *testJohnRoot = testGroupRoot.contents[0];
		 OrderedGroupContent *testLucyRoot = testGroupRoot.contents[1];
		 
		 UKObjectsEqual(@"GroupA", testGroupRoot.label);
		 UKObjectsEqual(@"John", testJohnRoot.label);
		 UKObjectsEqual(@"Lucy", testLucyRoot.label);
		 
		 UKFalse([[testGroupRoot objectGraphContext] isTrackingSpecificBranch]);
		 UKFalse([[testJohnRoot objectGraphContext] isTrackingSpecificBranch]);
		 UKFalse([[testLucyRoot objectGraphContext] isTrackingSpecificBranch]);
		 
		 // Ensure that the computed parents of Lucy and John are the "current branch object context" of Group,
		 // not a specific branch one.
		 
		 UKObjectsEqual(S(testGroupRoot), testJohnRoot.parentGroups);
		 UKObjectsEqual(S(testGroupRoot), testLucyRoot.parentGroups);
	 }];
	
	// Check out both specific branches of Group
	
	[self checkBranchWithExistingAndNewContext: groupA
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testBranchARoot = testBranch.rootObject;
		 OrderedGroupContent *testJohnRoot = testBranchARoot.contents[0];
		 OrderedGroupContent *testLucyRoot = testBranchARoot.contents[1];
		 
		 UKObjectsEqual(@"GroupA", testBranchARoot.label);
		 UKObjectsEqual(@"John", testJohnRoot.label);
		 UKObjectsEqual(@"Lucy", testLucyRoot.label);

		 UKTrue([[testBranchARoot objectGraphContext] isTrackingSpecificBranch]);
		 UKFalse([[testJohnRoot objectGraphContext] isTrackingSpecificBranch]);
		 UKFalse([[testLucyRoot objectGraphContext] isTrackingSpecificBranch]);
		 
		 // Ensure that the computed parents of Lucy and John are the "current branch object context" of Group,
		 // not a specific branch one.
		 
		 UKObjectsEqual(S(testProot.rootObject), testJohnRoot.parentGroups);
		 UKObjectsEqual(S(testProot.rootObject), testLucyRoot.parentGroups);
		 
		 UKObjectsNotEqual(S(testBranchARoot), testJohnRoot.parentGroups);
		 UKObjectsNotEqual(S(testBranchARoot), testLucyRoot.parentGroups);
	 }];

	[self checkBranchWithExistingAndNewContext: groupB
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testBranchBRoot = testBranch.rootObject;
		 OrderedGroupContent *testJohnRoot = testBranchBRoot.contents[0];
		 OrderedGroupContent *testLucyRoot = testBranchBRoot.contents[1];
		 
		 UKObjectsEqual(@"GroupB", testBranchBRoot.label);
		 UKObjectsEqual(@"John", testJohnRoot.label);
		 UKObjectsEqual(@"Lucy", testLucyRoot.label);
		 
		 UKTrue([[testBranchBRoot objectGraphContext] isTrackingSpecificBranch]);
		 UKFalse([[testJohnRoot objectGraphContext] isTrackingSpecificBranch]);
		 UKFalse([[testLucyRoot objectGraphContext] isTrackingSpecificBranch]);

		 // Ensure that the computed parents of Lucy and John are the "current branch object context" of Group
		 // not a specific branch one.
		 
		 UKObjectsEqual(S(testProot.rootObject), testJohnRoot.parentGroups);
		 UKObjectsEqual(S(testProot.rootObject), testLucyRoot.parentGroups);
		 
		 UKObjectsNotEqual(S(testBranchBRoot), testJohnRoot.parentGroups);
		 UKObjectsNotEqual(S(testBranchBRoot), testLucyRoot.parentGroups);
	 }];
	
	// Make a branch B of Lucy and make it current
	
	COBranch *lucyA = lucy.currentBranch;
	COBranch *lucyB = [lucyA makeBranchWithLabel: @"LucyB"];
	lucy.currentBranch = lucyB;
	OrderedGroupContent *lucyBRoot = lucyB.rootObject;
	lucyBRoot.label = @"LucyB";
	[ctx commit];
	
	// Check out both specific branches of Group again
	
	[self checkBranchWithExistingAndNewContext: groupA
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testBranchARoot = testBranch.rootObject;
		 OrderedGroupContent *testJohnRoot = testBranchARoot.contents[0];
		 OrderedGroupContent *testLucyRoot = testBranchARoot.contents[1];

		 UKObjectsEqual(@"LucyB", testLucyRoot.label);
		 
		 UKObjectsEqual(S(testProot.rootObject), testJohnRoot.parentGroups);
		 UKObjectsEqual(S(testProot.rootObject), testLucyRoot.parentGroups);
	 }];
	
	[self checkBranchWithExistingAndNewContext: groupB
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testBranchBRoot = testBranch.rootObject;
		 OrderedGroupContent *testJohnRoot = testBranchBRoot.contents[0];
		 OrderedGroupContent *testLucyRoot = testBranchBRoot.contents[1];
		 
		 UKObjectsEqual(@"LucyB", testLucyRoot.label);
		 
		 UKObjectsEqual(S(testProot.rootObject), testJohnRoot.parentGroups);
		 UKObjectsEqual(S(testProot.rootObject), testLucyRoot.parentGroups);
	 }];
	
	// Check out both specifc branches of Lucy
	
	[self checkBranchWithExistingAndNewContext: lucyA
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupContent *testLucyARoot = testBranch.rootObject;
		 UKObjectsEqual(@"Lucy", testLucyARoot.label);
	
		 // HACK: Have to unfault the group proot to populate testLucyARoot.parentGroups
		 OrderedGroupWithOpposite *testGroup = [testCtx persistentRootForUUID: group.UUID].rootObject;
		 
		 // The parent ref points to the current branch of Group
		 UKIntsEqual(1, [testLucyARoot.parentGroups count]);
		 UKObjectsSame(testGroup, [testLucyARoot.parentGroups anyObject]);
		 
		 UKFalse([[testGroup objectGraphContext] isTrackingSpecificBranch]);
		 UKObjectsEqual(@"GroupA", testGroup.label);
	 }];
	
	[self checkBranchWithExistingAndNewContext: lucyB
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupContent *testLucyBRoot = testBranch.rootObject;
		 UKObjectsEqual(@"LucyB", testLucyBRoot.label);
		 
		 // HACK: Have to unfault the group proot to populate testLucyARoot.parentGroups
		 OrderedGroupWithOpposite *testGroup = [testCtx persistentRootForUUID: group.UUID].rootObject;
		 
		 // The parent ref points to the current branch of Group
		 UKIntsEqual(1, [testLucyBRoot.parentGroups count]);
		 UKObjectsSame(testGroup, [testLucyBRoot.parentGroups anyObject]);
		 
		 UKFalse([[testGroup objectGraphContext] isTrackingSpecificBranch]);
		 UKObjectsEqual(@"GroupA", testGroup.label);
	 }];
}

- (void) testBranchDeletion
{
    // library1 <<persistent root>>
	//  |
	//  \--photo1 // cross-persistent-root link, branchB
	//
	// photo1 <<persistent root, branchA>>
    //
	// photo1 <<persistent root, branchB>>
    //
    // Test the effect of deleting branchB
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1 commit];

    COBranch *branchA = photo1.currentBranch;
    COBranch *branchB = [branchA makeBranchWithLabel: @"branchB"];
    [branchB.rootObject setLabel: @"photo1, branch B"];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    
    /* This creates a reference to branch B of photo1. */
	[library1.rootObject addObject: branchB.rootObject];
    [ctx commit];
    
    // Valid reference should be visible in existing and new context
    [self checkPersistentRootWithExistingAndNewContext: library1
                                               inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
     {
         UKObjectsEqual(S(@"photo1, branch B"), [[[testProot.rootObject contents] mappedCollection] label]);
     }];

	branchB.deleted = YES;
    
    // Uncommitted deletion, reference should be hidden in current context but visible in a new one
    [self checkPersistentRootWithExistingAndNewContext: library1
                                               inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
     {
         if (isNewContext)
             UKObjectsEqual(S(@"photo1, branch B"), [[[testProot.rootObject contents] mappedCollection] label]);
         else
             UKObjectsEqual(S(), [[[testProot.rootObject contents] mappedCollection] label]);
     }];
    
    [ctx commit];
	
    // Committed deletion, reference should be hidden
    [self checkPersistentRootWithExistingAndNewContext: library1
                                               inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
     {
         UKObjectsEqual(S(), [[[testProot.rootObject contents] mappedCollection] label]);
     }];
    
	UKTrue(branchB.deleted);
	[store finalizeDeletionsForPersistentRoot: photo1.UUID
									 error: NULL];
	UKTrue(branchB.deleted);

    // Finalized deletion, reference should be hidden
    [self checkPersistentRootWithExistingAndNewContext: library1
                                               inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
     {
         UKObjectsEqual(S(), [[[testProot.rootObject contents] mappedCollection] label]);
     }];
}

- (void) testMultipleRelationshipsPerObject
{
    // tag1 <<persistent root>>
	//  |
	//  \--photo1 // content property, cross-persistent-root link
	//  |
	//  \--photo2 // content property, cross-persistent-root link
	//
	// photo1 <<persistent root>>
    //
	// photo2 <<persistent root>>
	//
    // Test the effect of deleting photo1 (photo2 should continue to work)
    
    COPersistentRoot *tag1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
	COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *photo2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];

	NSMutableSet *tag1ContentsProxy = [tag1.rootObject mutableSetValueForKey: @"contents"];
	[tag1ContentsProxy addObject: photo1.rootObject];
	[tag1ContentsProxy addObject: photo2.rootObject];
	
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: tag1
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(S([photo1.rootObject UUID], [photo2.rootObject UUID]), [[[testProot.rootObject contents] mappedCollection] UUID]);
	 }];
	
	photo1.deleted = YES;
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: tag1
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(S([photo2.rootObject UUID]), [[[testProot.rootObject contents] mappedCollection] UUID]);
	 }];
}

- (void) testPersistentRootDeletion
{
    // library1 <<persistent root>>
	//  |
	//  \--photo1 // cross-persistent-root link,
	//
	// photo1 <<persistent root>>
    //
    // Test that deleting photo1 hides the child relationship in library1 to phtoto1
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1.rootObject setValue: @"photo1" forProperty: @"label"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    /* This creates a reference to photo1. */
    [library1.rootObject insertObject: photo1.rootObject atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1"), [library1.rootObject valueForKeyPath: @"contents.label"]);

    // Now delete photo1. This should automatically update the cross-persistent reference
    
    photo1.deleted = YES;
    
    UKObjectsEqual([NSSet set], [library1.rootObject valueForKeyPath: @"contents.label"]);
    
    [ctx commit];
}

- (void) testLibraryPersistentRootDeletion
{
    // library1 <<persistent root>>
	//  |
	//  \--photo1 // cross-persistent-root link,
	//
	// photo1 <<persistent root>>
    //
    // Test that deleting library1 hides the parent relationship in photo1 to library1
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1.rootObject setLabel: @"photo1"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [library1.rootObject setLabel: @"library1"];
    [library1.rootObject addObject: photo1.rootObject];
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1"), [library1.rootObject valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(@"library1"), [photo1.rootObject valueForKeyPath: @"parentCollections.label"]);
    
    // Now delete library1. This should automatically update the derived cross-persistent reference in photo1
    
    library1.deleted = YES;
    
	UKObjectsEqual([NSSet set], [photo1.rootObject valueForKeyPath: @"parentCollections.label"]);
    
    [ctx commit];
}

- (void) testPersistentRootUndeletion
{
    // library1 <<persistent root>>
	//  |
	//  \--photo1 // cross-persistent-root link
	//  |
    //  \--photo2 // inner reference to inner object
    //
	// photo1 <<persistent root>>
    //
    // Test that undeleting photo1 restores the child relationship in library1
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1.rootObject setLabel: @"photo1"];
    [photo1 commit];
        
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    /* This creates a reference to photo1. */
    [library1.rootObject addObject: photo1.rootObject];
    
    [ctx commit];
    
    // Delete photo1
    
    photo1.deleted = YES;
    [ctx commit];
    
    UKObjectsEqual(S(), [library1.rootObject valueForKeyPath: @"contents.label"]);
    
    // Add photo2 inner item. Note that the photo1 cross-persistent-root reference is
    // still present in library1.contents, it's just hidden.
	
    COObject *photo2 = [library1.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [photo2 setValue: @"photo2" forProperty: @"label"];
    [library1.rootObject addObject: photo2];
    
    UKObjectsEqual(S(@"photo2"), [library1.rootObject valueForKeyPath: @"contents.label"]);
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: library1
											  inBlock: ^(COEditingContext *ctx2, COPersistentRoot *library1ctx2, COBranch *testBranch, BOOL isNewContext)
	 {
        UKFalse([[library1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual(S(@"photo2"), [library1ctx2.rootObject valueForKeyPath: @"contents.label"]);
        
        // Undelete photo1, which should restore the cross-root relationship
        
        COPersistentRoot *photo1ctx2 = [ctx2.deletedPersistentRoots anyObject];
        [photo1ctx2 setDeleted: NO];
        
        UKFalse([[library1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual(S(@"photo1", @"photo2"), [library1ctx2.rootObject valueForKeyPath: @"contents.label"]);
	 }];
}

- (void) testLibraryPersistentRootUndeletion
{
    // library1 <<persistent root>>
	//  |
	//  \--photo1 // cross-persistent-root link
	//
	// photo1 <<persistent root>>
    //
    // Test that undeleting library1 restores the parent relationship in photo1
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1.rootObject setLabel: @"photo1"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [library1.rootObject setLabel: @"library1"];
    [library1.rootObject addObject: photo1.rootObject];
    [ctx commit];
    
    library1.deleted = YES;
    [ctx commit];
	
	
	// FIXME: Currently fails for the isNewContext==NO case
	// Caused by https://github.com/etoile/CoreObject/issues/20
#if 0
	[self checkPersistentRootWithExistingAndNewContext: photo1
											   inBlock: ^(COEditingContext *ctx2, COPersistentRoot *photo1ctx2, COBranch *testBranch, BOOL isNewContext)
	 {
        UKFalse([[photo1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual([NSSet set], [photo1ctx2.rootObject valueForKeyPath: @"parentCollections.label"]);
        
        // Undelete library1, which should restore the cross-root inverse relationship
		
		// Check the -deletedPersistentRoots property
		NSSet *deletedProots = [ctx2 deletedPersistentRoots];
		UKIntsEqual(1, [deletedProots count]);
        COPersistentRoot *library1ctx2 = [deletedProots anyObject];
		UKObjectsEqual([library1 UUID], [library1ctx2 UUID]);
        //[library1ctx2 setDeleted: NO];

        //UKFalse([[photo1ctx2 objectGraphContext] hasChanges]);
        //UKObjectsEqual(S(@"library1"), [photo1ctx2.rootObject valueForKeyPath: @"parentCollections.label"]);
	 }];
#endif
}

- (void) testCompositeCrossReference
{
    COPersistentRoot *doc1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *child1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    UKRaisesException([doc1.rootObject addObject: child1.rootObject]);
	
	// TODO: In fact, the illegal reference was actually inserted, so the object graph is in an
	// illegal state now.
}

- (void)testCompositeReferenceWithTransientParentAndPersistentChild
{
	COObjectGraphContext *transientCtx1 = [COObjectGraphContext new];
	
    OutlineItem *parent = [[OutlineItem alloc] initWithObjectGraphContext: transientCtx1];
    OutlineItem *child = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
	
	UKDoesNotRaiseException([parent addObject: child]);
	
	// TODO: Perhaps test making the child persistent (ok)
}

- (void)testCompositeReferenceWithPersistentParentAndTransientChild
{
	COObjectGraphContext *transientCtx1 = [COObjectGraphContext new];
	
    OutlineItem *parent = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    OutlineItem *child = [[OutlineItem alloc] initWithObjectGraphContext: transientCtx1];
	
	UKRaisesException([parent addObject: child]);
}

- (void)testCompositeReferenceAccrossTransientObjectGraphContexts
{
	COObjectGraphContext *transientCtx1 = [COObjectGraphContext new];
	COObjectGraphContext *transientCtx2 = [COObjectGraphContext new];

    OutlineItem *parent = [[OutlineItem alloc] initWithObjectGraphContext: transientCtx1];
    OutlineItem *child = [[OutlineItem alloc] initWithObjectGraphContext: transientCtx2];
	
	UKDoesNotRaiseException([parent addObject: child]);
	
	// TODO: Perhaps test making the child persistent (ok), making the parent
	/// persistent (invalid), and making the child persistent then the parent
	// persistent (ok)
}

// TODO: The code below probably belongs to TestUnivaluedRelationshipWithOpposite,
// but this requires to rework Relationship test classes as TestCommon subclasses.

/**
 * When a persistent root is created, the current branch is split in two 
 * replicates, the tracking branch -[COPersistentRoot objectGraphContext] 
 * (using the initial object graph context), and the non-tracking branch 
 * that can accessed through -[COPersistentRoot branchForUUID:].
 *
 * The non-tracking branch is created as a replicate using -setItemGraph:.
 */
- (void) testUnivaluedGroupWithOppositeInPersistentRoot
{
	COObjectGraphContext *graph = [COObjectGraphContext new];

	/* The group in the tracking branch */
	UnivaluedGroupWithOpposite *group =
		[[UnivaluedGroupWithOpposite alloc] initWithObjectGraphContext: graph];
	UnivaluedGroupContent *content =
		[[UnivaluedGroupContent alloc] initWithObjectGraphContext: graph];
	group.content = content;
	
	UKObjectsSame(content, [group content]);
	UKObjectsSame(group, [[content parents] anyObject]);
	UKObjectsEqual(S(group), [content parents]);

	COPersistentRoot *proot = [ctx insertNewPersistentRootWithRootObject: group];
	COBranch *nonTrackingBranch = [proot branchForUUID: graph.branchUUID];
	
	/* The group and content in the non-tracking branch */
	UnivaluedGroupWithOpposite *shadowGroup =
		[nonTrackingBranch.objectGraphContext loadedObjectForUUID: group.UUID];
	UnivaluedGroupContent *shadowContent =
		[nonTrackingBranch.objectGraphContext loadedObjectForUUID: content.UUID];

	UKObjectsSame(shadowContent, [shadowGroup content]);
	UKObjectsSame(shadowGroup, [[shadowContent parents] anyObject]);
	UKObjectsEqual(S(shadowGroup), [shadowContent parents]);
	
	UKObjectsNotSame(group, shadowGroup);
	UKObjectsNotSame(content, shadowContent);
	
	// TODO: Make a change in one branch, then commit and test both the tracking
	// and non-tracking branch contains the same object graphs in the current
	// context and a recreated context.
}


@end
