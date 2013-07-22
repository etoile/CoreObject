#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestCrossPersistentRootReferences : TestCommon <UKTest>
@end

/**
 * None of these are expected to pass yet.
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
    [[photo1 rootObject] setValue: @"photo1" forKey: @"label"];
    
    COPersistentRoot *photo2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[photo2 rootObject] setValue: @"photo2" forKey: @"label"];
    
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

    [[photo1 rootObject] setValue: @"photo1" forKey: @"label"];
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

/*
 - Verify that for references to the current branch, the COObject is transparently
 updated when the current branch switches
 - Test scenario where you have references to:
 * the current branch of photo1
 * branch A of photo1
 and when you change the main branch of photo1, the fist object changes to the
 root object for branch B, but the second stays on branch A.
 
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
    [photo1root setValue: @"photo1, branch A" forKey: @"label"];
    
    COObject *childA = [photo1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childA setValue: @"childA" forKey: @"label"];
    
    [photo1root insertObject: childA atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    // N.B. If we wanted to create a second branch in memory and also write some contents into that branch,
    // the two branches will not have a common parent.
    //
    // COSQLiteStore doesn't permit that. So we'll have to commit the first branch, and create the
    // second branch. This is probably a sensible restriction.
    //
    // Actually ignore that, we can do it all in memory, just calling -createBranch will create
    // a branch off of the first commit.
    //
    // ..But for simplicity, I won't allow branching from uncommitted branches.\
    
    [photo1 commit];
    
    COBranch *branchB = [[photo1 currentBranch] makeBranchWithLabel: @"branchB"];
    COObject *photo1branchBroot = [[branchB objectGraph] rootObject];

    [photo1branchBroot setValue: @"photo1, branch B" forKey: @"label"];
    
    COObject *childB = [branchB insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childA setValue: @"childB" forKey: @"label"];
    
    [photo1branchBroot insertObject: childA atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    [ctx commit];
}


/*
 
 List of some scenarios to test:
 
 - Performace for a library containing references to 50000 persistent roots
 - API for adding a cross-reference to a specific branch
 - How do we deal with possible broken relationships? Maybe need a special
 COBrokenLink object? What about relationships where the type of the destination
 is wrong?
 
 Cases:
 - testBasic scenario, but photo1's persistent root is deleted
 - testBasic scenario, but photo1's persistent root's root object is changed
 to something other than an OutlineItem.
 
 Should the contents property of the library still return it, even though
 the type is wrong, or should it return a COBrokenLink?
 
 Same quiestion for the parent of photo1.
 
 
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

#endif

@end