#import <CoreObject/CoreObject.h>

@interface COStoreTransaction : NSObject

@property (readwrite, nonatomic, strong) ETUUID *transactionUUID;
@property (readwrite, nonatomic, strong) ETUUID *previousTransactionUUID;

@property (nonatomic, readonly, strong) NSMutableArray *operations;

/** @taskunit Revision Writing */

- (void) writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                           revisionUUID: (ETUUID *)aRevisionUUID
                               metadata: (NSDictionary *)metadata
                       parentRevisionID: (ETUUID *)aParent
                  mergeParentRevisionID: (ETUUID *)aMergeParent
                     persistentRootUUID: (ETUUID *)aUUID
                             branchUUID: (ETUUID*)branch;

/** @taskunit Persistent Root Creation */

- (void) createPersistentRootWithUUID: (ETUUID *)persistentRootUUID
                persistentRootForCopy: (ETUUID *)persistentRootForCopyUUID;

/** @taskunit Persistent Root Modification */

/**
 * Sets the current branch. The current branch is used to resolve inter-persistent-root references
 * when no explicit branch is named.
 */
- (void) setCurrentBranch: (ETUUID *)aBranch
        forPersistentRoot: (ETUUID *)aRoot;

- (void) createBranchWithUUID: (ETUUID *)branchUUID
              initialRevision: (ETUUID *)revId
            forPersistentRoot: (ETUUID *)aRoot;

/**
 * All-in-one method for updating the current revision of a persistent root.
 */
- (void) setCurrentRevision: (ETUUID *)currentRev
			   headRevision: (ETUUID *)headRev
                  forBranch: (ETUUID *)aBranch
           ofPersistentRoot: (ETUUID *)aRoot;

- (void) setMetadata: (NSDictionary *)metadata
           forBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot;

/** @taskunit Persistent Root Deletion */

/**
 * Marks the given persistent root as deleted, can be reverted by -undeletePersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (void) deletePersistentRoot: (ETUUID *)aRoot;

/**
 * Unmarks the given persistent root as deleted
 */
- (void) undeletePersistentRoot: (ETUUID *)aRoot;

/**
 * Marks the given branch of the persistent root as deleted, can be reverted by -undeleteBranch:ofPersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (void) deleteBranch: (ETUUID *)aBranch
     ofPersistentRoot: (ETUUID *)aRoot;

/**
 * Unmarks the given branch of a persistent root as deleted
 */
- (void) undeleteBranch: (ETUUID *)aBranch
       ofPersistentRoot: (ETUUID *)aRoot;

@end
