#import "TestCommon.h"
#import "COItem.h"


/**
 * For each execution of a test method, the store is recreated and a persistent root
 * is created in -init with a single commit, with the contents returned by -makeInitialItemTree.
 */
@interface TestSQLiteStore : COSQLiteStoreTestCase <UKTest>
{
    COPersistentRootInfo *proot;
    ETUUID *prootUUID;
    
    ETUUID *initialBranchUUID;
    ETUUID *branchAUUID;
    ETUUID *branchBUUID;
    CORevisionID *initialRevisionId;
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
/*
 * The sample store will look like this
 *
 *  Fist commit
 *
 *    revid 0---------[ revid 1 through BRANCH_LENGTH ]  ("branch A")
 *           \
 *            \
 *             ------------[ revid (BRANCH_LENGTH + 1) through (2 * BRANCH_LENGTH) ] ("branch B")
 *
 * revid 0 through BRANCH_LENGTH will contain rootUUID and childUUID1.
 * revid (BRANCH_LENGTH + 1) through (2 * BRANCH_LENGTH) will contain rootUUID and childUUID2.
 */

- (COItem *) initialRootItemForChildren: (NSArray *)children
{
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: rootUUID] autorelease];
    [rootItem setValue: @"root" forAttribute: @"name" type: kCOStringType];
    [rootItem setValue: children
          forAttribute: @"children"
                  type: kCOCompositeReferenceType | kCOArrayType];
    return rootItem;
}

- (COItem *) initialChildItemForUUID: (ETUUID*)aUUID
                                name: (NSString *)name
{
    COMutableItem *child = [[[COMutableItem alloc] initWithUUID: aUUID] autorelease];
    [child setValue: name
       forAttribute: @"name"
               type: kCOStringType];
    return child;
}

- (COItemGraph*) makeInitialItemTree
{
    return [COItemGraph treeWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID1)],
                                                 [self initialChildItemForUUID: childUUID1 name: @"initial child"])];
}

- (COItemGraph*) makeBranchAItemTreeAtRevid: (int64_t)aRev
{
    NSString *name = [NSString stringWithFormat: @"child for commit %lld", (long long int)aRev];
    return [COItemGraph treeWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID1)],
                                                 [self initialChildItemForUUID: childUUID1 name: name])];
}

- (COItemGraph*) makeBranchBItemTreeAtRevid: (int64_t)aRev
{
    NSString *name = [NSString stringWithFormat: @"child for commit %lld", (long long int)aRev];
    return [COItemGraph treeWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID2)],
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
    
    // First commit
    
    ASSIGN(proot, [store createPersistentRootWithInitialContents: [self makeInitialItemTree]
                                                        metadata: [self initialMetadata]]);    
    ASSIGN(prootUUID, [proot UUID]);
    
    // Branch A
    
    for (int64_t i = 1; i<=BRANCH_LENGTH; i++)
    {
        [store writeContents: [self makeBranchAItemTreeAtRevid: i]
                withMetadata: [self branchAMetadata]
        parentRevisionID: [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: i - 1]
               modifiedItems: A(childUUID1)];
    }
    
    // Branch B
    
    [store writeContents: [self makeBranchBItemTreeAtRevid: BRANCH_LENGTH + 1]    
            withMetadata: [self branchBMetadata]
    parentRevisionID: [[proot currentBranchInfo] currentRevisionID]
           modifiedItems: A(rootUUID, childUUID2)];
    
    for (int64_t i = (BRANCH_LENGTH + 2); i <= (2 * BRANCH_LENGTH); i++)
    {
        [store writeContents: [self makeBranchBItemTreeAtRevid: i]
                withMetadata: [self branchBMetadata]
        parentRevisionID: [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: i]
               modifiedItems: A(childUUID2)];
    }


    ASSIGN(initialBranchUUID, [proot currentBranchUUID]);
    ASSIGN(initialRevisionId, [[proot currentBranchInfo] currentRevisionID]);
    
    ASSIGN(branchAUUID, [store createBranchWithInitialRevision: initialRevisionId
                                                    setCurrent: NO
                                             forPersistentRoot: prootUUID]);
    assert([store setCurrentRevision: [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: BRANCH_LENGTH]
                        headRevision: [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: BRANCH_LENGTH]
                        tailRevision: initialRevisionId
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID]);
    
    ASSIGN(branchBUUID, [store createBranchWithInitialRevision: initialRevisionId
                                                    setCurrent: NO
                                             forPersistentRoot: prootUUID]);
    
    assert([store setCurrentRevision: [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: 2 * BRANCH_LENGTH]
                        headRevision: [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: 2 * BRANCH_LENGTH]
                        tailRevision: initialRevisionId
                           forBranch: branchBUUID
                    ofPersistentRoot: prootUUID]);
    
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
    [super dealloc];
}


// --- The tests themselves

- (void) testDeleteBranchA
{
    COBranchInfo *initialState = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
    
    UKObjectsEqual(S(branchAUUID, branchBUUID, initialBranchUUID), [[store persistentRootWithUUID: prootUUID] branchUUIDs]);
    
    // Delete it
    UKTrue([store deleteBranch: branchAUUID ofPersistentRoot: prootUUID]);
    
    {
        COBranchInfo *branchObj = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKTrue([branchObj isDeleted]);
    }
    
    // Ensure we can't switch to it, since it is deleted
    UKFalse([store setCurrentBranch: branchAUUID forPersistentRoot: prootUUID]);

    // Undelete it
    UKTrue([store undeleteBranch: branchAUUID ofPersistentRoot: prootUUID]);
    {
        COBranchInfo *branchObj = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKFalse([branchObj isDeleted]);
        UKObjectsEqual(initialState.currentRevisionID, branchObj.currentRevisionID);
    }

    // Should have no effect
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);

    // Verify the branch is still there
    {
        COBranchInfo *branchObj = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKObjectsEqual(initialState.currentRevisionID, branchObj.currentRevisionID);
    }
    
    // Really delete it
    UKTrue([store deleteBranch: branchAUUID ofPersistentRoot: prootUUID]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);
    UKNil([[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID]);
    UKObjectsEqual(S(branchBUUID, initialBranchUUID), [[store persistentRootWithUUID: prootUUID] branchUUIDs]);
}

- (void) testDeleteCurrentBranch
{
    // Delete it - should return NO because you can't delete the current branch
    UKFalse([store deleteBranch: initialBranchUUID ofPersistentRoot: prootUUID]);

    // Should have no effect
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);
    
    // Verify the branch is still there
    {
        COBranchInfo *branchObj = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: initialBranchUUID];
        UKNotNil(branchObj);
        UKFalse([branchObj isDeleted]);
    }
}

- (void) testBranchMetadata
{
    UKNil([[[store persistentRootWithUUID: prootUUID] currentBranchInfo] metadata]);
    
    UKTrue([store setMetadata: D(@"hello world", @"msg")
                    forBranch: initialBranchUUID
             ofPersistentRoot: prootUUID]);
    
    UKObjectsEqual(D(@"hello world", @"msg"), [[[store persistentRootWithUUID: prootUUID] currentBranchInfo] metadata]);
    
    UKTrue([store setMetadata: nil
                    forBranch: initialBranchUUID
             ofPersistentRoot: prootUUID]);
    
    UKNil([[[store persistentRootWithUUID: prootUUID] currentBranchInfo] metadata]);
}

- (void) testSetCurrentBranch
{
    UKObjectsEqual(initialBranchUUID, [[store persistentRootWithUUID: prootUUID] currentBranchUUID]);
    
    UKTrue([store setCurrentBranch: branchAUUID
                 forPersistentRoot: prootUUID]);
    
    UKObjectsEqual(branchAUUID, [[store persistentRootWithUUID: prootUUID] currentBranchUUID]);

    UKTrue([store setCurrentBranch: branchBUUID
                 forPersistentRoot: prootUUID]);
    
    UKObjectsEqual(branchBUUID, [[store persistentRootWithUUID: prootUUID] currentBranchUUID]);

}

- (void) testSetMainBranch
{
    UKObjectsEqual(initialBranchUUID, [[store persistentRootWithUUID: prootUUID] mainBranchUUID]);
    
    UKTrue([store setMainBranch: branchAUUID
              forPersistentRoot: prootUUID]);
    
    UKObjectsEqual(branchAUUID, [[store persistentRootWithUUID: prootUUID] mainBranchUUID]);
    
    UKTrue([store setMainBranch: branchBUUID
              forPersistentRoot: prootUUID]);
    
    UKObjectsEqual(branchBUUID, [[store persistentRootWithUUID: prootUUID] mainBranchUUID]);
    
}

- (void) testSetCurrentVersion
{
    COBranchInfo *branchA = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKIntsEqual(0, [[branchA tailRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LENGTH, [[branchA headRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LENGTH, [[branchA currentRevisionID] revisionIndex]);

    UKTrue([store setCurrentRevision: [[branchA currentRevisionID] revisionIDWithRevisionIndex: BRANCH_LATER]
                        headRevision: [branchA headRevisionID]
                        tailRevision: [branchA tailRevisionID]
                          forBranch: branchAUUID
                   ofPersistentRoot: prootUUID]);
    
    branchA = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKIntsEqual(0, [[branchA tailRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LENGTH, [[branchA headRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LATER, [[branchA currentRevisionID] revisionIndex]);

    UKTrue([store setCurrentRevision: [[branchA currentRevisionID] revisionIDWithRevisionIndex: BRANCH_LATER]
                        headRevision: [[branchA currentRevisionID] revisionIDWithRevisionIndex: BRANCH_LATER]
                        tailRevision: [branchA tailRevisionID]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID]);
    
    branchA = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKIntsEqual(0, [[branchA tailRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LATER, [[branchA headRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LATER, [[branchA currentRevisionID] revisionIndex]);

    UKTrue([store setCurrentRevision: [[branchA currentRevisionID] revisionIDWithRevisionIndex: BRANCH_LATER]
                        headRevision: [[branchA currentRevisionID] revisionIDWithRevisionIndex: BRANCH_LATER]
                        tailRevision: [[branchA currentRevisionID] revisionIDWithRevisionIndex: BRANCH_EARLY]
                           forBranch: branchAUUID
                    ofPersistentRoot: prootUUID]);
    
    branchA = [[store persistentRootWithUUID: prootUUID] branchInfoForUUID: branchAUUID];
    UKIntsEqual(BRANCH_EARLY, [[branchA tailRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LATER, [[branchA headRevisionID] revisionIndex]);
    UKIntsEqual(BRANCH_LATER, [[branchA currentRevisionID] revisionIndex]);
}

- (void) testCrossPersistentRootReference
{
    
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
    [[tree itemForUUID: childUUID1] setValue: hash forAttribute: @"attachment" type: kCOAttachmentType];
    CORevisionID *withAttachment = [store writeContents: tree withMetadata: nil parentRevisionID: initialRevisionId modifiedItems: nil];
    UKNotNil(withAttachment);
    UKTrue([store setCurrentRevision: withAttachment
                        headRevision: withAttachment
                        tailRevision: initialRevisionId
                           forBranch: initialBranchUUID
                    ofPersistentRoot: prootUUID]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);
    
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
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);
    UKFalse([[NSFileManager defaultManager] fileExistsAtPath: [[store URLForAttachmentID: hash] path]]);
}

/**
 * See the conceptual model of the store in the COSQLiteStore comment. Revisions are not 
 * first class citizes; we garbage-collect them when they are not referenced.
 */
- (void) testRevisionGCDoesNotCollectReferenced
{
    COItemGraph *tree = [self makeInitialItemTree];
    CORevisionID *referencedRevision = [store writeContents: tree
                                               withMetadata: nil
                                           parentRevisionID: initialRevisionId
                                              modifiedItems: nil];
    
    UKTrue([store setCurrentRevision: referencedRevision
                        headRevision: referencedRevision
                        tailRevision: initialRevisionId
                           forBranch: initialBranchUUID
                    ofPersistentRoot: prootUUID]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);
    
    UKObjectsEqual(tree, [store contentsForRevisionID: referencedRevision]);
}

- (void) testRevisionGCCollectsUnReferenced
{
    COItemGraph *tree = [self makeInitialItemTree];
    CORevisionID *unreferencedRevision = [store writeContents: tree
                                                 withMetadata: nil
                                         parentRevisionID: initialRevisionId
                                                modifiedItems: nil];
    
    UKObjectsEqual(tree, [store contentsForRevisionID: unreferencedRevision]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);
    
    UKNil([store contentsForRevisionID: unreferencedRevision]);
    UKNil([store revisionInfoForRevisionID: unreferencedRevision]);
    
    // TODO: Expand, test using -setTail...
}

- (void) testDeletePersistentRoot
{
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKObjectsEqual(A(prootUUID), [store persistentRootUUIDs]);

    // Delete it
    UKTrue([store deletePersistentRoot: prootUUID]);

    UKObjectsEqual(A(prootUUID), [store deletedPersistentRootUUIDs]);
    UKObjectsEqual([NSArray array], [store persistentRootUUIDs]);
    UKNotNil([store persistentRootWithUUID: prootUUID]);
    UKFalse([[[store persistentRootWithUUID: prootUUID] currentBranchInfo] isDeleted]); // Deleting proot does not mark branch as deleted.
    
    // Undelete it
    UKTrue([store undeletePersistentRoot: prootUUID]);
    
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKObjectsEqual(A(prootUUID), [store persistentRootUUIDs]);
    
    // Delete it, and finalize the deletion
    UKTrue([store deletePersistentRoot: prootUUID]);
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID]);
    
    UKObjectsEqual([NSArray array], [store persistentRootUUIDs]);
    UKObjectsEqual([NSArray array], [store deletedPersistentRootUUIDs]);
    UKNil([store persistentRootWithUUID: prootUUID]);
    UKNil([store revisionInfoForRevisionID: initialRevisionId]);
    UKNil([store contentsForRevisionID: initialRevisionId]);
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
    UKObjectsEqual(initialBranchUUID, [[store persistentRootWithUUID: prootUUID] currentBranchUUID]);
    UKObjectsEqual([self makeInitialItemTree], [store contentsForRevisionID: initialRevisionId]);
}

/**
 * Tests creating a persistent root, proot, making a copy of it, and then making a commit
 * to proot and a commit to the copy.
 */
- (void)testPersistentRootCopies
{
    COPersistentRootInfo *copy = [store createPersistentRootWithInitialRevision: initialRevisionId
                                                                        metadata: D(@"test2", @"name")];

    UKObjectsEqual(S(prootUUID, [copy UUID]), [NSSet setWithArray:[store persistentRootUUIDs]]);

    // 1. check setup
    
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

    UKObjectsEqual(copy.branchUUIDs, [store persistentRootWithUUID: [copy UUID]].branchUUIDs);
    UKObjectsEqual([[copy currentBranchInfo] currentRevisionID], [[store persistentRootWithUUID: [copy UUID]] currentBranchInfo].currentRevisionID);
    
    // 2. try changing. Verify that proot and copy are totally independent

    CORevisionID *rev1 = [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: 1];
    
    UKTrue([store setCurrentRevision: rev1
                        headRevision: rev1
                        tailRevision: initialRevisionId
                           forBranch: [[proot currentBranchInfo] UUID]
                    ofPersistentRoot: prootUUID]);
    
    // Reload proot's and copy's metadata
    
    ASSIGN(proot, [store persistentRootWithUUID: prootUUID]);
    copy = [store persistentRootWithUUID: [copy UUID]];
    UKObjectsEqual(rev1, [[proot currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(rev1, [[proot currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[proot currentBranchInfo] tailRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] tailRevisionID]);
    
    // Commit to copy as well.
    
    CORevisionID *rev2 = [CORevisionID revisionWithBackinStoreUUID: [proot UUID] revisionIndex: 2];
    
    UKTrue([store setCurrentRevision: rev2
                        headRevision: rev2
                        tailRevision: initialRevisionId
                           forBranch: [[copy currentBranchInfo] UUID]
                    ofPersistentRoot: [copy UUID]]);
    
    // Reload proot's and copy's metadata
    
    ASSIGN(proot, [store persistentRootWithUUID: prootUUID]);
    copy = [store persistentRootWithUUID: [copy UUID]];
    UKObjectsEqual(rev1, [[proot currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(rev1, [[proot currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[proot currentBranchInfo] tailRevisionID]);
    UKObjectsEqual(rev2, [[copy currentBranchInfo] currentRevisionID]);
    UKObjectsEqual(rev2, [[copy currentBranchInfo] headRevisionID]);
    UKObjectsEqual(initialRevisionId, [[copy currentBranchInfo] tailRevisionID]);
}

@end
