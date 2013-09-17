#import "COStoreTransaction.h"

#import "COStoreSetCurrentBranch.h"
#import "COStoreCreateBranch.h"
#import "COStoreCreatePersistentRoot.h"
#import "COStoreSetCurrentRevision.h"
#import "COStoreSetBranchMetadata.h"
#import "COStoreDeletePersistentRoot.h"
#import "COStoreUndeletePersistentRoot.h"
#import "COStoreDeleteBranch.h"
#import "COStoreUndeleteBranch.h"
#import "COStoreWriteRevision.h"

@interface COStoreTransaction ()
@property (readwrite, nonatomic, strong) ETUUID *transactionUUID;
@property (nonatomic, readwrite, strong) NSMutableArray *operations;
@end


@implementation COStoreTransaction

@synthesize transactionUUID;
@synthesize previousTransactionUUID;
@synthesize operations;

- (id) init
{
    SUPERINIT;
    self.operations = [NSMutableArray arrayWithCapacity: 16];
    self.transactionUUID = [ETUUID UUID];
    return self;
}

- (void) addOperation: (id)anOperation
{
    [operations addObject: anOperation];
}

/** @taskunit Revision Writing */

- (void) writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                           revisionUUID: (ETUUID *)aRevisionUUID
                               metadata: (NSDictionary *)metadata
                       parentRevisionID: (ETUUID *)aParent
                  mergeParentRevisionID: (ETUUID *)aMergeParent
                     persistentRootUUID: (ETUUID *)aUUID
                             branchUUID: (ETUUID*)branch
{
    NILARG_EXCEPTION_TEST(anItemTree);
    NILARG_EXCEPTION_TEST(aRevisionUUID);
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(branch);
    
    COStoreWriteRevision *op = [[COStoreWriteRevision alloc] init];
    op.modifiedItems = anItemTree;
    op.revisionUUID = aRevisionUUID;
    op.metadata = metadata;
    op.parentRevisionUUID = aParent;
    op.mergeParentRevisionUUID = aMergeParent;
    op.persistentRoot = aUUID;
    op.branch = branch;
    [self addOperation: op];
}

/** @taskunit Persistent Root Creation */

- (void) createPersistentRootWithUUID: (ETUUID *)persistentRootUUID
                persistentRootForCopy: (ETUUID *)persistentRootForCopyUUID
{
    NILARG_EXCEPTION_TEST(persistentRootUUID);
    
    COStoreCreatePersistentRoot *op = [[COStoreCreatePersistentRoot alloc] init];
    op.persistentRoot = persistentRootUUID;
    op.persistentRootForCopy = persistentRootForCopyUUID;
    [self addOperation: op];
}

/** @taskunit Persistent Root Modification */

- (void) setCurrentBranch: (ETUUID *)aBranch
        forPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreSetCurrentBranch *op = [[COStoreSetCurrentBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = aBranch;
    [self addOperation: op];
}

- (void) createBranchWithUUID: (ETUUID *)branchUUID
              initialRevision: (ETUUID *)revId
            forPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(branchUUID);
    NILARG_EXCEPTION_TEST(revId);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreCreateBranch *op = [[COStoreCreateBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = branchUUID;
    op.initialRevision = revId;
    [self addOperation: op];
}

/**
 * All-in-one method for updating the current revision of a persistent root.
 */
- (void) setCurrentRevision: (ETUUID *)currentRev
                  forBranch: (ETUUID *)aBranch
           ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(currentRev);
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreSetCurrentRevision *op = [[COStoreSetCurrentRevision alloc] init];
    op.currentRevision = currentRev;
    op.branch = aBranch;
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

- (void) setMetadata: (NSDictionary *)metadata
           forBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreSetBranchMetadata *op = [[COStoreSetBranchMetadata alloc] init];
    op.metadata = metadata;
    op.branch = aBranch;
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

/** @taskunit Persistent Root Deletion */

- (void) deletePersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreDeletePersistentRoot *op = [[COStoreDeletePersistentRoot alloc] init];
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

/**
 * Unmarks the given persistent root as deleted
 */
- (void) undeletePersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreUndeletePersistentRoot *op = [[COStoreUndeletePersistentRoot alloc] init];
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

/**
 * Marks the given branch of the persistent root as deleted, can be reverted by -undeleteBranch:ofPersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (void) deleteBranch: (ETUUID *)aBranch
     ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreDeleteBranch *op = [[COStoreDeleteBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = aBranch;
    [self addOperation: op];
}

/**
 * Unmarks the given branch of a persistent root as deleted
 */
- (void) undeleteBranch: (ETUUID *)aBranch
       ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreUndeleteBranch *op = [[COStoreUndeleteBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = aBranch;
    [self addOperation: op];    
}

@end
