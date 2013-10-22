#import <CoreObject/CoreObject.h>

/**
 * Builder object for creating a batch of changes to write to the store.
 *
 * For every persistent root that you modify in the transaction, you must
 * call -setOldTransactionID:forPersistentRoot:, and at commit time,
 * the value you pass for oldID must match the last transaction ID recorded
 * in the store or your commit will be rejected (this is expected to happen
 * when process A sends a transaction to the store after process B has successfully
 * made a commit, but before process A has had a chance to load process B's 
 * changes into memory)
 *
 * As an exception, the value you pass for oldID doesn't matter if the persistent
 * root is created by this transaction. Just pass -1.
 */
@interface COStoreTransaction : NSObject
{
	NSMutableDictionary *_oldTransactionIDForPersistentRootUUID;
}

@property (nonatomic, readonly, strong) NSMutableArray *operations;

/** @taskunit Transaction ID */

- (NSArray *) persistentRootUUIDs;

- (int64_t) oldTransactionIDForPersistentRoot: (ETUUID *)aPersistentRoot;

/**
 * The value oldID MUST be one that was previously a committed state of the
 * persistent root. In particular, it is illegal to pass an oldID value 
 * returned from a -setOldTransactionID:forPersistentRoot: call of a previously
 * submitted transaction that you have not yet received confirmation from the
 * store as being committed.
 */
- (int64_t) setOldTransactionID: (int64_t)oldID forPersistentRoot: (ETUUID *)aPersistentRoot;

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


/**
 * Convenience method
 */
- (COPersistentRootInfo *) createPersistentRootCopyWithUUID: (ETUUID *)uuid
								   parentPersistentRootUUID: (ETUUID *)aParentPersistentRoot
												 branchUUID: (ETUUID *)aBranchUUID
										   parentBranchUUID: (ETUUID *)aParentBranch
										initialRevisionUUID: (ETUUID *)aRevision;

/**
 * Convenience method
 */
- (COPersistentRootInfo *) createPersistentRootWithInitialItemGraph: (COItemGraph *)contents
                                                               UUID: (ETUUID *)persistentRootUUID
                                                         branchUUID: (ETUUID *)aBranchUUID
                                                   revisionMetadata: (NSDictionary *)metadata;

/** @taskunit Persistent Root Modification */

/**
 * Sets the current branch. The current branch is used to resolve inter-persistent-root references
 * when no explicit branch is named.
 */
- (void) setCurrentBranch: (ETUUID *)aBranch
        forPersistentRoot: (ETUUID *)aRoot;

- (void) createBranchWithUUID: (ETUUID *)branchUUID
				 parentBranch: (ETUUID *)aParentBranch
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
