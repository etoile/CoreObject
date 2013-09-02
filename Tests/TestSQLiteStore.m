#import "TestCommon.h"
#import "COItem.h"
#import "COSQLiteStore+Attachments.h"


/**
 * For each execution of a test method, the store is recreated and a persistent root
 * is created in -init with a single commit, with the contents returned by -makeInitialItemTree.
 */
@interface TestSQLiteStore : COSQLiteStoreTestCase <UKTest>
{
    COPersistentRootInfo *proot;
    ETUUID *prootUUID;
    int64_t prootChangeCount;
    
    ETUUID *initialBranchUUID;
    ETUUID *branchAUUID;
    ETUUID *branchBUUID;
    
    CORevisionID *initialRevisionId;
    
    NSMutableArray *branchARevisionIDs;
    NSMutableArray *branchBRevisionIDs;
}
@end

@implementation TestSQLiteStore

static ETUUID *rootUUID;
static ETUUID *childUUID1;
static ETUUID *childUUID2;

+ (void) initialize
{
    if (self == [TestSQLiteStore class])
    {
        rootUUID = [[ETUUID alloc] init];
        childUUID1 = [[ETUUID alloc] init];
        childUUID2 = [[ETUUID alloc] init];
    }
}

// --- Example data setup
// FIXME: Factor out to ExampleStore class shared by the backing store test and this and others.
// FIXME: Test another isolated persistent root with its own backing store.
#define BRANCH_LENGTH 15
#define BRANCH_EARLY 4
#define BRANCH_LATER 7

- (CORevisionID *) lateBranchA
{
    return [branchARevisionIDs objectAtIndex: BRANCH_LATER];
}

- (CORevisionID *) lateBranchB
{
    return [branchBRevisionIDs objectAtIndex: BRANCH_LATER];
}

- (CORevisionID *) earlyBranchA
{
    return [branchARevisionIDs objectAtIndex: BRANCH_EARLY];
}

- (CORevisionID *) earlyBranchB
{
    return [branchBRevisionIDs objectAtIndex: BRANCH_EARLY];
}

/*
 * The sample store will look like this
 *
 *  Fist commit
 *
 *    x ---------[ BRANCH_LENGTH commits ]  ("branch A")
 *      \
 *       \
 *        ------------[ BRANCH_LENGTH commits ] ("branch B")
 *
 */

- (COItem *) initialRootItemForChildren: (NSArray *)children
{
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: rootUUID] autorelease];
    [rootItem setValue: @"root" forAttribute: @"name" type: kCOTypeString];
    [rootItem setValue: children
          forAttribute: @"children"
                  type: kCOTypeCompositeReference | kCOTypeArray];
    return rootItem;
}

- (COItem *) initialChildItemForUUID: (ETUUID*)aUUID
                                name: (NSString *)name
{
    COMutableItem *child = [[[COMutableItem alloc] initWithUUID: aUUID] autorelease];
    [child setValue: name
       forAttribute: @"name"
               type: kCOTypeString];
    return child;
}

- (COItemGraph*) makeInitialItemTree
{
    return [COItemGraph itemGraphWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID1)],
                                                 [self initialChildItemForUUID: childUUID1 name: @"initial child"])];
}

/**
 * Index is in [0..BRANCH_LENGTH]
 */
- (COItemGraph*) makeBranchAItemTreeAtIndex: (int)index
{
    NSString *name = [NSString stringWithFormat: @"branch A commit %d", index];
    return [COItemGraph itemGraphWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID1)],
                                                       [self initialChildItemForUUID: childUUID1 name: name])];
}

/**
 * Index is in [0..BRANCH_LENGTH]
 */
- (COItemGraph*) makeBranchBItemTreeAtIndex: (int)index
{
    NSString *name = [NSString stringWithFormat: @"branch B commit %d", index];
    return [COItemGraph itemGraphWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID2)],
                                                       [self initialChildItemForUUID: childUUID2 name: name])];
}

- (COItemGraph *)itemTreeWithChildNameChange: (NSString*)aName
{
    COItemGraph *it = [self makeInitialItemTree];
    COMutableItem *item = (COMutableItem *)[it itemForUUID: childUUID1];
    [item setValue: aName
      forAttribute: @"name"];
    return it;
}

- (NSDictionary *)initialMetadata
{
    return D(@"first commit", @"name");
}

- (NSDictionary *)branchAMetadata
{
    return D(@"branch A", @"name");
}

- (NSDictionary *)branchBMetadata
{
    return D(@"branch B", @"name");
}

- (id) init
{
    SUPERINIT;
    
    branchARevisionIDs = [[NSMutableArray alloc] init];
    branchBRevisionIDs = [[NSMutableArray alloc] init];
    
    // First commit
    
    ASSIGN(proot, [store createPersistentRootWithInitialItemGraph: [self makeInitialItemTree]
                                                            UUID: [ETUUID UUID]
                                                      branchUUID: [ETUUID UUID]
                                                        revisionMetadata: [self initialMetadata]
                                                           error: NULL]);
    ASSIGN(prootUUID, [proot UUID]);
    prootChangeCount = proot.changeCount;
    
    ASSIGN(initialBranchUUID, [proot currentBranchUUID]);
    ASSIGN(initialRevisionId, [[proot currentBranchInfo] currentRevisionID]);
    
    // Branch A
    
    for (int i = 0; i < BRANCH_LENGTH; i++)
    {
        CORevisionID *revid = [store writeRevisionWithItemGraph: [self makeBranchAItemTreeAtIndex: i]
                                                       metadata: [self branchAMetadata]
                                               parentRevisionID: (i == 0) ? initialRevisionId : [branchARevisionIDs lastObject]
                                          mergeParentRevisionID: nil
                                                  modifiedItems: A(childUUID1)
                                                          error: NULL];        
        [branchARevisionIDs addObject: revid];
    }
    
    // Branch B
    
    for (int i = 0; i < BRANCH_LENGTH; i++)
    {
        CORevisionID *revid = [store writeRevisionWithItemGraph: [self makeBranchBItemTreeAtIndex: i]
                                                       metadata: [self branchBMetadata]
                                               parentRevisionID: (i == 0) ? initialRevisionId : [branchBRevisionIDs lastObject]
                                          mergeParentRevisionID: nil
                                                  modifiedItems: nil
                                                          error: NULL];
        [branchBRevisionIDs addObject: revid];
    }
    
    ASSIGN(branchAUUID, [ETUUID UUID]);
    [store createBranchWithUUID: branchAUUID
                initialRevision: initialRevisionId
              forPersistentRoot: prootUUID
                          error: NULL];
    
    assert([store setCurrentRevision: [branchARevisionIDs lastObject]
                        headRevision: [branchARevisionIDs lastObject]
                        tailRevision: initialRevisionId
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    ASSIGN(branchBUUID, [ETUUID UUID]);
    [store createBranchWithUUID: branchBUUID
                initialRevision: initialRevisionId
              forPersistentRoot: prootUUID
                          error: NULL];
    
    assert([store setCurrentRevision: [branchBRevisionIDs lastObject]
                        headRevision: [branchBRevisionIDs lastObject]
                        tailRevision: initialRevisionId
                           forBranch: branchBUUID
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    return self;
}

- (void) dealloc
{
    [proot release];
    [prootUUID release];
    [initialBranchUUID release];
    [initialRevisionId release];
    [branchAUUID release];
    [branchBUUID release];
    [branchARevisionIDs release];
    [branchBRevisionIDs release];
    [super dealloc];
}


// --- The tests themselves

- (void) testDeleteBranchA
{
    COBranchInfo *initialState = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    
    UKObjectsEqual(S(branchAUUID, branchBUUID, initialBranchUUID), [[store persistentRootInfoForUUID: prootUUID] branchUUIDs]);
    
    // Delete it
    UKTrue([store deleteBranch: branchAUUID ofPersistentRoot: prootUUID error: NULL]);
    
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKTrue([branchObj isDeleted]);
    }
    
    // Ensure we can't switch to it, since it is deleted
    UKFalse([store setCurrentBranch: branchAUUID forPersistentRoot: prootUUID error: NULL]);

    // Undelete it
    UKTrue([store undeleteBranch: branchAUUID ofPersistentRoot: prootUUID error: NULL]);
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKFalse([branchObj isDeleted]);
        UKObjectsEqual(initialState.currentRevisionID, branchObj.currentRevisionID);
    }

    // Should have no effect
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);

    // Verify the branch is still there
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKObjectsEqual(initialState.currentRevisionID, branchObj.currentRevisionID);
    }
    
    // Really delete it
    UKTrue([store deleteBranch: branchAUUID ofPersistentRoot: prootUUID error: NULL]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    UKNil([[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID]);
    UKObjectsEqual(S(branchBUUID, initialBranchUUID), [[store persistentRootInfoForUUID: prootUUID] branchUUIDs]);
}

- (void) testDeleteCurrentBranch
{
    // Delete it - should return NO because you can't delete the current branch
    UKFalse([store deleteBranch: initialBranchUUID ofPersistentRoot: prootUUID error: NULL]);

    // Should have no effect
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    // Verify the branch is still there
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: initialBranchUUID];
        UKNotNil(branchObj);
        UKFalse([branchObj isDeleted]);
    }
}

- (void) testBranchMetadata
{
    // A plain call to -createPersistentRootWithInitialItemGraph: creates a default branch
    // with nil metadata; this is intentional.
    //
    // If you want to give the branch initial metadata you can call -setMetadata:forBranch:...
    // in a transaction with the -createPersistentRootWithInitialItemGraph: call.
    UKNil([[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] metadata]);
    
    UKTrue([store setMetadata: D(@"hello world", @"msg")
                    forBranch: initialBranchUUID
             ofPersistentRoot: prootUUID
                        error: NULL]);
    
    UKObjectsEqual(D(@"hello world", @"msg"), [[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] metadata]);
    
    UKTrue([store setMetadata: nil
                    forBranch: initialBranchUUID
             ofPersistentRoot: prootUUID
                        error: NULL]);
    
    UKNil([[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] metadata]);
}

- (void) testSetCurrentBranch
{
    UKObjectsEqual(initialBranchUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);
    
    UKTrue([store setCurrentBranch: branchAUUID
              forPersistentRoot: prootUUID
                          error: NULL]);
    
    UKObjectsEqual(branchAUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);

    UKTrue([store setCurrentBranch: branchBUUID
              forPersistentRoot: prootUUID
                          error: NULL]);
    
    UKObjectsEqual(branchBUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);

}




- (void) testSetCurrentVersion
{
    COBranchInfo *branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA tailRevisionID]);
    UKObjectsEqual([branchARevisionIDs lastObject], [branchA headRevisionID]);
    UKObjectsEqual([branchARevisionIDs lastObject], [branchA currentRevisionID]);

    UKTrue([store setCurrentRevision: [self lateBranchA]
                        headRevision: [branchA headRevisionID]
                        tailRevision: [branchA tailRevisionID]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA tailRevisionID]);
    UKObjectsEqual([branchARevisionIDs lastObject], [branchA headRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA currentRevisionID]);

    UKTrue([store setCurrentRevision: [self lateBranchA]
                        headRevision: [self lateBranchA]
                        tailRevision: [branchA tailRevisionID]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA tailRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA headRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA currentRevisionID]);

    UKTrue([store setCurrentRevision: [self lateBranchA]
                        headRevision: [self lateBranchA]
                        tailRevision: [self earlyBranchA]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual([self earlyBranchA], [branchA tailRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA headRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA currentRevisionID]);
}

- (void) testSetCurrentVersionChangeCount
{
    COBranchInfo *branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA tailRevisionID]);
    UKObjectsEqual([branchARevisionIDs lastObject], [branchA headRevisionID]);
    UKObjectsEqual([branchARevisionIDs lastObject], [branchA currentRevisionID]);

    // Open another store and change the current revision
    
    int64_t store2ChangeCount = prootChangeCount;
    {
        COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: [store URL]];
        
        UKTrue([store2 setCurrentRevision: [self lateBranchA]
                             headRevision: [branchA headRevisionID]
                             tailRevision: [branchA tailRevisionID]
                                forBranch: branchAUUID
                         ofPersistentRoot: prootUUID
                       currentChangeCount: &store2ChangeCount
                                    error: NULL]);
        
        [store2 release];
    }
    
    // Try to change the revision again, pretending we didn't notice the
    // store2 change

    UKFalse([store setCurrentRevision: [self earlyBranchA]
                         headRevision: [branchA headRevisionID]
                         tailRevision: [branchA tailRevisionID]
                            forBranch: branchAUUID
                     ofPersistentRoot: prootUUID
                   currentChangeCount: &prootChangeCount
                                error: NULL]);

    // Reload our in-memory state, and the call should succeed
    
    ASSIGN(proot, [store persistentRootInfoForUUID: prootUUID]);
    prootChangeCount = proot.changeCount;
    
    UKTrue([store setCurrentRevision:  [self earlyBranchA]
                         headRevision: [branchA headRevisionID]
                         tailRevision: [branchA tailRevisionID]
                            forBranch: branchAUUID
                     ofPersistentRoot: prootUUID
                   currentChangeCount: &prootChangeCount
                                error: NULL]);
}

- (void) testCrossPersistentRootReference
{
    
}

- (void) testAttachmentsBasic
{
    NSString *fakeAttachment1 = @"this is a large attachment";
    NSString *fakeAttachment2 = @"this is another large attachment";
    NSString *path1 = [NSTemporaryDirectory() stringByAppendingPathComponent: @"coreobject-test1.txt"];
    NSString *path2 = [NSTemporaryDirectory() stringByAppendingPathComponent: @"coreobject-test2.txt"];
    
    [fakeAttachment1 writeToFile: path1
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
    
    [fakeAttachment2 writeToFile: path2
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
    
    NSData *hash1 = [store importAttachmentFromURL: [NSURL fileURLWithPath: path1]];
    NSData *hash2 = [store importAttachmentFromURL: [NSURL fileURLWithPath: path2]];
    
    UKObjectsEqual(fakeAttachment1, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash1]
                                                             encoding: NSUTF8StringEncoding
                                                                error: NULL]);
    
    UKObjectsEqual(fakeAttachment2, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash2]
                                                             encoding: NSUTF8StringEncoding
                                                                error: NULL]);
    
    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: [[store URLForAttachmentID: hash1] path]]);
    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: [[store URLForAttachmentID: hash2] path]]);
}

- (void) testAttachmentsGCDoesNotCollectReferenced
{
    NSString *fakeAttachment = @"this is a large attachment";
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent: @"cotest.txt"];
    
    UKTrue([fakeAttachment writeToFile: path
                            atomically: YES
                              encoding: NSUTF8StringEncoding
                                 error: NULL]);
    
    NSData *hash = [store importAttachmentFromURL: [NSURL fileURLWithPath: path]];
    UKNotNil(hash);
    
    NSString *internalPath = [[store URLForAttachmentID: hash] path];
    
    UKTrue([path hasPrefix: NSTemporaryDirectory()]);
    UKFalse([internalPath hasPrefix: NSTemporaryDirectory()]);
    
    NSLog(@"external path: %@", path);
    NSLog(@"internal path: %@", internalPath);
    
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash]
                                                            encoding: NSUTF8StringEncoding
                                                               error: NULL]);
    
    // Test attachment GC
    
    COItemGraph *tree = [self makeInitialItemTree];
    [[tree itemForUUID: childUUID1] setValue: hash forAttribute: @"attachment" type: kCOTypeAttachment];
    CORevisionID *withAttachment = [store writeRevisionWithItemGraph: tree
                                                            metadata: nil
                                                    parentRevisionID: initialRevisionId
                                               mergeParentRevisionID: nil
                                                       modifiedItems: nil
                                                               error: NULL];
    UKNotNil(withAttachment);
    UKTrue([store setCurrentRevision: withAttachment
                        headRevision: withAttachment
                        tailRevision: initialRevisionId
                           forBranch: initialBranchUUID
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash]
                                                            encoding: NSUTF8StringEncoding
                                                               error: NULL]);
}

- (void) testAttachmentsGCCollectsUnReferenced
{
    NSString *fakeAttachment = @"this is a large attachment";
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent: @"cotest.txt"];
    [fakeAttachment writeToFile: path
                     atomically: YES
                       encoding: NSUTF8StringEncoding
                          error: NULL];    
    NSData *hash = [store importAttachmentFromURL: [NSURL fileURLWithPath: path]];
    
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash]
                                                            encoding: NSUTF8StringEncoding
                                                               error: NULL]);

    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: [[store URLForAttachmentID: hash] path]]);
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    UKFalse([[NSFileManager defaultManager] fileExistsAtPath: [[store URLForAttachmentID: hash] path]]);
}

/**
 * See the conceptual model of the store in the COSQLiteStore comment. Revisions are not 
 * first class citizes; we garbage-collect them when they are not referenced.
 */
- (void) testRevisionGCDoesNotCollectReferenced
{
    COItemGraph *tree = [self makeInitialItemTree];
    CORevisionID *referencedRevision = [store writeRevisionWithItemGraph: tree
                                                                metadata: nil
                                                        parentRevisionID: initialRevisionId
                                                   mergeParentRevisionID: nil
                                                           modifiedItems: nil
                                                                   error: NULL];
    
    UKTrue([store setCurrentRevision: referencedRevision
                        headRevision: referencedRevision
                        tailRevision: initialRevisionId
                           forBranch: initialBranchUUID
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKObjectsEqual(tree, [store itemGraphForRevisionID: referencedRevision]);
}

- (void) testRevisionGCCollectsUnReferenced
{
    COItemGraph *tree = [self makeInitialItemTree];
    CORevisionID *unreferencedRevision = [store writeRevisionWithItemGraph: tree
                                                                  metadata: nil
                                                          parentRevisionID: initialRevisionId
                                                     mergeParentRevisionID: nil
                                                             modifiedItems: nil
                                                                     error: NULL];
    
    UKObjectsEqual(tree, [store itemGraphForRevisionID: unreferencedRevision]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKNil([store itemGraphForRevisionID: unreferencedRevision]);
    UKNil([store revisionInfoForRevisionID: unreferencedRevision]);
    
    // TODO: Expand, test using -setTail...
}

- (void) testRevisionInfo
{
    CORevisionInfo *info = [store revisionInfoForRevisionID: initialRevisionId];
    UKNil([info parentRevisionID]);
    UKObjectsEqual(initialRevisionId, [info revisionID]);
}

- (void) testDeletePersistentRoot
{
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKObjectsEqual(A(prootUUID), [store persistentRootUUIDs]);
    UKFalse([[store persistentRootInfoForUUID: prootUUID] isDeleted]);

    // Delete it
    UKTrue([store deletePersistentRoot: prootUUID error: NULL]);

    UKTrue([[store persistentRootInfoForUUID: prootUUID] isDeleted]);
    UKObjectsEqual(A(prootUUID), [store deletedPersistentRootUUIDs]);
    UKObjectsEqual([NSArray array], [store persistentRootUUIDs]);
    UKNotNil([store persistentRootInfoForUUID: prootUUID]);
    UKFalse([[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] isDeleted]); // Deleting proot does not mark branch as deleted.
    
    // Undelete it
    UKTrue([store undeletePersistentRoot: prootUUID error: NULL]);

    UKFalse([[store persistentRootInfoForUUID: prootUUID] isDeleted]);
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKObjectsEqual(A(prootUUID), [store persistentRootUUIDs]);
    
    // Delete it, and finalize the deletion
    UKTrue([store deletePersistentRoot: prootUUID error: NULL]);
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKObjectsEqual([NSArray array], [store persistentRootUUIDs]);
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKNil([store persistentRootInfoForUUID: prootUUID]);
    UKNil([store revisionInfoForRevisionID: initialRevisionId]);
    UKNil([store itemGraphForRevisionID: initialRevisionId]);
}

// FIXME: Not sure if this is worth the bother

//- (void) testAllOperationsFailOnDeletedPersistentRoot
//{
//    // Used later in test
//    COUUID *branch = [store createBranchWithInitialRevision: [[proot currentBranchState] currentState]
//                                                 setCurrent: NO
//                                          forPersistentRoot: prootUUID];
//    
//    UKTrue([store deletePersistentRoot: prootUUID]);
//    // Persistent root returned since we have not called finalizeDeletions.
//    UKObjectsEqual(A(prootUUID), [store persistentRootUUIDs]);
//    
//    // Persistent root returned since we have not called finalizeDeletions.
//    UKNotNil([store persistentRootWithUUID: prootUUID]);
//    
//    // All write operations on prootUUID should return NO.
//    
//    UKFalse([store setCurrentBranch: branch forPersistentRoot: prootUUID]);
//    UKFalse([store setCurrentVersion: [[proot currentBranchState] currentState] forBranch: branch ofPersistentRoot: prootUUID updateHead: NO]);
//    UKFalse([store setTailRevision: [[proot currentBranchState] currentState] forBranch: branch ofPersistentRoot:prootUUID]);
//    UKFalse([store deleteBranch: branch ofPersistentRoot: prootUUID]);
//    UKFalse([store undeleteBranch: branch ofPersistentRoot: prootUUID]);
//}

- (void) testPersistentRootBasic
{
    UKObjectsEqual(S(prootUUID), [NSSet setWithArray:[store persistentRootUUIDs]]);
    UKObjectsEqual(initialBranchUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);
    UKObjectsEqual([self makeInitialItemTree], [store itemGraphForRevisionID: initialRevisionId]);
    UKFalse([[store persistentRootInfoForUUID: prootUUID] isDeleted]);
}

/**
 * Tests creating a persistent root, proot, making a copy of it, and then making a commit
 * to proot and a commit to the copy.
 */
- (void)testPersistentRootCopies
{
    COPersistentRootInfo *copy = [store createPersistentRootWithInitialRevision: initialRevisionId
                                                                           UUID: [ETUUID UUID]
                                                                     branchUUID: [ETUUID UUID]
                                                                          error: NULL];
    int64_t copyChangeCount = copy.changeCount;
    
    UKObjectsEqual(S(prootUUID, [copy UUID]), [NSSet setWithArray:[store persistentRootUUIDs]]);

    // 1. check setup
    
    // Verify that the new branch metadata is nil
    UKNil([[copy currentBranchInfo] metadata]);
    
    // Verify that new UUIDs were generated
    UKObjectsNotEqual(prootUUID, [copy UUID]);
    UKObjectsNotEqual([proot branchUUIDs], [copy branchUUIDs]);
    UKIntsEqual(1,  [[copy branchUUIDs] count]);
    
    // Check that the current branch is set correctly
    UKObjectsEqual([[copy branchUUIDs] anyObject], [copy currentBranchUUID]);
    
    // Check that the branch data is the same
    UKNotNil([[proot currentBranchInfo] headRevisionID]);
    UKNotNil([[proot currentBranchInfo] tailRevisionID]);
    UKNotNil(initialRevisionId);
    UKObjectsEqual([[proot currentBranchInfo] headRevisionID], [[copy currentBranchInfo] headRevisionID]);
    UKObjectsEqual([[proot currentBranchInfo] tailRevisionID], [[copy currentBranchInfo] tailRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] currentRevisionID]);
    
    // Make sure the persistent root state returned from createPersistentRoot matches what the store
    // gives us when we read it back.

    UKObjectsEqual(copy.branchUUIDs, [store persistentRootInfoForUUID: [copy UUID]].branchUUIDs);
    UKObjectsEqual([[copy currentBranchInfo] currentRevisionID], [[store persistentRootInfoForUUID: [copy UUID]] currentBranchInfo].currentRevisionID);
    
    // 2. try changing. Verify that proot and copy are totally independent

    CORevisionID *rev1 = [self earlyBranchA];
    
    UKTrue([store setCurrentRevision: rev1
                        headRevision: rev1
                        tailRevision: initialRevisionId
                           forBranch: [[proot currentBranchInfo] UUID]
                    ofPersistentRoot: prootUUID
                  currentChangeCount: &prootChangeCount
                               error: NULL]);
    
    // Reload proot's and copy's metadata
    
    ASSIGN(proot, [store persistentRootInfoForUUID: prootUUID]);
    copy = [store persistentRootInfoForUUID: [copy UUID]];
    UKObjectsEqual(rev1, [[proot currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(rev1, [[proot currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[proot currentBranchInfo] tailRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] tailRevisionID]);
    
    // Commit to copy as well.
    
    CORevisionID *rev2 = [self lateBranchA];
    
    UKTrue([store setCurrentRevision: rev2
                        headRevision: rev2
                        tailRevision: initialRevisionId
                           forBranch: [[copy currentBranchInfo] UUID]
                    ofPersistentRoot: [copy UUID]
                  currentChangeCount: &copyChangeCount
                               error: NULL]);
    
    // Reload proot's and copy's metadata
    
    ASSIGN(proot, [store persistentRootInfoForUUID: prootUUID]);
    copy = [store persistentRootInfoForUUID: [copy UUID]];
    UKObjectsEqual(rev1, [[proot currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(rev1, [[proot currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[proot currentBranchInfo] tailRevisionID]);
    UKObjectsEqual(rev2, [[copy currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(rev2, [[copy currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] tailRevisionID]);
}

- (void) testStoreUUID
{
    ETUUID *uuid = [store UUID];
    UKNotNil(uuid);
    
    COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: [store URL]];
    UKObjectsEqual(uuid, [store2 UUID]);
    
    [store2 release];
}

// The following are some tests ported from CoreObject's TestStore.m

- (void)testPersistentRootInsertion
{
    ETUUID *cheapCopyUUID = [ETUUID UUID];
    ETUUID *cheapCopyBranchUUID = [ETUUID UUID];

    COPersistentRootInfo *cheapCopy = [store createPersistentRootWithInitialRevision: [branchARevisionIDs lastObject]
                                                                                UUID: cheapCopyUUID
                                                                          branchUUID: cheapCopyBranchUUID
                                                                               error: NULL];

    UKObjectsEqual(rootUUID, [store rootObjectUUIDForRevisionID: [proot currentRevisionID]]);
    UKObjectsEqual(rootUUID, [store rootObjectUUIDForRevisionID: [cheapCopy currentRevisionID]]);
    UKObjectsEqual(initialBranchUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);
    UKObjectsEqual(cheapCopyBranchUUID, [[store persistentRootInfoForUUID: cheapCopyUUID] currentBranchUUID]);
}

- (void)testReopenStore
{
    COSQLiteStore *store2 = [[[COSQLiteStore alloc] initWithURL: [store URL]] autorelease];
    
    CORevisionID *currentRevisionID = [[store2 persistentRootInfoForUUID: prootUUID] currentRevisionID];
    CORevisionID *branchARevisionID = [[[store2 persistentRootInfoForUUID: prootUUID]
                                        branchInfoForUUID: branchAUUID] currentRevisionID];
    CORevisionID *branchBRevisionID = [[[store2 persistentRootInfoForUUID: prootUUID]
                                        branchInfoForUUID: branchBUUID] currentRevisionID];
    
    UKObjectsEqual([self makeInitialItemTree], [store2 itemGraphForRevisionID: currentRevisionID]);
    UKTrue(COItemGraphEqualToItemGraph([self makeBranchAItemTreeAtIndex: BRANCH_LENGTH - 1], [store2 itemGraphForRevisionID: branchARevisionID]));
    UKTrue(COItemGraphEqualToItemGraph([self makeBranchBItemTreeAtIndex: BRANCH_LENGTH - 1], [store2 itemGraphForRevisionID: branchBRevisionID]));
}

- (void)testCommitWithNoChanges
{
    COItemGraph *graph = [[[COItemGraph alloc] initWithItemForUUID: [NSDictionary dictionary]
                                                      rootItemUUID: rootUUID] autorelease];
    UKNotNil(graph);
    
    // This isn't expected to work. If you want to make a commit with no changes, just pass in the same graph
    UKRaisesException([store writeRevisionWithItemGraph: graph
                                               metadata: nil
                                       parentRevisionID: initialRevisionId
                                  mergeParentRevisionID: nil
                                          modifiedItems: nil
                                                  error: NULL]);
}

- (void) testInitialRevisionMetadata
{
    UKObjectsEqual([self initialMetadata], [[store revisionInfoForRevisionID: initialRevisionId] metadata]);
}

- (void) testPersistentRootInfoForUUID
{
    UKRaisesException([store persistentRootInfoForUUID: nil]);
}

@end
