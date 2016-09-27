/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  April 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"
#import "COItem.h"
#import "COSQLiteStore+Attachments.h"
#import "COSQLiteStore+Private.h"
#import "FMDatabaseAdditions.h"

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
    
    ETUUID *initialRevisionUUID;
    
    NSMutableArray *branchARevisionUUIDs;
    NSMutableArray *branchBRevisionUUIDs;
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

- (ETUUID *) lateBranchA
{
    return branchARevisionUUIDs[BRANCH_LATER];
}

- (ETUUID *) lateBranchB
{
    return branchBRevisionUUIDs[BRANCH_LATER];
}

- (ETUUID *) earlyBranchA
{
    return branchARevisionUUIDs[BRANCH_EARLY];
}

- (ETUUID *) earlyBranchB
{
    return branchBRevisionUUIDs[BRANCH_EARLY];
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
    return [COItemGraph itemGraphWithItemsRootFirst:
        @[[self initialRootItemForChildren: @[childUUID1]],
          [self initialChildItemForUUID: childUUID1 name: @"initial child"]]];
}

/**
 * Index is in [0..BRANCH_LENGTH]
 */
- (COItemGraph*) makeBranchAItemTreeAtIndex: (int)index
{
    NSString *name = [NSString stringWithFormat: @"branch A commit %d", index];
    return [COItemGraph itemGraphWithItemsRootFirst:
        @[[self initialRootItemForChildren: @[childUUID1]],
          [self initialChildItemForUUID: childUUID1 name: name]]];
}

/**
 * Index is in [0..BRANCH_LENGTH]
 */
- (COItemGraph*) makeBranchBItemTreeAtIndex: (int)index
{
    NSString *name = [NSString stringWithFormat: @"branch B commit %d", index];
    return [COItemGraph itemGraphWithItemsRootFirst:
        @[[self initialRootItemForChildren: @[childUUID2]],
          [self initialChildItemForUUID: childUUID2 name: name]]];
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
    return @{ @"name": @"first commit" };
}

- (NSDictionary *)branchAMetadata
{
    return @{ @"name": @"branch A" };
}

- (NSDictionary *)branchBMetadata
{
    return @{ @"name": @"branch B" };
}


- (id) init
{
    SUPERINIT;
    
    branchARevisionUUIDs = [[NSMutableArray alloc] init];
    branchBRevisionUUIDs = [[NSMutableArray alloc] init];
    
    // First commit
    
    
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    proot = [txn createPersistentRootWithInitialItemGraph: [self makeInitialItemTree]
                                                     UUID: [ETUUID UUID]
                                               branchUUID: [ETUUID UUID]
                                         revisionMetadata: [self initialMetadata]];
    prootUUID =  proot.UUID;
    initialBranchUUID =  proot.currentBranchUUID;
    initialRevisionUUID = proot.currentRevisionUUID;
    
    branchAUUID =  [ETUUID UUID];
    [txn createBranchWithUUID: branchAUUID
                   parentBranch: nil
                initialRevision: initialRevisionUUID
              forPersistentRoot: prootUUID];
    
    branchBUUID =  [ETUUID UUID];
    [txn createBranchWithUUID: branchBUUID
                   parentBranch: nil
                initialRevision: initialRevisionUUID
              forPersistentRoot: prootUUID];
    
    // Branch A
    
    for (int i = 0; i < BRANCH_LENGTH; i++)
    {
        ETUUID *revid = [ETUUID UUID];
        
        [txn writeRevisionWithModifiedItems: [self makeBranchAItemTreeAtIndex: i]
                               revisionUUID: revid
                                   metadata: [self branchAMetadata]
                           parentRevisionID: (i == 0) ? initialRevisionUUID : branchARevisionUUIDs.lastObject
                      mergeParentRevisionID: nil
                         persistentRootUUID: prootUUID
                                 branchUUID: branchAUUID];
        
        [branchARevisionUUIDs addObject: revid];
    }
    
    // Branch B
    
    for (int i = 0; i < BRANCH_LENGTH; i++)
    {
        ETUUID *revid = [ETUUID UUID];

        [txn writeRevisionWithModifiedItems: [self makeBranchBItemTreeAtIndex: i]
                               revisionUUID: revid
                                   metadata: [self branchBMetadata]
                           parentRevisionID: (i == 0) ? initialRevisionUUID : branchBRevisionUUIDs.lastObject
                      mergeParentRevisionID: nil
                         persistentRootUUID: prootUUID
                                 branchUUID: branchBUUID];
        
        [branchBRevisionUUIDs addObject: revid];
    }

    [txn setCurrentRevision: branchARevisionUUIDs.lastObject
               headRevision: branchARevisionUUIDs.lastObject
                  forBranch: branchAUUID
           ofPersistentRoot: prootUUID];

    [txn setCurrentRevision: branchBRevisionUUIDs.lastObject
               headRevision: branchBRevisionUUIDs.lastObject
                  forBranch: branchBUUID
           ofPersistentRoot: prootUUID];

    [self updateChangeCountAndCommitTransaction: txn];
    
    return self;
}



// --- The tests themselves

- (void) updateChangeCountAndCommitTransaction: (COStoreTransaction *)txn
{
    prootChangeCount = [txn setOldTransactionID: prootChangeCount forPersistentRoot: prootUUID];
    UKTrue([store commitStoreTransaction: txn]);
}

- (void) testDeleteBranchA
{
    COBranchInfo *initialState = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    
    UKObjectsEqual(S(branchAUUID, branchBUUID, initialBranchUUID), [store persistentRootInfoForUUID: prootUUID].branchUUIDs);
    
    // Delete it
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn deleteBranch: branchAUUID ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKTrue(branchObj.deleted);
    }
    
    // Ensure we can't switch to it, since it is deleted
//    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
//    UKFalse([store setCurrentBranch: branchAUUID forPersistentRoot: prootUUID]);
//    [store commitStoreTransaction: txn];
    
    // Undelete it
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn undeleteBranch: branchAUUID ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKFalse(branchObj.deleted);
        UKObjectsEqual(initialState.currentRevisionUUID, branchObj.currentRevisionUUID);
    }

    // Should have no effect
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);

    // Verify the branch is still there
    {
        COBranchInfo *branchObj = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
        UKObjectsEqual(initialState.currentRevisionUUID, branchObj.currentRevisionUUID);
    }
    
    // Really delete it
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn deleteBranch: branchAUUID ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    UKNil([[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID]);
    UKObjectsEqual(S(branchBUUID, initialBranchUUID), [store persistentRootInfoForUUID: prootUUID].branchUUIDs);
}

/**
 * Not a good idea but this is supported, at least right now
 */
- (void) testDeleteCurrentBranch
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn deleteBranch: initialBranchUUID ofPersistentRoot: prootUUID];
    [self updateChangeCountAndCommitTransaction: txn];
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    // FIXME: Failing
    //UKTrue([[[store persistentRootInfoForUUID: prootUUID] branches] isEmpty]);
}

- (void) testBranchMetadata
{
    // A plain call to -createPersistentRootWithInitialItemGraph: creates a default branch
    // with nil metadata; this is intentional.
    //
    // If you want to give the branch initial metadata you can call -setMetadata:forBranch:...
    // in a transaction with the -createPersistentRootWithInitialItemGraph: call.
    UKNil([store persistentRootInfoForUUID: prootUUID].currentBranchInfo.metadata);
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setMetadata: @{@"msg": @"hello world"}
               forBranch: initialBranchUUID
        ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKObjectsEqual(D(@"hello world", @"msg"), [store persistentRootInfoForUUID: prootUUID].currentBranchInfo.metadata);
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setMetadata: nil
               forBranch: initialBranchUUID
        ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    UKNil([store persistentRootInfoForUUID: prootUUID].currentBranchInfo.metadata);
}

- (void) testPersistentRootMetadata
{
    // A plain call to -createPersistentRootWithInitialItemGraph: creates a persistent root
    // with nil metadata; this is intentional.
    UKNil([store persistentRootInfoForUUID: prootUUID].metadata);
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setMetadata: @{ @"msg": @"hello world" }
       forPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKObjectsEqual(D(@"hello world", @"msg"), [store persistentRootInfoForUUID: prootUUID].metadata);
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setMetadata: nil
       forPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    UKNil([store persistentRootInfoForUUID: prootUUID].metadata);
}


- (void) testSetCurrentBranch
{
    UKObjectsEqual(initialBranchUUID, [store persistentRootInfoForUUID: prootUUID].currentBranchUUID);
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentBranch: branchAUUID
            forPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKObjectsEqual(branchAUUID, [store persistentRootInfoForUUID: prootUUID].currentBranchUUID);

    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentBranch: branchBUUID
            forPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKObjectsEqual(branchBUUID, [store persistentRootInfoForUUID: prootUUID].currentBranchUUID);
}

- (void) testSetCurrentVersion
{
    [self checkBranch: branchAUUID
              current: branchARevisionUUIDs.lastObject
                 head: branchARevisionUUIDs.lastObject];

    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentRevision: [self lateBranchA]
                   headRevision: branchARevisionUUIDs.lastObject
                      forBranch: branchAUUID
               ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    [self checkBranch: branchAUUID
              current: [self lateBranchA]
                 head: branchARevisionUUIDs.lastObject];
        {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentRevision: [self lateBranchA]
                   headRevision: [self lateBranchA]
                      forBranch: branchAUUID
               ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    [self checkBranch: branchAUUID
              current: [self lateBranchA]
                 head: [self lateBranchA]];

    // FIXME: Set initial revision and test it
}

- (void) testSetCurrentVersionChangeCount
{
    COBranchInfo *branchA = [[store persistentRootInfoForUUID: prootUUID] branchInfoForUUID: branchAUUID];
    
    [self checkBranch: branchAUUID
              current: branchARevisionUUIDs.lastObject
                 head: branchARevisionUUIDs.lastObject];

    // Open another store and change the current revision
    
    {
        COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: store.URL];
        
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentRevision: [self lateBranchA]
                   headRevision: branchA.headRevisionUUID
                      forBranch: branchAUUID
               ofPersistentRoot: prootUUID];
        
        (void)[txn setOldTransactionID: prootChangeCount forPersistentRoot: prootUUID];
        UKTrue([store2 commitStoreTransaction: txn]);
    }
    
    // Try to change the revision again, pretending we didn't notice the
    // store2 change

    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentRevision: [self earlyBranchA]
                   headRevision: branchA.headRevisionUUID
                      forBranch: branchAUUID
               ofPersistentRoot: prootUUID];
        (void)[txn setOldTransactionID: prootChangeCount forPersistentRoot: prootUUID];
        UKFalse([store commitStoreTransaction: txn]);
    }

    // Reload our in-memory state, and the call should succeed
    
    proot =  [store persistentRootInfoForUUID: prootUUID];    
    prootChangeCount = proot.transactionID;
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentRevision: [self earlyBranchA]
                   headRevision: branchA.headRevisionUUID
                      forBranch: branchAUUID
               ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
}

- (void) testCrossPersistentRootReference
{
    
}

- (void) testAttachmentsBasic
{
    NSString *fakeAttachment1 = @"this is a large attachment";
    NSString *fakeAttachment2 = @"this is another large attachment";
    NSString *path1 = [[SQLiteStoreTestCase temporaryPathForTestStorage] stringByAppendingPathComponent: @"coreobject-test1.txt"];
    NSString *path2 = [[SQLiteStoreTestCase temporaryPathForTestStorage] stringByAppendingPathComponent: @"coreobject-test2.txt"];
    
    [fakeAttachment1 writeToFile: path1
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
    
    [fakeAttachment2 writeToFile: path2
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
    
    COAttachmentID *hash1 = [store importAttachmentFromURL: [NSURL fileURLWithPath: path1]];
    COAttachmentID *hash2 = [store importAttachmentFromURL: [NSURL fileURLWithPath: path2]];
    
    UKObjectsEqual(fakeAttachment1, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash1]
                                                             encoding: NSUTF8StringEncoding
                                                                error: NULL]);
    
    UKObjectsEqual(fakeAttachment2, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash2]
                                                             encoding: NSUTF8StringEncoding
                                                                error: NULL ]);
    
    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: [store URLForAttachmentID: hash1].path]);
    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: [store URLForAttachmentID: hash2].path]);
}

- (void) testAttachmentFromData
{
    NSString *fakeAttachment = @"this is a large attachment";
    COAttachmentID *hash = [store importAttachmentFromData: [fakeAttachment dataUsingEncoding: NSUTF8StringEncoding]];
    
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash]
                                                            encoding: NSUTF8StringEncoding
                                                               error: NULL]);
    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: [store URLForAttachmentID: hash].path]);
}

- (void) testAttachmentsGCDoesNotCollectReferenced
{
    NSString *fakeAttachment = @"this is a large attachment";
    NSString *path = [[SQLiteStoreTestCase temporaryPathForTestStorage] stringByAppendingPathComponent: @"cotest.txt"];
    
    UKTrue([fakeAttachment writeToFile: path
                            atomically: YES
                              encoding: NSUTF8StringEncoding
                                 error: NULL]);
    
    COAttachmentID *hash = [store importAttachmentFromURL: [NSURL fileURLWithPath: path]];
    UKNotNil(hash);
    
    NSString *internalPath = [store URLForAttachmentID: hash].path;
    
    UKObjectsNotEqual(path, internalPath);
    
    NSLog(@"external path: %@", path);
    NSLog(@"internal path: %@", internalPath);
    
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash]
                                                            encoding: NSUTF8StringEncoding
                                                               error: NULL]);
    
    // Test attachment GC
    
    COItemGraph *tree = [self makeInitialItemTree];
    [[tree itemForUUID: childUUID1] setValue: hash forAttribute: @"attachment" type: kCOTypeAttachment];
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        ETUUID *withAttachment = [ETUUID UUID];
        
        [txn writeRevisionWithModifiedItems: tree
                               revisionUUID: withAttachment
                                   metadata: nil
                           parentRevisionID: initialRevisionUUID
                      mergeParentRevisionID: nil
                         persistentRootUUID: prootUUID
                                 branchUUID: branchAUUID];
        
        
        [txn setCurrentRevision: withAttachment
                   headRevision: withAttachment
                      forBranch: initialBranchUUID
               ofPersistentRoot: prootUUID];
        
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash]
                                                            encoding: NSUTF8StringEncoding
                                                              error: NULL]);
}

- (void) testAttachmentsGCCollectsUnReferenced
{
    NSString *fakeAttachment = @"this is a large attachment";
    NSString *path = [[SQLiteStoreTestCase temporaryPathForTestStorage] stringByAppendingPathComponent: @"cotest.txt"];
    [fakeAttachment writeToFile: path
                     atomically: YES
                       encoding: NSUTF8StringEncoding
                         error: NULL];
    COAttachmentID *hash = [store importAttachmentFromURL: [NSURL fileURLWithPath: path]];
    
    UKObjectsEqual(fakeAttachment, [NSString stringWithContentsOfURL: [store URLForAttachmentID: hash]
                                                            encoding: NSUTF8StringEncoding
                                                              error: NULL]);

    UKTrue([[NSFileManager defaultManager] fileExistsAtPath: [store URLForAttachmentID: hash].path]);
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    UKFalse([[NSFileManager defaultManager] fileExistsAtPath: [store URLForAttachmentID: hash].path]);
}

/**
 * See the conceptual model of the store in the COSQLiteStore comment. Revisions are not 
 * first class citizes; we garbage-collect them when they are not referenced.
 */
- (void) testRevisionGCDoesNotCollectReferenced
{
    COItemGraph *tree = [self makeInitialItemTree];
    ETUUID *referencedRevision = [ETUUID UUID];
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        
        [txn writeRevisionWithModifiedItems: tree
                               revisionUUID: referencedRevision
                                   metadata: nil
                           parentRevisionID: initialRevisionUUID
                      mergeParentRevisionID: nil
                         persistentRootUUID: prootUUID
                                 branchUUID: branchAUUID];
        
        [txn setCurrentRevision: referencedRevision
                   headRevision: referencedRevision
                      forBranch: initialBranchUUID
               ofPersistentRoot: prootUUID];
        
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);

    UKObjectsEqual(tree, [store itemGraphForRevisionUUID: referencedRevision persistentRoot: prootUUID]);
}

- (void) testRevisionGCCollectsUnReferenced
{
    COItemGraph *tree = [self makeInitialItemTree];

    ETUUID *unreferencedRevision = [ETUUID UUID];

    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn writeRevisionWithModifiedItems: tree
                               revisionUUID: unreferencedRevision
                                   metadata: nil
                           parentRevisionID: initialRevisionUUID
                      mergeParentRevisionID: nil
                         persistentRootUUID: prootUUID
                                 branchUUID: branchAUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKObjectsEqual(tree, [store itemGraphForRevisionUUID: unreferencedRevision persistentRoot: prootUUID]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    
    UKNil([store itemGraphForRevisionUUID: unreferencedRevision persistentRoot: prootUUID]);
    UKNil([store revisionInfoForRevisionUUID: unreferencedRevision persistentRootUUID: prootUUID]);
    
    // TODO: Expand, test using -setInitial...
}

- (void) testRevisionInfo
{
    CORevisionInfo *info = [store revisionInfoForRevisionUUID: initialRevisionUUID persistentRootUUID: prootUUID];
    UKNil(info.parentRevisionUUID);
    UKObjectsEqual(initialRevisionUUID, info.revisionUUID);
    UKObjectsEqual(proot.currentBranchUUID, info.branchUUID);
}

- (void) checkHasTables: (BOOL)flag forUUID: (ETUUID *)aUUID
{
#if BACKING_STORES_SHARE_SAME_SQLITE_DB == 1
    [store testingRunBlockInStoreQueue: ^() {
        BOOL hasCommitsTable = [store.database tableExists: [NSString stringWithFormat: @"commits-%@", aUUID]];
        BOOL hasMetadataTable = [store.database tableExists: [NSString stringWithFormat: @"metadata-%@", aUUID]];
        
        if (flag)
        {
            UKTrue(hasCommitsTable);
            UKTrue(hasMetadataTable);
        }
        else
        {
            UKFalse(hasCommitsTable);
            UKFalse(hasMetadataTable);
        }
    }];
#endif
}

- (void) testDeletePersistentRoot
{
    UKObjectsEqual(@[], store.deletedPersistentRootUUIDs);
    UKObjectsEqual(A(prootUUID), store.persistentRootUUIDs);
    UKFalse([store persistentRootInfoForUUID: prootUUID].deleted);

    [self checkHasTables: YES forUUID: prootUUID];
    
    // Delete it
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn deletePersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }

    UKTrue([store persistentRootInfoForUUID: prootUUID].deleted);
    UKObjectsEqual(A(prootUUID), store.deletedPersistentRootUUIDs);
    UKObjectsEqual(@[], store.persistentRootUUIDs);
    UKNotNil([store persistentRootInfoForUUID: prootUUID]);
    UKFalse([store persistentRootInfoForUUID: prootUUID].currentBranchInfo.deleted); // Deleting proot does not mark branch as deleted.
    
    // Undelete it
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn undeletePersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    UKFalse([store persistentRootInfoForUUID: prootUUID].deleted);
    UKObjectsEqual(@[], store.deletedPersistentRootUUIDs);
    UKObjectsEqual(A(prootUUID), store.persistentRootUUIDs);
    
    // Delete it, and finalize the deletion
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn deletePersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
        
        UKTrue([store finalizeDeletionsForPersistentRoot: prootUUID error: NULL]);
    }
    
    UKObjectsEqual(@[], store.persistentRootUUIDs);
    UKObjectsEqual(@[], store.deletedPersistentRootUUIDs);
    UKNil([store persistentRootInfoForUUID: prootUUID]);
    UKNil([store revisionInfoForRevisionUUID: initialRevisionUUID persistentRootUUID: prootUUID]);
    UKNil([store itemGraphForRevisionUUID: initialRevisionUUID persistentRoot: prootUUID]);
    
    [self checkHasTables: NO forUUID: prootUUID];
}

// FIXME: Uncomment this test and verify that things work/do not work on deleted persistent root, as appropriate

//- (void) testAllOperationsFailOnDeletedPersistentRoot
//{
//    // Used later in test
//    COUUID *branch = [store createBranchWithInitialRevision: [[proot currentBranchState] currentState]
//                                                 setCurrent: NO
//                                          forPersistentRoot: prootUUID];
//    
//    UKTrue([store deletePersistentRoot: prootUUID]);
//    // Persistent root returned since we have not called finalizeDeletions.
//    UKObjectsEqual(A(prootUUID), store.persistentRootUUIDs);
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
    UKObjectsEqual(S(prootUUID), [NSSet setWithArray: store.persistentRootUUIDs]);
    
    [self checkPersistentRoot: prootUUID
                      current: initialRevisionUUID
                         head: initialRevisionUUID];
    
    UKObjectsEqual([self makeInitialItemTree], [self currentItemGraphForPersistentRoot: prootUUID]);
    UKFalse([store persistentRootInfoForUUID: prootUUID].deleted);
}

/**
 * Tests creating a persistent root, proot, making a copy of it, and then making a commit
 * to proot and a commit to the copy.
 */
- (void)testPersistentRootCopies
{
    int64_t copyChangeCount = 0;
    COPersistentRootInfo *copy = nil;
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        copy = [txn createPersistentRootCopyWithUUID: [ETUUID UUID]
                            parentPersistentRootUUID: prootUUID
                                          branchUUID: [ETUUID UUID]
                                    parentBranchUUID: nil
                                 initialRevisionUUID: initialRevisionUUID];
        copyChangeCount = [txn setOldTransactionID: copyChangeCount forPersistentRoot: copy.UUID];
        UKTrue([store commitStoreTransaction: txn]);
    }
    
    UKObjectsEqual(S(prootUUID, copy.UUID), [NSSet setWithArray:store.persistentRootUUIDs]);

    // 1. check setup
    
    // Verify that the new branch metadata is nil
    UKNil(copy.currentBranchInfo.metadata);
    
    // Verify that new UUIDs were generated
    UKObjectsNotEqual(prootUUID, copy.UUID);
    UKObjectsNotEqual(proot.branchUUIDs, copy.branchUUIDs);
    UKIntsEqual(1,  copy.branchUUIDs.count);
    
    // Check that the current branch is set correctly
    UKObjectsEqual([copy.branchUUIDs anyObject], copy.currentBranchUUID);
    
    // Check that the branch data is the same

    [self checkPersistentRoot: prootUUID
                      current: initialRevisionUUID
                         head: initialRevisionUUID];
    
    [self checkPersistentRoot: copy.UUID
                      current: initialRevisionUUID
                         head: initialRevisionUUID];
    
    // Make sure the persistent root state returned from createPersistentRoot matches what the store
    // gives us when we read it back.

    UKObjectsEqual(copy.branchUUIDs, [store persistentRootInfoForUUID: copy.UUID].branchUUIDs);
    UKObjectsEqual(copy.currentBranchInfo.currentRevisionUUID, [store persistentRootInfoForUUID: copy.UUID].currentBranchInfo.currentRevisionUUID);
    
    // 2. try changing. Verify that proot and copy are totally independent

    ETUUID *rev1 = [self earlyBranchA];

    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentRevision: rev1
                   headRevision: rev1
                      forBranch: proot.currentBranchInfo.UUID
               ofPersistentRoot: prootUUID];
        [self updateChangeCountAndCommitTransaction: txn];
    }
    
    [self checkPersistentRoot: prootUUID
                      current: rev1
                         head: rev1];
    
    [self checkPersistentRoot: copy.UUID
                      current: initialRevisionUUID
                         head: initialRevisionUUID];
    
    // Commit to copy as well.
    
    ETUUID *rev2 = [self lateBranchA];
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        [txn setCurrentRevision: rev2
                   headRevision: rev2
                      forBranch: copy.currentBranchInfo.UUID
               ofPersistentRoot: copy.UUID];
        copyChangeCount = [txn setOldTransactionID: copyChangeCount forPersistentRoot: copy.UUID];
        UKTrue([store commitStoreTransaction: txn]);
    }

    [self checkPersistentRoot: prootUUID
                      current: rev1
                         head: rev1];
    
    [self checkPersistentRoot: copy.UUID
                      current: rev2
                         head: rev2];
}

- (void) testStoreUUID
{
    ETUUID *uuid = store.UUID;
    UKNotNil(uuid);
    
    COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: store.URL];
    UKObjectsEqual(uuid, store2.UUID);
    
}

// The following are some tests ported from CoreObject's TestStore.m

- (void)testPersistentRootInsertion
{
    ETUUID *cheapCopyUUID = [ETUUID UUID];
    ETUUID *cheapCopyBranchUUID = [ETUUID UUID];

    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    COPersistentRootInfo *cheapCopy = [txn createPersistentRootCopyWithUUID: cheapCopyUUID
                                                   parentPersistentRootUUID:  prootUUID
                                                                 branchUUID: cheapCopyBranchUUID
                                                           parentBranchUUID: nil
                                                        initialRevisionUUID: branchARevisionUUIDs.lastObject];
    UKTrue([store commitStoreTransaction: txn]);

    UKObjectsEqual(rootUUID, [store rootObjectUUIDForPersistentRoot: proot.UUID]);
    UKObjectsEqual(rootUUID, [store rootObjectUUIDForPersistentRoot: cheapCopy.UUID]);
    UKObjectsEqual(initialBranchUUID, [store persistentRootInfoForUUID: prootUUID].currentBranchUUID);
    UKObjectsEqual(cheapCopyBranchUUID, [store persistentRootInfoForUUID: cheapCopyUUID].currentBranchUUID);
}

- (void)testReopenStore
{
    COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: store.URL];
    
    ETUUID *currentRevisionUUID = [store2 persistentRootInfoForUUID: prootUUID].currentRevisionUUID;
    ETUUID *branchARevisionUUID = [[store2 persistentRootInfoForUUID: prootUUID]
                                        branchInfoForUUID: branchAUUID].currentRevisionUUID;
    ETUUID *branchBRevisionUUID = [[store2 persistentRootInfoForUUID: prootUUID]
                                        branchInfoForUUID: branchBUUID].currentRevisionUUID;
    
    UKObjectsEqual([self makeInitialItemTree], [store2 itemGraphForRevisionUUID: currentRevisionUUID persistentRoot: prootUUID]);
    UKTrue(COItemGraphEqualToItemGraph([self makeBranchAItemTreeAtIndex: BRANCH_LENGTH - 1], [store2 itemGraphForRevisionUUID: branchARevisionUUID persistentRoot: prootUUID]));
    UKTrue(COItemGraphEqualToItemGraph([self makeBranchBItemTreeAtIndex: BRANCH_LENGTH - 1], [store2 itemGraphForRevisionUUID: branchBRevisionUUID persistentRoot: prootUUID]));
}

- (void)testEmptyCommitWithNoChanges
{
    COItemGraph *graph = [[COItemGraph alloc] initWithItemForUUID: @{}
                                                      rootItemUUID: rootUUID];
    UKNotNil(graph);


    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    ETUUID *revid = [ETUUID UUID];
    
    [txn writeRevisionWithModifiedItems: graph
                           revisionUUID: revid
                               metadata: nil
                       parentRevisionID: initialRevisionUUID
                  mergeParentRevisionID: nil
                     persistentRootUUID: prootUUID
                             branchUUID: branchAUUID];
    [self updateChangeCountAndCommitTransaction: txn];
    
    // This could be useful for committing markers/tags. The very first
    // ObjectMerging prototype used this approach for marking points when the
    // user pressed cmd+S
    
    UKObjectsEqual([self makeInitialItemTree], [store itemGraphForRevisionUUID: revid persistentRoot: prootUUID]);
}

- (void) testInitialRevisionMetadata
{
    UKObjectsEqual([self initialMetadata], [[store revisionInfoForRevisionUUID: initialRevisionUUID
                                                            persistentRootUUID: prootUUID] metadata]);
}

- (void) testPersistentRootInfoForUUID
{
    UKNil([store persistentRootInfoForUUID: nil]);
}

- (void) testDuplicateBranchesDisallowed
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    COPersistentRootInfo *otherPersistentRoot = [txn createPersistentRootWithInitialItemGraph: [self makeInitialItemTree]
                                                                                         UUID: [ETUUID UUID]
                                                                                   branchUUID: [ETUUID UUID]
                                                                             revisionMetadata: nil];
    [txn createBranchWithUUID: branchBUUID
                 parentBranch: nil
              initialRevision: otherPersistentRoot.currentRevisionUUID
            forPersistentRoot: otherPersistentRoot.UUID];
    
    UKFalse([store commitStoreTransaction: txn]);
}

/**
 * The precise constraint is: for every revision, the root object UUID of that
 * revision's object graph must equal the root object UUID of that revision's
 * parent's object graph
 */
- (void) testChangeRootObjectUUIDDisallowed
{
    // Make a "bad" item graph where the root item UUID is not rootUUID
    ETUUID *newRootUUID = [ETUUID UUID];
    COItem *newRootItem = [[COItem alloc] initWithUUID: newRootUUID typesForAttributes: @{} valuesForAttributes: @{}];
    COItemGraph *graph = [[COItemGraph alloc] initWithItems: @[newRootItem] rootItemUUID: newRootUUID];
    
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn writeRevisionWithModifiedItems: graph
                           revisionUUID: [ETUUID UUID]
                               metadata: nil
                       parentRevisionID: initialRevisionUUID
                  mergeParentRevisionID: nil
                     persistentRootUUID: prootUUID
                             branchUUID: branchAUUID];
    
    prootChangeCount = [txn setOldTransactionID: prootChangeCount forPersistentRoot: prootUUID];
    UKFalse([store commitStoreTransaction: txn]);
}

- (void) testInsertDuplicateRevisionUUID
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn writeRevisionWithModifiedItems: [self makeBranchAItemTreeAtIndex: BRANCH_LATER]
                           revisionUUID: [self lateBranchA]
                               metadata: nil
                       parentRevisionID: initialRevisionUUID
                  mergeParentRevisionID: nil
                     persistentRootUUID: prootUUID
                             branchUUID: branchAUUID];
    
    prootChangeCount = [txn setOldTransactionID: prootChangeCount forPersistentRoot: prootUUID];
    UKFalse([store commitStoreTransaction: txn]);
}

/**
 * Writing a new revision does not touch the mutable state of a persistent
 * root, so there is no need to provide a transaction ID for the persistent
 * root. This test ensures that the store allows this.
 */
- (void) testWriteRevisionDoesNotNeedValidTransactionID
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn writeRevisionWithModifiedItems: [self makeBranchAItemTreeAtIndex: BRANCH_LATER]
                           revisionUUID: [ETUUID UUID]
                               metadata: nil
                       parentRevisionID: initialRevisionUUID
                  mergeParentRevisionID: nil
                     persistentRootUUID: prootUUID
                             branchUUID: branchAUUID];
    UKTrue([store commitStoreTransaction: txn]);
}

- (void) testWriteRevisionWithNonExistentParent
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    
    // N.B. If the parent revision is not in the store, you have to provide all items
    // in the revision (not just a delta against the parent)
    
    [txn writeRevisionWithModifiedItems: [self makeBranchAItemTreeAtIndex: BRANCH_LATER]
                           revisionUUID: [ETUUID UUID]
                               metadata: nil
                       parentRevisionID: [ETUUID UUID]
                  mergeParentRevisionID: nil
                     persistentRootUUID: prootUUID
                             branchUUID: branchAUUID];
    prootChangeCount = [txn setOldTransactionID: prootChangeCount forPersistentRoot: prootUUID];
    UKTrue([store commitStoreTransaction: txn]);
}

- (void) testWriteRevisionWithNonExistentMergeParent
{
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    [txn writeRevisionWithModifiedItems: [self makeBranchAItemTreeAtIndex: BRANCH_LATER]
                           revisionUUID: [ETUUID UUID]
                               metadata: nil
                       parentRevisionID: initialRevisionUUID
                  mergeParentRevisionID: [ETUUID UUID]
                     persistentRootUUID: prootUUID
                             branchUUID: branchAUUID];
    prootChangeCount = [txn setOldTransactionID: prootChangeCount forPersistentRoot: prootUUID];
    UKTrue([store commitStoreTransaction: txn]);
}

/**
 * check that the store can retrieve the item graph for a (persistentRoot, revisionUUID) pair
 * even if persistentRoot has been permanently deleted, and persistentRoot != the backing store UUID.
 */
- (void) testAccessItemGraphAfterPersistentRootDeletion
{
    /**
     * Persistent root that will be created & deleted
     */
    ETUUID *cheapCopyUUID1 = [ETUUID UUID];
    ETUUID *cheapCopyBranchUUID1 = [ETUUID UUID];

    /**
     * Persistent root to prevent newRevisionUUID from being GC'ed
     */
    ETUUID *cheapCopyUUID2 = [ETUUID UUID];
    ETUUID *cheapCopyBranchUUID2 = [ETUUID UUID];

    /**
     * Revision to commit in cheapCopyUUID1
     */
    ETUUID *newRevisionUUID = [ETUUID UUID];
    
    int64_t cheapCopy1TransactionID = 0;
    int64_t cheapCopy2TransactionID = 0;
    
    // 1. Make a cheap copy and write a new revision in it.
    //    This is just to give a situation where we have a revision whose
    //    persistentRootUUID is not the same as the backing store's
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];

        COPersistentRootInfo *cheapCopy1 = [txn createPersistentRootCopyWithUUID: cheapCopyUUID1
                                                        parentPersistentRootUUID: prootUUID
                                                                      branchUUID: cheapCopyBranchUUID1
                                                                parentBranchUUID: nil
                                                             initialRevisionUUID: newRevisionUUID];
        
        [txn writeRevisionWithModifiedItems: [self itemTreeWithChildNameChange: @"newRevisionUUID"]
                               revisionUUID: newRevisionUUID
                                   metadata: nil
                           parentRevisionID: initialRevisionUUID
                      mergeParentRevisionID: nil
                         persistentRootUUID: cheapCopyUUID1
                                 branchUUID: cheapCopyBranchUUID1];

        cheapCopy1TransactionID = [txn setOldTransactionID: cheapCopy1.transactionID forPersistentRoot: cheapCopyUUID1];
        
        UKTrue([store commitStoreTransaction: txn]);
    }
    
    UKTrue(COItemGraphEqualToItemGraph([self itemTreeWithChildNameChange: @"newRevisionUUID"],
                                       [store itemGraphForRevisionUUID: newRevisionUUID persistentRoot: cheapCopyUUID1]));
    
    // 2. Make another cheap copy based on cheapCopyUUID1. Then delete cheapCopyUUID1
    
    {
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        
        COPersistentRootInfo *cheapCopy2 = [txn createPersistentRootCopyWithUUID: cheapCopyUUID2
                                                        parentPersistentRootUUID: cheapCopyUUID1
                                                                      branchUUID: cheapCopyBranchUUID2
                                                                parentBranchUUID: nil
                                                             initialRevisionUUID: newRevisionUUID];
        
        [txn deletePersistentRoot: cheapCopyUUID1];
        
        cheapCopy1TransactionID = [txn setOldTransactionID: cheapCopy1TransactionID forPersistentRoot: cheapCopyUUID1];
        cheapCopy1TransactionID = [txn setOldTransactionID: cheapCopy2.transactionID forPersistentRoot: cheapCopyUUID2];
        
        UKTrue([store commitStoreTransaction: txn]);
        
        UKTrue([store finalizeDeletionsForPersistentRoot: cheapCopyUUID1 error: NULL]);
    }
        
    // 3. Ensure we can reopen the store, and still read back newRevisionUUID,
    // even though proot it was committed on is deleted.
    
    COSQLiteStore *store2 = [[COSQLiteStore alloc] initWithURL: store.URL];

    UKNil([store2 persistentRootInfoForUUID: cheapCopyUUID1]);
    UKNotNil([store2 persistentRootInfoForUUID: cheapCopyUUID2]);
    
    UKTrue(COItemGraphEqualToItemGraph([self itemTreeWithChildNameChange: @"newRevisionUUID"],
                                       [store2 itemGraphForRevisionUUID: newRevisionUUID persistentRoot: cheapCopyUUID1]));
    UKTrue(COItemGraphEqualToItemGraph([self itemTreeWithChildNameChange: @"newRevisionUUID"],
                                       [store2 itemGraphForRevisionUUID: newRevisionUUID persistentRoot: cheapCopyUUID2]));

}

@end
