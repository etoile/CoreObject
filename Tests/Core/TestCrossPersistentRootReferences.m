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
    [[photo1 rootObject] setLabel: @"photo1"];
    
    COPersistentRoot *photo2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[photo2 rootObject] setLabel: @"photo2"];
    
    COPersistentRoot *library = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [[library rootObject] addObject: [photo1 rootObject]];
    [[library rootObject] addObject: [photo2 rootObject]];
    
    UKObjectsEqual(S([photo1 rootObject], [photo2 rootObject]), [[library rootObject] contents]);
    
    // Do the computed parentCollections properties work across persistent root boundaries?
    UKObjectsEqual(S([library rootObject]), [[photo1 rootObject] parentCollections]);
    UKObjectsEqual(S([library rootObject]), [[photo2 rootObject] parentCollections]);
    
    // Check that nothing is committed yet
    UKObjectsEqual([NSArray array], [store persistentRootUUIDs]);
    
    [ctx commit];

	[self checkPersistentRootWithExistingAndNewContext: library
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testLibrary, COBranch *testBranch, BOOL isNewContext)
	 {
		 NSArray *library2contents = [[testLibrary rootObject] valueForKey: @"contents"];
		 UKIntsEqual(2, [library2contents count]);
		 
		 COPersistentRoot *photo1ctx2 = nil;
		 COPersistentRoot *photo2ctx2 = nil;
		 
		 for (COObject *obj in library2contents)
		 {
			 if ([[obj valueForKey: @"label"] isEqual: @"photo1"])
			 {
				 photo1ctx2 = [obj persistentRoot];
			 }
			 else if ([[obj valueForKey: @"label"] isEqual: @"photo2"])
			 {
				 photo2ctx2 = [obj persistentRoot];
			 }
		 }
		 
		 UKObjectsEqual([photo1 UUID], [photo1ctx2 UUID]);
		 UKObjectsEqual([photo2 UUID], [photo2ctx2 UUID]);
		 UKObjectsEqual([[photo1 rootObject] UUID], [[photo1ctx2 rootObject] UUID]);
		 UKObjectsEqual([[photo2 rootObject] UUID], [[photo2ctx2 rootObject] UUID]);
		 UKObjectsEqual(@"photo1", [[photo1ctx2 rootObject] label]);
		 UKObjectsEqual(@"photo2", [[photo2ctx2 rootObject] label]);
	 }];
}

- (void) testSpecificAndCurrentBranchReferenceInSet
{
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COBranch *branchA = [photo1 currentBranch];
    
	OutlineItem *photo1root = [photo1 rootObject];
	OutlineItem *branchAroot = [branchA rootObject];
	
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
	COBranch *branchA = [photo1 currentBranch];
    OutlineItem *photo1root = [photo1 rootObject];
    photo1root.label = @"photo1, branch A";
    
    OutlineItem *childA = [[photo1 objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    childA.label = @"childA";
    
    [photo1root addObject: childA];
    [photo1 commit];
    
    COBranch *branchB = [[photo1 currentBranch] makeBranchWithLabel: @"branchB"];
    OutlineItem *photo1branchBroot = [[branchB objectGraphContext] rootObject];
    photo1branchBroot.label = @"photo1, branch B";
    
    OutlineItem *childB = [photo1branchBroot.contents firstObject];
    childB.label = @"childB";
    
    [ctx commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [[library1 rootObject] setContents: S([photo1 rootObject], [branchA rootObject])];
	UKIntsEqual(2, [[[library1 rootObject] contents] count]);
	
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1, branch A"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(A(@"childA")), [[library1 rootObject] valueForKeyPath: @"contents.contents.label"]);
    
    // Now switch the current branch of photo1. This should automatically update the cross-persistent reference
    
    [photo1 setCurrentBranch: branchB];
    
    UKObjectsEqual(S(@"photo1, branch A", @"photo1, branch B"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(A(@"childA"), A(@"childB")), [[library1 rootObject] valueForKeyPath: @"contents.contents.label"]);
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: library1
											  inBlock: ^(COEditingContext *ctx2, COPersistentRoot *library1ctx2, COBranch *testBranch, BOOL isNewContext)
	 {
        // Test that the cross-persistent reference uses branchB when we reopen the store
        
        COPersistentRoot *photo1ctx2 = [ctx2 persistentRootForUUID: [photo1 UUID]];
        
        // Sanity check
        
        UKObjectsEqual([branchB UUID], [[photo1ctx2 currentBranch] UUID]);
        UKObjectsEqual(A(@"childB"), [[photo1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
        
        // Actual test of cross-persistent-root references
        
        UKObjectsEqual(S(@"photo1, branch A", @"photo1, branch B"), [[library1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
        UKObjectsEqual(S(A(@"childA"), A(@"childB")), [[library1ctx2 rootObject] valueForKeyPath: @"contents.contents.label"]);
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
	OrderedGroupContent *johnRoot = [john rootObject];
	johnRoot.label = @"John";
	
	COPersistentRoot *lucy = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupContent"];
	OrderedGroupContent *lucyRoot = [lucy rootObject];
	lucyRoot.label = @"Lucy";
	
	COPersistentRoot *group = [ctx insertNewPersistentRootWithEntityName: @"OrderedGroupWithOpposite"];
	[ctx commit]; /* FIXME: HACK */
	
	COBranch *groupA = [group currentBranch];
	OrderedGroupWithOpposite *groupARoot = [groupA rootObject];
	groupARoot.label = @"GroupA";
	groupARoot.contents = @[johnRoot, lucyRoot];
	
	[ctx commit];
	
	// Setup Group branch B
	
	COBranch *groupB = [groupA makeBranchWithLabel: @"GroupB"];
	OrderedGroupWithOpposite *groupBRoot = [groupB rootObject];
	groupBRoot.label = @"GroupB";
	/* No change to groupBRoot.content */
	
	[ctx commit];
	
	// Check the current (tracking) branch context of Group
	
	[self checkPersistentRootWithExistingAndNewContext: group
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testGroupRoot = [testProot rootObject];
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
		 OrderedGroupWithOpposite *testBranchARoot = [testBranch rootObject];
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
		 
		 UKObjectsEqual(S([testProot rootObject]), testJohnRoot.parentGroups);
		 UKObjectsEqual(S([testProot rootObject]), testLucyRoot.parentGroups);
		 
		 UKObjectsNotEqual(S(testBranchARoot), testJohnRoot.parentGroups);
		 UKObjectsNotEqual(S(testBranchARoot), testLucyRoot.parentGroups);
	 }];

	[self checkBranchWithExistingAndNewContext: groupB
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testBranchBRoot = [testBranch rootObject];
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
		 
		 UKObjectsEqual(S([testProot rootObject]), testJohnRoot.parentGroups);
		 UKObjectsEqual(S([testProot rootObject]), testLucyRoot.parentGroups);
		 
		 UKObjectsNotEqual(S(testBranchBRoot), testJohnRoot.parentGroups);
		 UKObjectsNotEqual(S(testBranchBRoot), testLucyRoot.parentGroups);
	 }];
	
	// Make a branch B of Lucy and make it current
	
	COBranch *lucyA = [lucy currentBranch];
	COBranch *lucyB = [lucyA makeBranchWithLabel: @"LucyB"];
	[lucy setCurrentBranch: lucyB];
	OrderedGroupContent *lucyBRoot = [lucyB rootObject];
	lucyBRoot.label = @"LucyB";
	[ctx commit];
	
	// Check out both specific branches of Group again
	
	[self checkBranchWithExistingAndNewContext: groupA
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testBranchARoot = [testBranch rootObject];
		 OrderedGroupContent *testJohnRoot = testBranchARoot.contents[0];
		 OrderedGroupContent *testLucyRoot = testBranchARoot.contents[1];

		 UKObjectsEqual(@"LucyB", testLucyRoot.label);
		 
		 UKObjectsEqual(S([testProot rootObject]), testJohnRoot.parentGroups);
		 UKObjectsEqual(S([testProot rootObject]), testLucyRoot.parentGroups);
	 }];
	
	[self checkBranchWithExistingAndNewContext: groupB
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupWithOpposite *testBranchBRoot = [testBranch rootObject];
		 OrderedGroupContent *testJohnRoot = testBranchBRoot.contents[0];
		 OrderedGroupContent *testLucyRoot = testBranchBRoot.contents[1];
		 
		 UKObjectsEqual(@"LucyB", testLucyRoot.label);
		 
		 UKObjectsEqual(S([testProot rootObject]), testJohnRoot.parentGroups);
		 UKObjectsEqual(S([testProot rootObject]), testLucyRoot.parentGroups);
	 }];
	
	// Check out both specifc branches of Lucy
	
	[self checkBranchWithExistingAndNewContext: lucyA
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupContent *testLucyARoot = [testBranch rootObject];
		 UKObjectsEqual(@"Lucy", testLucyARoot.label);
		 
		 // The parent ref points to the current branch of Group
		 UKIntsEqual(1, [testLucyARoot.parentGroups count]);
		 OrderedGroupWithOpposite *testGroup = [testLucyARoot.parentGroups anyObject];
		 
		 UKFalse([[testGroup objectGraphContext] isTrackingSpecificBranch]);
		 UKObjectsEqual(@"GroupA", testGroup.label);
	 }];
	
	[self checkBranchWithExistingAndNewContext: lucyB
									   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 OrderedGroupContent *testLucyBRoot = [testBranch rootObject];
		 UKObjectsEqual(@"LucyB", testLucyBRoot.label);
		 
		 // The parent ref points to the current branch of Group
		 UKIntsEqual(1, [testLucyBRoot.parentGroups count]);
		 OrderedGroupWithOpposite *testGroup = [testLucyBRoot.parentGroups anyObject];
		 
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
    
    COBranch *branchA = [photo1 currentBranch];
    COBranch *branchB = [branchA makeBranchWithLabel: @"branchB"];
    [branchB.rootObject setLabel: @"photo1, branch B"];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    
    /* This creates a reference to branch B of photo1. */
	[[library1 rootObject] addObject: branchB.rootObject];
    [ctx commit];

	branchB.deleted = YES;
    [ctx commit];
	
	[store finalizeDeletionsForPersistentRoot: [photo1 UUID]
									 error: NULL];
	
	// TODO: The persistent root should notice that the branch was permanently
	// deleted, and move the COObjectGraphContext to a CODeletedBranch
	// (but the COObject pointer to the root object remains valid.)
	//
	// 4 cases:
	// - loaded in memory -> root broken reference in memory, deleted
	// - not in memory -> root broken reference in memory, deleted
	// - root broken reference in memory, deleted -> restored from backup (?)
	// - not in memory -> loaded in memory (regular case)
}

- (void) testMultipleRelationshipsPerObject
{
    // tag1 <<persistent root>>
	//  |
	//  \--photo1 // content property, cross-persistent-root link
	//  |
	//  \--tag2 // childTags property, cross-persistent-root link
	//
	// photo1 <<persistent root>>
    //
	// tag2 <<persistent root>>
	//
    // Test the effect of deleting photo1 (tag2 should continue to work)
    
    COPersistentRoot *tag1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    COPersistentRoot *tag2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
	COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	
	[[[tag1 rootObject] mutableSetValueForKey: @"contents"] addObject: [photo1 rootObject]];
	[[[tag1 rootObject] mutableSetValueForKey: @"childTags"] addObject: [tag2 rootObject]];
	
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: tag1
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(S([[photo1 rootObject] UUID]), [[[[testProot rootObject] contents] mappedCollection] UUID]);
		 UKObjectsEqual(S([[tag2 rootObject] UUID]), [[[[testProot rootObject] childTags] mappedCollection] UUID]);
	 }];
	
	photo1.deleted = YES;
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: tag1
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(S([[photo1 rootObject] UUID]), [[[[testProot rootObject] contents] mappedCollection] UUID]);
		 UKObjectsEqual(S([[tag2 rootObject] UUID]), [[[[testProot rootObject] childTags] mappedCollection] UUID]);
	 }];
}

- (void) testMultipleRelationshipsPerObject2
{
    COPersistentRoot *tag1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    COPersistentRoot *tag2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
	COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];

	// Same as last test but order of these two statements is swapped
	[[[tag1 rootObject] mutableSetValueForKey: @"childTags"] addObject: [tag2 rootObject]];
	[[[tag1 rootObject] mutableSetValueForKey: @"contents"] addObject: [photo1 rootObject]];
	
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: tag1
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(S([[photo1 rootObject] UUID]), [[[[testProot rootObject] contents] mappedCollection] UUID]);
		 UKObjectsEqual(S([[tag2 rootObject] UUID]), [[[[testProot rootObject] childTags] mappedCollection] UUID]);
	 }];
	
	photo1.deleted = YES;
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: tag1
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(S([[photo1 rootObject] UUID]), [[[[testProot rootObject] contents] mappedCollection] UUID]);
		 UKObjectsEqual(S([[tag2 rootObject] UUID]), [[[[testProot rootObject] childTags] mappedCollection] UUID]);
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
    [[photo1 rootObject] setValue: @"photo1" forProperty: @"label"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    /* This creates a reference to photo1. */
    [[library1 rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);

    // Now delete photo1. This should automatically update the cross-persistent reference
    
    photo1.deleted = YES;
    
    // FIXME: UKObjectsEqual([NSSet set], [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    
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
    [[photo1 rootObject] setLabel: @"photo1"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [[library1 rootObject] setLabel: @"library1"];
    [[library1 rootObject] addObject: [photo1 rootObject]];
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(@"library1"), [[photo1 rootObject] valueForKeyPath: @"parentCollections.label"]);
    
    // Now delete library1. This should automatically update the derived cross-persistent reference in photo1
    
    library1.deleted = YES;
    
    // FIXME: UKObjectsEqual([NSSet set], [[photo1 rootObject] valueForKeyPath: @"parentCollections.label"]);
    
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
    [[photo1 rootObject] setLabel: @"photo1"];
    [photo1 commit];
        
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    /* This creates a reference to photo1. */
    [[library1 rootObject] addObject: [photo1 rootObject]];
    
    [ctx commit];
    
    // Delete photo1
    
    photo1.deleted = YES;
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    
    // Add photo2 inner item. Note that the photo1 cross-persistent-root reference is
    // still present in library1.contents, it's just hidden.
    // FIXME: That is the part that's difficult to implement and not currently implemented.
	// See comment in -[COObject updateOutgoingSerializedRelationshipCacheForProperty]
	
    COObject *photo2 = [[library1 objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [photo2 setValue: @"photo2" forProperty: @"label"];
    [[library1 rootObject] addObject: photo2];
    
    UKObjectsEqual(S(@"photo1", @"photo2"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    
    [ctx commit];
    
	[self checkPersistentRootWithExistingAndNewContext: library1
											  inBlock: ^(COEditingContext *ctx2, COPersistentRoot *library1ctx2, COBranch *testBranch, BOOL isNewContext)
	 {
        UKFalse([[library1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual(S(@"photo1", @"photo2"), [[library1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
        
        // Undelete photo1, which should restore the cross-root relationship
        
        COPersistentRoot *photo1ctx2 = [[ctx2 deletedPersistentRoots] anyObject];
        [photo1ctx2 setDeleted: NO];
        
		// FIXME: Currently broken, see comment in -[COObject updateCrossPersistentRootReferences]
        //UKFalse([[library1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual(S(@"photo1", @"photo2"), [[library1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
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
    [[photo1 rootObject] setLabel: @"photo1"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [[library1 rootObject] setLabel: @"library1"];
    [[library1 rootObject] addObject: [photo1 rootObject]];
    [ctx commit];
    
    library1.deleted = YES;
    [ctx commit];
    
	// FIXME: Currently fails for the isNewContext==NO case
#if 0
	[self testPersistentRootWithExistingAndNewContext: photo1
											  inBlock: ^(COEditingContext *ctx2, COPersistentRoot *photo1ctx2, COBranch *testBranch, BOOL isNewContext)
	 {
        UKFalse([[photo1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual([NSSet set], [[photo1ctx2 rootObject] valueForKeyPath: @"parentCollections.label"]);
        
        // Undelete library1, which should restore the cross-root inverse relationship
        
        COPersistentRoot *library1ctx2 = [[ctx2 deletedPersistentRoots] anyObject];
        [library1ctx2 setDeleted: NO];

        UKFalse([[photo1ctx2 objectGraphContext] hasChanges]);
        //FIXME: UKObjectsEqual(S(@"photo1"), [[photo1ctx2 rootObject] valueForKeyPath: @"parentCollections.label"]);
	 }];
#endif
}

- (void) testCompositeCrossReference
{
    COPersistentRoot *doc1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *child1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[doc1 rootObject] addObject: [child1 rootObject]];
	UKRaisesException([ctx commit]);
}

@end