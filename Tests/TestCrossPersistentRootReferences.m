#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestCrossPersistentRootReferences : TestCommon <UKTest>
@end

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
    [[photo1 rootObject] setValue: @"photo1" forProperty: @"label"];
    
    COPersistentRoot *photo2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[photo2 rootObject] setValue: @"photo2" forProperty: @"label"];
    
    COPersistentRoot *library = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [[library rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    [[library rootObject] insertObject: [photo2 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    
    UKObjectsEqual(S([photo1 rootObject], [photo2 rootObject]), [[library rootObject] valueForKey: @"contents"]);
    
    // Do the computed parentCollections properties work across persistent root boundaries?
    UKObjectsEqual(S([library rootObject]), [[photo1 rootObject] valueForKey: @"parentCollections"]);
    UKObjectsEqual(S([library rootObject]), [[photo2 rootObject] valueForKey: @"parentCollections"]);
    
    // Check that nothing is committed yet
    UKObjectsEqual([NSArray array], [store persistentRootUUIDs]);
    
    [ctx commit];

    // 2. Read it into another context
    {
        COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: store];
        COPersistentRoot *library2 = [ctx2 persistentRootForUUID: [library persistentRootUUID]];
        
        NSArray *library2contents = [[library2 rootObject] valueForKey: @"contents"];
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
        
        UKObjectsEqual([photo1 persistentRootUUID], [photo1ctx2 persistentRootUUID]);
        UKObjectsEqual([photo2 persistentRootUUID], [photo2ctx2 persistentRootUUID]);
        UKObjectsEqual([[photo1 rootObject] UUID], [[photo1ctx2 rootObject] UUID]);
        UKObjectsEqual([[photo2 rootObject] UUID], [[photo2ctx2 rootObject] UUID]);
        UKObjectsEqual(@"photo1", [[photo1ctx2 rootObject] valueForKey: @"label"]);
        UKObjectsEqual(@"photo2", [[photo2ctx2 rootObject] valueForKey: @"label"]);
    }
}

#if 0

- (void) testAsyncFaulting
{
    // library1 <<persistent root>>
	//  |
	//  \--photo1 // cross-persistent-root link, default branch
	//
	// photo1 <<persistent root>>
	//  |
	//  \--child1 (pretend there are a lot of child objects)
    
    
    // 1. Set it up in memory
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COObject *child1 = [photo1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];

    [[photo1 rootObject] setValue: @"photo1" forProperty: @"label"];
    [[photo1 rootObject] insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    
    [ctx commit];
    
    // 2. Read it into another context
    
    {
        COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: store];
        COPersistentRoot *persistentRoot2 = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COPersistentRoot *photo1ctx2 = [[[[persistentRoot2 rootObject] valueForKey: @"contents"] objectAtIndex: 0] persistentRoot];
        
        // This should be a fault
        COObject *photo1ctx2RootObject = [photo1ctx2 rootObject];
        
        // The relationship has not loaded yet.
        UKObjectsEqual([NSArray array], [photo1ctx2RootObject valueForKey: @"contents"]);
        
        // Now, suppose that triggers loading.
        // Should we automatically notify a delegate?
        
        // FIXME: Check for the loaded contents
    }
}

#endif

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
    COObject *photo1root = [photo1 rootObject];
    [photo1root setValue: @"photo1, branch A" forProperty: @"label"];
    
    COObject *childA = [photo1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childA setValue: @"childA" forProperty: @"label"];
    
    [photo1root insertObject: childA atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [photo1 commit];
    
    COBranch *branchB = [[photo1 currentBranch] makeBranchWithLabel: @"branchB"];
    COObject *photo1branchBroot = [[branchB objectGraphContext] rootObject];
    [photo1branchBroot setValue: @"photo1, branch B" forProperty: @"label"];
    
    COObject *childB = [[photo1branchBroot valueForKey: @"contents"] firstObject];
    // FIXME: Why was -setValue:forKey: appearing to work but not logging a change in the object graph?
    [childB setValue: @"childB" forProperty: @"label"];
    
    [ctx commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    /* This creates a reference to the current branch of photo1. */
    // FIXME: What should the API for referring to a specific branch look loke?
    [[library1 rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];

    [ctx commit];
    
    UKObjectsEqual(S(@"photo1, branch A"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(A(@"childA")), [[library1 rootObject] valueForKeyPath: @"contents.contents.label"]);
    
    // Now switch the current branch of photo1. This should automatically update the cross-persistent reference
    
    [photo1 setCurrentBranch: branchB];
    
    UKObjectsEqual(S(@"photo1, branch B"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(A(@"childB")), [[library1 rootObject] valueForKeyPath: @"contents.contents.label"]);
    
    [ctx commit];
    
    {
        // Test that the cross-persistent reference uses branchB when we reopen the store
        
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *library1ctx2 = [ctx2 persistentRootForUUID: [library1 persistentRootUUID]];
        COPersistentRoot *photo1ctx2 = [ctx2 persistentRootForUUID: [photo1 persistentRootUUID]];
        
        // Sanity check
        
        UKObjectsEqual([branchB UUID], [[photo1ctx2 currentBranch] UUID]);
        UKObjectsEqual(A(@"childB"), [[photo1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
        
        // Actual test of cross-persistent-root references
        
        UKObjectsEqual(S(@"photo1, branch B"), [[library1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
        UKObjectsEqual(S(A(@"childB")), [[library1ctx2 rootObject] valueForKeyPath: @"contents.contents.label"]);
    }
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
	//  |
	//  \--childB
    //
    // Test the effect of deleting branchB
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1 commit];
    
    COBranch *branchA = [photo1 currentBranch];
    COBranch *branchB = [branchA makeBranchWithLabel: @"branchB"];
    
    COObject *photo1branchBroot = [[branchB objectGraphContext] rootObject];
    
    [photo1branchBroot setValue: @"photo1, branch B" forProperty: @"label"];
    
    COObject *childB = [[branchB objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childB setValue: @"childB" forProperty: @"label"];
    
    [photo1branchBroot insertObject: childB atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    [ctx commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    
    /* This creates a reference to branch B of photo1. */
    COPath *branchBRef = [COPath pathWithPersistentRoot: [photo1 persistentRootUUID] branch: [branchB UUID]];
    COMutableItem *library1RootItem = [[[library1 objectGraphContext] itemForUUID: [[library1 objectGraphContext] rootItemUUID]] mutableCopy];
    [library1RootItem setValue: S(branchBRef) forAttribute: @"contents"];
    [[library1 objectGraphContext] insertOrUpdateItems: A(library1RootItem)];
    
    [ctx commit];
    
    UKObjectsEqual(S(@"photo1, branch B"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    UKObjectsEqual(S(A(@"childB")), [[library1 rootObject] valueForKeyPath: @"contents.contents.label"]);
    
    // Now delete branch B. This should automatically update the cross-persistent reference
    
    branchB.deleted = YES;
    
    UKObjectsEqual([NSSet set], [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    
    [ctx commit];
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
    [[photo1 rootObject] setValue: @"photo1" forProperty: @"label"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [[library1 rootObject] setValue: @"library1" forProperty: @"label"];
    [[library1 rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
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
    //  \--photo2 // inner reference to embedded object
    //
	// photo1 <<persistent root>>
    //
    // Test that undeleting photo1 restores the child relationship in library1
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[photo1 rootObject] setValue: @"photo1" forProperty: @"label"];
    [photo1 commit];
        
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    /* This creates a reference to photo1. */
    [[library1 rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    
    [ctx commit];
    
    // Delete photo1
    
    photo1.deleted = YES;
    [ctx commit];
    
    // FIXME: UKObjectsEqual([NSSet set], [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    
    // Add photo2 embedded item. Note that the photo1 cross-persistent-root reference is
    // still present in library1.contents, it's just hidden.
    
    COObject *photo2 = [library1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [photo2 setValue: @"photo2" forProperty: @"label"];
    [[library1 rootObject] insertObject: photo2 atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    
    // FIXME: UKObjectsEqual(S(@"photo2"), [[library1 rootObject] valueForKeyPath: @"contents.label"]);
    
    [ctx commit];
    
    {
        // Re-open in an independent context, to make sure we're not cheating
        
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *library1ctx2 = [ctx2 persistentRootForUUID: [library1 persistentRootUUID]];
        
        UKFalse([[library1ctx2 objectGraphContext] hasChanges]);
        // FIXME: UKObjectsEqual(S(@"photo2"), [[library1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
        
        // Undelete photo1, which should restore the cross-root relationship
        
        COPersistentRoot *photo1ctx2 = [[ctx2 deletedPersistentRoots] anyObject];
        [photo1ctx2 setDeleted: NO];
        
        UKFalse([[library1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual(S(@"photo1", @"photo2"), [[library1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
    }
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
    [[photo1 rootObject] setValue: @"photo1" forProperty: @"label"];
    [photo1 commit];
    
    // Set up library
    
    COPersistentRoot *library1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.Tag"];
    [[library1 rootObject] setValue: @"library1" forProperty: @"label"];
    [[library1 rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    [ctx commit];
    
    library1.deleted = YES;
    [ctx commit];
    
    {
        // Re-open in an independent context, to make sure we're not cheating
        
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *photo1ctx2 = [ctx2 persistentRootForUUID: [photo1 persistentRootUUID]];
        
        UKFalse([[photo1ctx2 objectGraphContext] hasChanges]);
        UKObjectsEqual([NSSet set], [[photo1ctx2 rootObject] valueForKeyPath: @"parentCollections.label"]);
        
        // Undelete library1, which should restore the cross-root inverse relationship
        
        COPersistentRoot *library1ctx2 = [[ctx2 deletedPersistentRoots] anyObject];
        [library1ctx2 setDeleted: NO];

        UKFalse([[photo1ctx2 objectGraphContext] hasChanges]);
        //FIXME: UKObjectsEqual(S(@"photo1"), [[photo1ctx2 rootObject] valueForKeyPath: @"parentCollections.label"]);
    }
}

/*
 
 List of some scenarios to test:
 
 - Performace for a library containing references to 50000 persistent roots
 - (DONE) API for adding a cross-reference to a specific branch
 - (DONE) How do we deal with possible broken relationships? Maybe need a special COBrokenLink object? => the reference will simply disappear
 - (N/A) What about relationships where the type of the destination
 is wrong? => not going to allow

 - (DONE) testBasic scenario, but photo1's persistent root is deleted
 - (N/A) testBasic scenario, but photo1's persistent root's root object is changed
 to something other than an OutlineItem.
   => We're not going to allow doing that
 
 - (DONE) Test accessing the parent of photo1 when the library persistent root is deleted
 
 
 Idea: Two views of references.
 
 1. Basic
 
 Cross-persistent root refs are indistinguishable from regular intra-persistent-root refs.
 Whether the Cross-persistent-root ref is to the default branch or an explicit branch is indistinguishable.
 Cross-persistent-root refs to a deleted persistent root are simply hidden.
 
 2. Show metadata
 
 Basically raw access to the COItem level.
 You get to see COPath objects, so you can see if it's a branch specific relationship,
 an can check if they're broken. (Maybe a wrapper on top of COPath, instead of
 raw COPath objects.)
 
 => We need to keep the COItem-level representation for relationships in memory,
 so if you delete a persistent root then restore it, the relationships in the
 Basic level reappear automatically.
 
 
 */


@end