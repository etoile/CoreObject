#import "TestCommon.h"
#import "COItem.h"
#import "COSQLiteStore+Attachments.h"


/**
 * For each execution of a test method, the store is recreated and a persistent root
 * is created in -init with a single commit, with the contents returned by -makeInitialItemTree.
 */
@interface TestSQLiteStore : SQLiteStoreTestCase <UKTest>
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
#define BRANCH_LENGTH 4
#define BRANCH_EARLY 1
#define BRANCH_LATER 2

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
    COMutableItem *rootItem = [[COMutableItem alloc] initWithUUID: rootUUID];
    [rootItem setValue: @"root" forAttribute: @"name" type: kCOTypeString];
    [rootItem setValue: children
          forAttribute: @"children"
                  type: kCOTypeCompositeReference | kCOTypeArray];
    return rootItem;
}

- (COItem *) initialChildItemForUUID: (ETUUID*)aUUID
                                name: (NSString *)name
{
    COMutableItem *child = [[COMutableItem alloc] initWithUUID: aUUID];
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
    
    [store beginTransactionWithError: NULL];
    proot = [store createPersistentRootWithInitialItemGraph: [self makeInitialItemTree]
                                                            UUID: [ETUUID UUID]
                                                      branchUUID: [ETUUID UUID]
                                                        revisionMetadata: [self initialMetadata]
                                                           error: NULL];
    prootUUID =  [proot UUID];
    initialBranchUUID =  [proot currentBranchUUID];
    initialRevisionId =  [[proot currentBranchInfo] currentRevisionID];
    
    branchAUUID =  [ETUUID UUID];
    [store createBranchWithUUID: branchAUUID
                   parentBranch: nil
                initialRevision: initialRevisionId
              forPersistentRoot: prootUUID
                          error: NULL];
    
    branchBUUID =  [ETUUID UUID];
    [store createBranchWithUUID: branchBUUID
                   parentBranch: nil
                initialRevision: initialRevisionId
              forPersistentRoot: prootUUID
                          error: NULL];
	
    // Branch A
    
    for (int i = 0; i < BRANCH_LENGTH; i++)
    {
        CORevisionID *revid = [store writeRevisionWithItemGraph: [self makeBranchAItemTreeAtIndex: i]
                                                   revisionUUID: [ETUUID UUID]
                                                       metadata: [self branchAMetadata]
                                               parentRevisionID: (i == 0) ? initialRevisionId : [branchARevisionIDs lastObject]
                                          mergeParentRevisionID: nil
		                                             branchUUID: branchAUUID
                                             persistentRootUUID: prootUUID
                                                          error: NULL];
        [branchARevisionIDs addObject: revid];
    }
    
    // Branch B
    
    for (int i = 0; i < BRANCH_LENGTH; i++)
    {
        CORevisionID *revid = [store writeRevisionWithItemGraph: [self makeBranchBItemTreeAtIndex: i]
                                                   revisionUUID: [ETUUID UUID]
                                                       metadata: [self branchBMetadata]
                                               parentRevisionID: (i == 0) ? initialRevisionId : [branchBRevisionIDs lastObject]
                                          mergeParentRevisionID: nil
		                                             branchUUID: branchBUUID
                                             persistentRootUUID: prootUUID
                                                          error: NULL];
        [branchBRevisionIDs addObject: revid];
    }

    assert([store setCurrentRevision: [branchARevisionIDs lastObject]
                        initialRevision: initialRevisionId
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID
                               error: NULL]);

    assert([store setCurrentRevision: [branchBRevisionIDs lastObject]
                        initialRevision: initialRevisionId
                           forBranch: branchBUUID
                    ofPersistentRoot: prootUUID
                               error: NULL]);

    [store commitTransactionWithError: NULL];
    
    return self;
}



// --- The tests themselves

- (void) testDeleteBranchA
{
    COBranchInfo *initialState = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    
    UKObjectsEqual(S(branchAUUID, branchBUUID, initialBranchUUID), [[store persistentRootInfoForUUID: prootUUID] branchUUIDs]);
    
    // Delete it
    [store beginTransactionWithError: NULL];
    UKTrue([store deleteBranch: branchAUUID ofPersistentRoot: prootUUID error: NULL]);
    [store commitTransactionWithError: NULL];
    
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKTrue([branchObj isDeleted]);
    }
    
    // Ensure we can't switch to it, since it is deleted
//    [store beginTransactionWithError: NULL];
//    UKFalse([store setCurrentBranch: branchAUUID forPersistentRoot: prootUUID error: NULL]);
//    [store commitTransactionWithError: NULL];
    
    // Undelete it
    [store beginTransactionWithError: NULL];
    UKTrue([store undeleteBranch: branchAUUID ofPersistentRoot: prootUUID error: NULL]);
    [store commitTransactionWithError: NULL];    
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
    [store beginTransactionWithError: NULL];
    UKTrue([store deleteBranch: branchAUUID ofPersistentRoot: prootUUID error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    UKNil([[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID]);
    UKObjectsEqual(S(branchBUUID, initialBranchUUID), [[store persistentRootInfoForUUID: prootUUID] branchUUIDs]);
}

#if 0
- (void) testDeleteCurrentBranch
{
    // Delete it - should return NO because you can't delete the current branch
    [store beginTransactionWithError: NULL];
    UKFalse([store deleteBranch: initialBranchUUID ofPersistentRoot: prootUUID error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // Should have no effect
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    // Verify the branch is still there
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: initialBranchUUID];
        UKNotNil(branchObj);
        UKFalse([branchObj isDeleted]);
    }
}
#endif

- (void) testBranchMetadata
{
    // A plain call to -createPersistentRootWithInitialItemGraph: creates a default branch
    // with nil metadata; this is intentional.
    //
    // If you want to give the branch initial metadata you can call -setMetadata:forBranch:...
    // in a transaction with the -createPersistentRootWithInitialItemGraph: call.
    UKNil([[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] metadata]);
    
    [store beginTransactionWithError: NULL];
    UKTrue([store setMetadata: D(@"hello world", @"msg")
                    forBranch: initialBranchUUID
             ofPersistentRoot: prootUUID
                        error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKObjectsEqual(D(@"hello world", @"msg"), [[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] metadata]);
    
    [store beginTransactionWithError: NULL];
    UKTrue([store setMetadata: nil
                    forBranch: initialBranchUUID
             ofPersistentRoot: prootUUID
                        error: NULL]);
    [store commitTransactionWithError: NULL];
    UKNil([[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] metadata]);
}

- (void) testSetCurrentBranch
{
    UKObjectsEqual(initialBranchUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);
    
    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentBranch: branchAUUID
              forPersistentRoot: prootUUID
                          error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKObjectsEqual(branchAUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);

    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentBranch: branchBUUID
              forPersistentRoot: prootUUID
                          error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKObjectsEqual(branchBUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);

}




- (void) testSetCurrentVersion
{
    COBranchInfo *branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA initialRevisionID]);
    UKObjectsEqual([branchARevisionIDs lastObject], [branchA currentRevisionID]);

    [store beginTransactionWithError: NULL];    
    UKTrue([store setCurrentRevision: [self lateBranchA]
                        initialRevision: [branchA initialRevisionID]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID

                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
    branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA initialRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA currentRevisionID]);

    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentRevision: [self lateBranchA]
                        initialRevision: [branchA initialRevisionID]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID

                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
    branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA initialRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA currentRevisionID]);

    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentRevision: [self lateBranchA]
                        initialRevision: [self earlyBranchA]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID

                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
    branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    //UKObjectsEqual([self earlyBranchA], [branchA initialRevisionID]);
    UKObjectsEqual([self lateBranchA], [branchA currentRevisionID]);
}

- (void) testSetCurrentVersionChangeCount
{
    COBranchInfo *branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKObjectsEqual(initialRevisionId, [branchA initialRevisionID]);
    UKObjectsEqual([branchARevisionIDs lastObject], [branchA currentRevisionID]);

    // Open another store and change the current revision
    
    {
        COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: [store URL]];
        [store2 beginTransactionWithError: NULL];
        UKTrue([store2 setCurrentRevision: [self lateBranchA]
                             initialRevision: [branchA initialRevisionID]
                                forBranch: branchAUUID
                         ofPersistentRoot: prootUUID
                                    error: NULL]);
        [store2 commitTransactionWithError: NULL];
    }
    
    // Try to change the revision again, pretending we didn't notice the
    // store2 change

    // FIXME: Change count support is currently disabled. Need to
    // more carefully specify the behaviour and test it.
//    UKFalse([store setCurrentRevision: [self earlyBranchA]
//                      initialRevision: [branchA initialRevisionID]
//                            forBranch: branchAUUID
//                     ofPersistentRoot: prootUUID
// 
//                                error: NULL]);

    // Reload our in-memory state, and the call should succeed
    
    proot =  [store persistentRootInfoForUUID: prootUUID];
    
    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentRevision:  [self earlyBranchA]
                         initialRevision: [branchA initialRevisionID]
                            forBranch: branchAUUID
                     ofPersistentRoot: prootUUID
                                error: NULL]);
    [store commitTransactionWithError: NULL];
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
    
    [store beginTransactionWithError: NULL];
    CORevisionID *withAttachment = [store writeRevisionWithItemGraph: tree
                                                        revisionUUID: [ETUUID UUID]
                                                            metadata: nil
                                                    parentRevisionID: initialRevisionId
                                               mergeParentRevisionID: nil
	                                                      branchUUID: branchAUUID
                                                  persistentRootUUID: prootUUID
                                                               error: NULL];
    UKNotNil(withAttachment);
    UKTrue([store setCurrentRevision: withAttachment
                        initialRevision: initialRevisionId
                           forBranch: initialBranchUUID
                    ofPersistentRoot: prootUUID

                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
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
    [store beginTransactionWithError: NULL];
    CORevisionID *referencedRevision = [store writeRevisionWithItemGraph: tree
                                                            revisionUUID: [ETUUID UUID]
                                                                metadata: nil
                                                        parentRevisionID: initialRevisionId
                                                   mergeParentRevisionID: nil
	                                                          branchUUID: branchAUUID
                                                      persistentRootUUID: prootUUID
                                                                   error: NULL];
    
    UKTrue([store setCurrentRevision: referencedRevision
                        initialRevision: initialRevisionId
                           forBranch: initialBranchUUID
                    ofPersistentRoot: prootUUID

                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKObjectsEqual(tree, [store itemGraphForRevisionID: referencedRevision]);
}

- (void) testRevisionGCCollectsUnReferenced
{
    COItemGraph *tree = [self makeInitialItemTree];
    [store beginTransactionWithError: NULL];
    CORevisionID *unreferencedRevision = [store writeRevisionWithItemGraph: tree
                                                              revisionUUID: [ETUUID UUID]
                                                                  metadata: nil
                                                          parentRevisionID: initialRevisionId
                                                     mergeParentRevisionID: nil
	                                                            branchUUID: branchAUUID
                                                        persistentRootUUID: prootUUID
                                                                     error: NULL];
    [store commitTransactionWithError: NULL];
    UKObjectsEqual(tree, [store itemGraphForRevisionID: unreferencedRevision]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKNil([store itemGraphForRevisionID: unreferencedRevision]);
    UKNil([store revisionInfoForRevisionID: unreferencedRevision]);
    
    // TODO: Expand, test using -setInitial...
}

- (void) testRevisionInfo
{
    CORevisionInfo *info = [store revisionInfoForRevisionID: initialRevisionId];
    UKNil([info parentRevisionID]);
    UKObjectsEqual(initialRevisionId, [info revisionID]);
	UKObjectsEqual([proot currentBranchUUID], [info branchUUID]);
}

- (void) testDeletePersistentRoot
{
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKObjectsEqual(A(prootUUID), [store persistentRootUUIDs]);
    UKFalse([[store persistentRootInfoForUUID: prootUUID] isDeleted]);

    // Delete it
    [store beginTransactionWithError: NULL];
    UKTrue([store deletePersistentRoot: prootUUID error: NULL]);
    [store commitTransactionWithError: NULL];

    UKTrue([[store persistentRootInfoForUUID: prootUUID] isDeleted]);
    UKObjectsEqual(A(prootUUID), [store deletedPersistentRootUUIDs]);
    UKObjectsEqual([NSArray array], [store persistentRootUUIDs]);
    UKNotNil([store persistentRootInfoForUUID: prootUUID]);
    UKFalse([[[store persistentRootInfoForUUID: prootUUID] currentBranchInfo] isDeleted]); // Deleting proot does not mark branch as deleted.
    
    // Undelete it
    [store beginTransactionWithError: NULL];
    UKTrue([store undeletePersistentRoot: prootUUID error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKFalse([[store persistentRootInfoForUUID: prootUUID] isDeleted]);
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKObjectsEqual(A(prootUUID), [store persistentRootUUIDs]);
    
    // Delete it, and finalize the deletion
    [store beginTransactionWithError: NULL];
    UKTrue([store deletePersistentRoot: prootUUID error: NULL]);
    [store commitTransactionWithError: NULL];
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
//    UKFalse([store setInitialRevision: [[proot currentBranchState] currentState] forBranch: branch ofPersistentRoot:prootUUID]);
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
    [store beginTransactionWithError: NULL];
    COPersistentRootInfo *copy = [store createPersistentRootWithInitialRevision: initialRevisionId
                                                                           UUID: [ETUUID UUID]
                                                                     branchUUID: [ETUUID UUID]
                                                                          error: NULL];
    [store commitTransactionWithError: NULL];
    
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
    UKNotNil([[proot currentBranchInfo] initialRevisionID]);
    UKNotNil(initialRevisionId);
    UKObjectsEqual([[proot currentBranchInfo] initialRevisionID], [[copy currentBranchInfo] initialRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] currentRevisionID]);
    
    // Make sure the persistent root state returned from createPersistentRoot matches what the store
    // gives us when we read it back.

    UKObjectsEqual(copy.branchUUIDs, [store persistentRootInfoForUUID: [copy UUID]].branchUUIDs);
    UKObjectsEqual([[copy currentBranchInfo] currentRevisionID], [[store persistentRootInfoForUUID: [copy UUID]] currentBranchInfo].currentRevisionID);
    
    // 2. try changing. Verify that proot and copy are totally independent

    CORevisionID *rev1 = [self earlyBranchA];

    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentRevision: rev1
                        initialRevision: initialRevisionId
                           forBranch: [[proot currentBranchInfo] UUID]
                    ofPersistentRoot: prootUUID

                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // Reload proot's and copy's metadata
    
    proot =  [store persistentRootInfoForUUID: prootUUID];
    copy = [store persistentRootInfoForUUID: [copy UUID]];
    UKObjectsEqual(rev1, [[proot currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(initialRevisionId, [[proot currentBranchInfo] initialRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] initialRevisionID]);
    
    // Commit to copy as well.
    
    CORevisionID *rev2 = [self lateBranchA];
    
    [store beginTransactionWithError: NULL];
    UKTrue([store setCurrentRevision: rev2
                        initialRevision: initialRevisionId
                           forBranch: [[copy currentBranchInfo] UUID]
                    ofPersistentRoot: [copy UUID]
                               error: NULL]);
    [store commitTransactionWithError: NULL];
    
    // Reload proot's and copy's metadata
    
    proot =  [store persistentRootInfoForUUID: prootUUID];
    copy = [store persistentRootInfoForUUID: [copy UUID]];
    UKObjectsEqual(rev1, [[proot currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(initialRevisionId, [[proot currentBranchInfo] initialRevisionID]);
    UKObjectsEqual(rev2, [[copy currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] initialRevisionID]);
}

- (void) testStoreUUID
{
    ETUUID *uuid = [store UUID];
    UKNotNil(uuid);
    
    COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: [store URL]];
    UKObjectsEqual(uuid, [store2 UUID]);
    
}

// The following are some tests ported from CoreObject's TestStore.m

- (void)testPersistentRootInsertion
{
    ETUUID *cheapCopyUUID = [ETUUID UUID];
    ETUUID *cheapCopyBranchUUID = [ETUUID UUID];

    [store beginTransactionWithError: NULL];
    COPersistentRootInfo *cheapCopy = [store createPersistentRootWithInitialRevision: [branchARevisionIDs lastObject]
                                                                                UUID: cheapCopyUUID
                                                                          branchUUID: cheapCopyBranchUUID
                                                                               error: NULL];
    [store commitTransactionWithError: NULL];

    UKObjectsEqual(rootUUID, [store rootObjectUUIDForRevisionID: [proot currentRevisionID]]);
    UKObjectsEqual(rootUUID, [store rootObjectUUIDForRevisionID: [cheapCopy currentRevisionID]]);
    UKObjectsEqual(initialBranchUUID, [[store persistentRootInfoForUUID: prootUUID] currentBranchUUID]);
    UKObjectsEqual(cheapCopyBranchUUID, [[store persistentRootInfoForUUID: cheapCopyUUID] currentBranchUUID]);
}

- (void)testReopenStore
{
    COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: [store URL]];
    
    CORevisionID *currentRevisionID = [[store2 persistentRootInfoForUUID: prootUUID] currentRevisionID];
    CORevisionID *branchARevisionID = [[[store2 persistentRootInfoForUUID: prootUUID]
                                        branchInfoForUUID: branchAUUID] currentRevisionID];
    CORevisionID *branchBRevisionID = [[[store2 persistentRootInfoForUUID: prootUUID]
                                        branchInfoForUUID: branchBUUID] currentRevisionID];
    
    UKObjectsEqual([self makeInitialItemTree], [store2 itemGraphForRevisionID: currentRevisionID]);
    UKTrue(COItemGraphEqualToItemGraph([self makeBranchAItemTreeAtIndex: BRANCH_LENGTH - 1], [store2 itemGraphForRevisionID: branchARevisionID]));
    UKTrue(COItemGraphEqualToItemGraph([self makeBranchBItemTreeAtIndex: BRANCH_LENGTH - 1], [store2 itemGraphForRevisionID: branchBRevisionID]));
}

- (void)testEmptyCommitWithNoChanges
{
    COItemGraph *graph = [[COItemGraph alloc] initWithItemForUUID: [NSDictionary dictionary]
                                                      rootItemUUID: rootUUID];
    UKNotNil(graph);


    [store beginTransactionWithError: NULL];
    CORevisionID *revid = [store writeRevisionWithItemGraph: graph
                                                 revisionUUID: [ETUUID UUID]
                                                     metadata: nil
                                             parentRevisionID: initialRevisionId
                                        mergeParentRevisionID: nil
                                                   branchUUID: branchAUUID
                                           persistentRootUUID: prootUUID
                                                        error: NULL];
    [store commitTransactionWithError: NULL];
    
    // This could be useful for committing markers/tags. The very first
    // ObjectMerging prototype used this approach for marking points when the
    // user pressed cmd+S
    
    UKObjectsEqual([self makeInitialItemTree], [store itemGraphForRevisionID: revid]);
}

- (void) testInitialRevisionMetadata
{
    UKObjectsEqual([self initialMetadata], [[store revisionInfoForRevisionID: initialRevisionId] metadata]);
}

- (void) testPersistentRootInfoForUUID
{
    UKNil([store persistentRootInfoForUUID: nil]);
}

- (void) testDuplicateBranchesDisallowed
{
    [store beginTransactionWithError: NULL];
    COPersistentRootInfo *otherPersistentRoot = [store createPersistentRootWithInitialItemGraph: [self makeInitialItemTree]
                                                                                           UUID: [ETUUID UUID]
                                                                                     branchUUID: [ETUUID UUID]
                                                                               revisionMetadata: nil
                                                                                          error: NULL];
    BOOL commandOK = [store createBranchWithUUID: branchBUUID
                                    parentBranch: nil
                                 initialRevision: [otherPersistentRoot currentRevisionID]
                               forPersistentRoot: [otherPersistentRoot UUID]
                                           error: NULL];
    
    BOOL commitOK = [store commitTransactionWithError: NULL];
    
    UKFalse(commandOK && commitOK);
}

@end
