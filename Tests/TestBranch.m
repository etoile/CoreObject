#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COBranch.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COPersistentRoot.h"

@interface TestBranch : TestCommon <UKTest>
{
    COPersistentRoot *persistentRoot;
    COContainer *rootObj;
    COBranch *originalBranch;
}
@end

@implementation TestBranch

- (id) init
{
    SUPERINIT;
    ASSIGN(persistentRoot, [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"]);
    ASSIGN(rootObj, [persistentRoot rootObject]);
    ASSIGN(originalBranch, [persistentRoot currentBranch]);
    return self;
}

- (void) dealloc
{
    DESTROY(rootObj);
    DESTROY(originalBranch);
    DESTROY(persistentRoot);
    [super dealloc];
}

- (void)testNoExistingCommitTrack
{
	[rootObj setValue: @"Groceries" forProperty: @"label"];
	
	UKNotNil(originalBranch);
	UKNil([originalBranch currentRevision]);

	[ctx commit];

	UKNotNil([originalBranch currentRevision]);
	UKObjectsEqual([originalBranch currentRevision], [rootObj revision]);
}

- (void)testSimpleRootObjectPropertyUndoRedo
{
	[rootObj setValue: @"Groceries" forProperty: @"label"];
	[ctx commit];
	
	CORevision *firstRevision = [originalBranch currentRevision];
	UKNotNil(originalBranch);
	UKNotNil(firstRevision);
	UKNil([firstRevision parentRevision]);

	[rootObj setValue: @"Shopping List" forProperty: @"label"];
	[ctx commit];
	CORevision *secondRevision = [originalBranch currentRevision];

    UKNotNil(secondRevision);
	UKObjectsNotEqual(firstRevision, secondRevision);

	[rootObj setValue: @"Todo" forProperty: @"label"];
	[ctx commit];
	CORevision *thirdRevision = [originalBranch currentRevision];
    
    UKNotNil(thirdRevision);
	UKObjectsNotEqual(thirdRevision, secondRevision);

	// First undo (Todo -> Shopping List)
	[originalBranch undo]; //[originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"Shopping List", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, [originalBranch currentRevision]);

	// Second undo (Shopping List -> Groceries)
	[originalBranch undo]; //[originalBranch setCurrentRevision: firstRevision];
	UKStringsEqual(@"Groceries", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(firstRevision, [originalBranch currentRevision]);

    // Verify that the revert to firstRevision is not committed
    UKObjectsEqual([thirdRevision revisionID],
                   [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] currentBranchInfo] currentRevisionID]);
    
	// First redo (Groceries -> Shopping List)
	[originalBranch redo]; //[originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"Shopping List", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, [originalBranch currentRevision]);

    // Second redo (Shopping List -> Todo)
	[originalBranch redo]; //[originalBranch setCurrentRevision: thirdRevision];
	UKStringsEqual(@"Todo", [rootObj valueForProperty: @"label"]);
	UKObjectsEqual(thirdRevision, [originalBranch currentRevision]);
}

/**
 * Test a root object with sub-object's connected as properties.
 */
- (void)testWithObjectPropertiesUndoRedo
{
	[rootObj setValue: @"Document" forProperty: @"label"];
	[ctx commit];
    CORevision *firstRevision = [originalBranch currentRevision];
    UKNotNil(firstRevision);
    
	COContainer *para1 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[rootObj addObject: para1];
	[rootObj addObject: para2];
	[ctx commit];
    CORevision *secondRevision = [originalBranch currentRevision];    
    UKNotNil(secondRevision);
    
	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];
	[ctx commit];
    CORevision *thirdRevision = [originalBranch currentRevision];
    UKNotNil(thirdRevision);
    
    // Undo
    [originalBranch undo]; //[originalBranch setCurrentRevision: secondRevision];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	
    // Redo
    [originalBranch redo]; //[originalBranch setCurrentRevision: thirdRevision];
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);
}

- (void)testDivergentCommitTrack
{
	[rootObj setValue: @"Document" forProperty: @"label"];
	[ctx commit]; // Revision 1
    CORevision *firstRevision = [originalBranch currentRevision];
    UKNotNil(firstRevision);

	COContainer *para1 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[rootObj addObject: para1];
	[rootObj addObject: para2];
	UKIntsEqual(2, [rootObj count]);
	[ctx commit]; // Revision 2 (base 1)

    CORevision *secondRevision = [originalBranch currentRevision];    
    UKNotNil(secondRevision);
    
    // Undo
    [originalBranch undo]; //[originalBranch setCurrentRevision: firstRevision];
	UKIntsEqual(0, [rootObj count]);

	COContainer *para3 = [[originalBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para3 setValue: @"paragraph 3" forProperty: @"label"];
	[rootObj addObject: para3];
	[ctx commit];
    CORevision *divergentRevision = [originalBranch currentRevision];
    UKNotNil(divergentRevision);
    
	UKIntsEqual(1, [rootObj count]); // Revision 3 (base 1)

    // Undo
    [originalBranch undo]; //[originalBranch setCurrentRevision: firstRevision];
	UKIntsEqual(0, [rootObj count]);

    
    // Redo
    [originalBranch redo]; //[originalBranch setCurrentRevision: divergentRevision];
	UKIntsEqual(1, [rootObj count]);
	UKStringsEqual(@"paragraph 3", [[[rootObj contentArray] objectAtIndex: 0] valueForProperty: @"label"]);
}

- (void)testBranchCreation
{
    [persistentRoot commit];
    
	CORevision *rev1 = [[persistentRoot currentBranch] currentRevision];

	COBranch *branch = [originalBranch makeBranchWithLabel: @"Sandbox"];
	UKNotNil(branch);
	UKObjectsNotEqual([branch UUID], [originalBranch UUID]);
    
    /* Verify that the branch creation is not committed yet. */
    UKIntsEqual(1, [[[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] branchForUUID] allKeys] count]);
    
    [persistentRoot commit];

    UKIntsEqual(2, [[[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] branchForUUID] allKeys] count]);
	UKStringsEqual(@"Sandbox", [branch label]);
    
	//UKObjectsEqual(commitTrack, [branch parentTrack]);
	UKObjectsEqual([rootObj persistentRoot], [branch persistentRoot]);
	//UKTrue([rev1 isEqual: [rev2 baseRevision]]);
	
	UKObjectsEqual(rev1, [originalBranch currentRevision]);
	UKObjectsEqual(rev1, [branch currentRevision]);
	//UKObjectsEqual(rev1, [branch parentRevision]);

	/* Branch creation doesn't touch the current persistent root revision */
	UKObjectsEqual([rootObj revision], rev1);

	/* Branch creation doesn't switch the branch */
	UKObjectsSame(originalBranch, [[rootObj persistentRoot] currentBranch]);
}

- (void)testBranchSwitch
{
	[rootObj setValue: @"Untitled" forProperty: @"label"];
	[persistentRoot commit];
    
	//CORevision *rev1 = [[persistentRoot currentBranch] currentRevision];
	
	COBranch *branch = [originalBranch makeBranchWithLabel: @"Sandbox"];
    
	/* Switch to the Sandbox branch */

	[persistentRoot setCurrentBranch: branch];

    UKObjectsEqual([originalBranch UUID],
                   [[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] currentBranchUUID]);    
    
	/* Commit some changes in the Sandbox branch */
	
    COObject *sandboxRootObj = [[branch objectGraphContext] rootObject];
    
	[sandboxRootObj setValue: @"Todo" forProperty: @"label"];

    UKObjectsEqual(@"Todo", [[persistentRoot rootObject] valueForProperty: @"label"]);
    
	[persistentRoot commit];

    UKObjectsEqual([branch UUID],
                   [[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] currentBranchUUID]);
    
	[sandboxRootObj setValue: @"Tidi" forProperty: @"label"];
	
    [persistentRoot commit];
    
	//CORevision *rev3 = [branch currentRevision];
    
    UKObjectsEqual(@"Tidi", [[persistentRoot rootObject] valueForProperty: @"label"]);
	
	/* Switch back to the main branch */
	
	[persistentRoot setCurrentBranch: originalBranch];
    
    UKObjectsEqual(@"Untitled", [[persistentRoot rootObject] valueForProperty: @"label"]);
}

- (void) testBranchSwitchCommitted
{
	// photo1 <<persistent root, branchA>>
	//  |
	//  \--childA
	//
	// photo1 <<persistent root, branchB>>
	//  |
	//  \--childB
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COObject *photo1root = [photo1 rootObject];
    
    COObject *childA = [photo1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childA setValue: @"childA" forKey: @"label"];
    [photo1root insertObject: childA atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    [photo1 commit];
    
    COBranch *branchB = [[photo1 currentBranch] makeBranchWithLabel: @"branchB"];
    COObject *photo1branchBroot = [[branchB objectGraphContext] rootObject];
    
    COObject *childB = [[photo1branchBroot valueForKey: @"contents"] firstObject];
    [childB setValue: @"childB" forProperty: @"label"];
    UKTrue([[branchB objectGraphContext] hasChanges]);
    
    [ctx commit];
    
    UKObjectsEqual(A(@"childA"), [[photo1 rootObject] valueForKeyPath: @"contents.label"]);
    [photo1 setCurrentBranch: branchB];
    
    UKObjectsEqual(A(@"childB"), [[photo1 rootObject] valueForKeyPath: @"contents.label"]);
    [ctx commit];
    
    {
        // Test that the cross-persistent reference uses branchB when we reopen the store
        
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *photo1ctx2 = [ctx2 persistentRootForUUID: [photo1 persistentRootUUID]];
        
        // Sanity check
        
        UKObjectsEqual([branchB UUID], [[photo1ctx2 currentBranch] UUID]);
        UKObjectsEqual(A(@"childB"), [[photo1ctx2 rootObject] valueForKeyPath: @"contents.label"]);
    }
}

- (void)testBranchFromBranch
{
	UKNil([originalBranch currentRevision]);

	/* Commit some initial changes in the main branch */
	
	[rootObj setValue: @"Red" forProperty: @"label"];
	
    [persistentRoot commit];
    CORevision *rev1 = [originalBranch currentRevision];
	UKNotNil(rev1);
    
	[rootObj setValue: @"Blue" forProperty: @"label"];
	
    [persistentRoot commit];
	CORevision *rev2 = [originalBranch currentRevision];

	//UKObjectsEqual(A(rev1, rev2), [[[initialTrack loadedNodes] mappedCollection] revision]);

	/* Create branch 1 */
	
	COBranch *branch1 = [originalBranch makeBranchWithLabel: @"Branch 1"];
	CORevision *rev3 = [branch1 currentRevision];

    UKObjectsEqual(rev2, rev3);
    
	//UKObjectsEqual(A(rev1, rev2), [[[branch1 loadedNodes] mappedCollection] revision]);

	/* Switch to branch 1 */
	
	[persistentRoot setCurrentBranch: branch1];
	
	/* Commit some  changes in branch 1 */
	
	[[persistentRoot rootObject] setValue: @"Todo" forProperty: @"label"];
	
	[persistentRoot commit];
    CORevision *rev5 = [persistentRoot revision];
    
	[[persistentRoot rootObject] setValue: @"Tidi" forProperty: @"label"];
	
	[persistentRoot commit];
    CORevision *rev6 = [persistentRoot revision];

	//UKObjectsEqual(A(rev1, rev2, rev5, rev6), [[[branch1 loadedNodes] mappedCollection] revision]);
	
	/* Create branch2 */
	
	COBranch *branch2 = [branch1 makeBranchWithLabel: @"Branch 2" atRevision: rev5];
	CORevision *rev7 = [branch2 currentRevision];
	UKNotNil(rev7);
    
	/* Switch to branch 2 */
	
	[persistentRoot setCurrentBranch: branch2]; //rev8 (not yet the case)
	
    [persistentRoot commit];
    
	UKObjectsEqual([rev2 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]]
                                            branchInfoForUUID: [originalBranch UUID]] currentRevisionID]);
	UKObjectsEqual([rev6 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]]
                                         branchInfoForUUID: [branch1 UUID]] currentRevisionID]);
	UKObjectsEqual([rev5 revisionID], [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]]
                                         branchInfoForUUID: [branch2 UUID]] currentRevisionID]);
	
//	NSArray *parentTrackUUIDs = A([initialTrack UUID], [branch1 UUID]);
//	
//	UKObjectsEqual(parentTrackUUIDs, [store parentTrackUUIDsForCommitTrackUUID: [branch2 UUID]]);
//	UKObjectsEqual(A(rev1, rev2, rev5), [[[branch2 loadedNodes] mappedCollection] revision]);
//	
//	[object setValue: @"Boum" forProperty: @"label"];
//	
//	CORevision *rev9 = [[object persistentRoot] commit];
//	
//	[object setValue: @"Bam" forProperty: @"label"];
//	
//	CORevision *rev10 = [[object persistentRoot] commit];
//	
//	UKObjectsEqual(A(rev1, rev2, rev5, rev9, rev10), [[[branch2 loadedNodes] mappedCollection] revision]);
//	UKObjectsEqual(A(rev3, rev7), [self revisionsForStoreTrack]);
}

- (void)testCheapCopyCreation
{
    [rootObj setValue: @"Untitled" forProperty: @"label"];
    
    [persistentRoot commit];
    
	CORevision *rev1 = [originalBranch currentRevision];
    COPersistentRoot *copyRoot = [originalBranch makeCopyFromRevision: rev1];
    
	COBranch *copyRootBranch = [copyRoot currentBranch];
    
    UKNil([store persistentRootInfoForUUID: [copyRoot persistentRootUUID]]);
    
    [ctx commit];
    
    UKNotNil([store persistentRootInfoForUUID: [copyRoot persistentRootUUID]]);
    
    UKObjectsNotEqual([copyRootBranch UUID], [originalBranch UUID]);
    UKObjectsNotEqual([copyRoot persistentRootUUID], [persistentRoot persistentRootUUID]);
    
    UKObjectsEqual(rev1, [copyRootBranch parentRevision]);
    UKObjectsEqual(rev1, [copyRootBranch currentRevision]);
    UKObjectsEqual(rev1, [originalBranch currentRevision]);

    /* Make a commit in the cheap copy */
    
   	[[copyRoot rootObject] setValue: @"Todo" forProperty: @"label"];

    [ctx commit];
    
    // FIXME: Not yet supported by COBranch:
    //UKObjectsEqual(commitTrack, [branch parentTrack]);
	
	/* Cheap copy creation doesn't touch the current persistent root revision */
	UKObjectsEqual([[persistentRoot rootObject] revision], rev1);

    /* Cheap copy creation doesn't switch the branch */
    UKObjectsSame(originalBranch, [persistentRoot currentBranch]);
}

- (void)testDeleteUncommittedPersistentRoot
{
    ETUUID *uuid = [[[persistentRoot persistentRootUUID] retain] autorelease];
    
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
    UKFalse([persistentRoot isDeleted]);
    
    [ctx deletePersistentRoot: persistentRoot];
    
    UKFalse([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKNil([ctx persistentRootForUUID: uuid]);
    UKNil([store persistentRootInfoForUUID: uuid]);
}

- (void)testDeleteCommittedPersistentRoot
{
    ETUUID *uuid = [[[persistentRoot persistentRootUUID] retain] autorelease];
    
    [ctx commit];
    
    UKFalse([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKFalse([persistentRoot isDeleted]);
    
    [ctx deletePersistentRoot: persistentRoot];

    UKTrue([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKTrue([persistentRoot isDeleted]);
    
    [ctx commit];
  
    UKFalse([ctx hasChanges]);
    UKObjectsEqual([NSSet set], [ctx persistentRoots]);
    /* N.B.: -deletedPersistentRoots returns the pending deletions, which is why it's empty here  */
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKIntsEqual(1, [[ctx deletedPersistentRoots] count]);
    /* You can still retrieve a deleted persistent root, until the deletion is finalized */
    UKNotNil([ctx persistentRootForUUID: uuid]);
    UKNotNil([store persistentRootInfoForUUID: uuid]);
    UKTrue([persistentRoot isDeleted]);
}

- (void)testUndeleteCommittedPersistentRoot
{
    ETUUID *uuid = [[[persistentRoot persistentRootUUID] retain] autorelease];    
    [ctx commit];
    
    [ctx deletePersistentRoot: persistentRoot];
    [ctx commit];
    
    [persistentRoot setDeleted: NO];

    UKTrue([[store persistentRootInfoForUUID: uuid] isDeleted]);
    UKTrue([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRootsPendingUndeletion]);
    UKObjectsEqual(S(persistentRoot), [ctx deletedPersistentRoots]);
    UKFalse([persistentRoot isDeleted]);
    
    [ctx commit];
    
    UKFalse([[store persistentRootInfoForUUID: uuid] isDeleted]);
    UKFalse([ctx hasChanges]);
    UKObjectsEqual(S(persistentRoot), [ctx persistentRoots]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingDeletion]);
    UKObjectsEqual([NSSet set], [ctx persistentRootsPendingUndeletion]);
    UKObjectsEqual([NSSet set], [ctx deletedPersistentRoots]);
    UKFalse([persistentRoot isDeleted]);
}

- (void) testDeleteUncommittedBranch
{
    [ctx commit];
    
    COBranch *branch = [originalBranch makeBranchWithLabel: @"branch"];
    
    UKObjectsEqual(S(branch, originalBranch), [persistentRoot branches]);
    
    [persistentRoot deleteBranch: branch];
    
    UKObjectsEqual(S(originalBranch), [persistentRoot branches]);
    
    [ctx commit];
    
    UKObjectsEqual(A([originalBranch UUID]), [[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] branchForUUID] allKeys]);
}

- (void) testDeleteCommittedBranch
{
    [ctx commit];
    
    COBranch *branch = [originalBranch makeBranchWithLabel: @"branch"];
    
    UKObjectsEqual(S(branch, originalBranch), [persistentRoot branches]);

    [ctx commit];
    
    UKObjectsEqual(S([originalBranch UUID], [branch UUID]),
                   SA([[[store persistentRootInfoForUUID: [persistentRoot persistentRootUUID]] branchForUUID] allKeys]));
    
    [persistentRoot deleteBranch: branch];
    
    UKObjectsEqual(S(originalBranch), [persistentRoot branches]);
    UKObjectsEqual(S(branch), [persistentRoot deletedBranches]);
    UKTrue([branch isDeleted]);
    
    [ctx commit];
    
}

- (void) testBranchObjectGraphs
{
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [photo1 commit];
    
    COBranch *branchA = [photo1 currentBranch];
    COBranch *branchB = [branchA makeBranchWithLabel: @"branchB"];
    
    UKObjectsNotSame([branchA objectGraphContext], [branchB objectGraphContext]);
    UKObjectsNotSame([[branchA objectGraphContext] rootObject], [[branchB objectGraphContext] rootObject]);
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKFalse([[branchB objectGraphContext] hasChanges]);
    
    COObject *branchBroot = [[branchB objectGraphContext] rootObject];
    [branchBroot setValue: @"photo1, branch B" forProperty: @"label"];
    
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKTrue([[branchB objectGraphContext] hasChanges]);
    UKObjectsEqual(S([branchBroot UUID]), SA([[branchA objectGraphContext] itemUUIDs]));
    UKObjectsEqual(S([branchBroot UUID]), SA([[branchB objectGraphContext] itemUUIDs]));
    
    COObject *childB = [[branchB objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [childB setValue: @"childB" forProperty: @"label"];
    
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKTrue([[branchB objectGraphContext] hasChanges]);
    UKObjectsEqual(S([branchBroot UUID]),                SA([[branchA objectGraphContext] itemUUIDs]));
    UKObjectsEqual(S([branchBroot UUID], [childB UUID]), SA([[branchB objectGraphContext] itemUUIDs]));
    
    [branchBroot insertObject: childB atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];

    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKTrue([[branchB objectGraphContext] hasChanges]);
    UKObjectsEqual(S([branchBroot UUID]),                SA([[branchA objectGraphContext] itemUUIDs]));
    UKObjectsEqual(S([branchBroot UUID], [childB UUID]), SA([[branchB objectGraphContext] itemUUIDs]));
    
    [ctx commit];
    
    UKFalse([[branchA objectGraphContext] hasChanges]);
    UKFalse([[branchB objectGraphContext] hasChanges]);
}

- (void) testBranchLabel
{
    [ctx commit];
    
    UKNil([originalBranch label]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setLabel: @"Hello world"];
    
    UKObjectsEqual(@"Hello world", [originalBranch label]);
    UKTrue([ctx hasChanges]);
    UKTrue([persistentRoot hasChanges]);
    UKTrue([originalBranch hasChanges]);
    
    [originalBranch discardAllChanges];
    
    UKNil([originalBranch label]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setLabel: @"Hello world"];
        
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKNil([[[ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]] currentBranch] label]);
    }
    
    [ctx commit];
    
    UKObjectsEqual(@"Hello world", [originalBranch label]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKObjectsEqual(@"Hello world", [[[ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]] currentBranch] label]);
    }
    
    [originalBranch setLabel: @"Hello world 2"];
    UKObjectsEqual(@"Hello world 2", [originalBranch label]);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual(@"Hello world", [originalBranch label]);
}

- (void) testBranchMetadata
{
    [ctx commit];

    UKObjectsEqual([NSDictionary dictionary], [originalBranch metadata]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setMetadata: D(@"value", @"key")];
    
    UKObjectsEqual(D(@"value", @"key"), [originalBranch metadata]);
    UKFalse([[originalBranch metadata] isKindOfClass: [NSMutableDictionary class]]);
    UKTrue([ctx hasChanges]);
    UKTrue([persistentRoot hasChanges]);
    UKTrue([originalBranch hasChanges]);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual([NSDictionary dictionary], [originalBranch metadata]);
    UKFalse([originalBranch hasChanges]);
    
    [originalBranch setMetadata: D(@"value", @"key")];
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKObjectsEqual([NSDictionary dictionary], [[[ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]] currentBranch] metadata]);
    }
    
    [ctx commit];
    
    UKObjectsEqual(D(@"value", @"key"), [originalBranch metadata]);
    UKFalse([ctx hasChanges]);
    UKFalse([persistentRoot hasChanges]);
    UKFalse([originalBranch hasChanges]);
    
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        UKObjectsEqual(D(@"value", @"key"), [[[ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]] currentBranch] metadata]);
    }
    
    [originalBranch setMetadata: D(@"value2", @"key")];
    UKObjectsEqual(D(@"value2", @"key"), [originalBranch metadata]);
    
    [originalBranch discardAllChanges];
    
    UKObjectsEqual(D(@"value", @"key"), [originalBranch metadata]);
}

@end
