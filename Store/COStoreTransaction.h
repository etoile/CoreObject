/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@protocol COStoreAction;

NS_ASSUME_NONNULL_BEGIN

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

@property (nonatomic, readonly, strong) NSMutableArray<id <COStoreAction>> *operations;

/** @taskunit Transaction ID */

@property (nonatomic, readonly) NSArray<ETUUID *> *persistentRootUUIDs;

/**
 * Returns YES if this transaction contains an action affecting the mutable
 * state of the persistent root with the given UUID. i.e., an action other
 * than writing a revision. Otherwise, returns NO.
 */
- (BOOL)touchesMutableStateForPersistentRootUUID: (ETUUID *)aUUID;
- (int64_t)oldTransactionIDForPersistentRoot: (ETUUID *)aPersistentRoot;
- (BOOL)hasOldTransactionIDForPersistentRoot: (ETUUID *)aPersistentRoot;
/**
 * The value oldID MUST be one that was previously a committed state of the
 * persistent root. In particular, it is illegal to pass an oldID value 
 * returned from a -setOldTransactionID:forPersistentRoot: call of a previously
 * submitted transaction that you have not yet received confirmation from the
 * store as being committed.
 */
- (int64_t)setOldTransactionID: (int64_t)oldID forPersistentRoot: (ETUUID *)aPersistentRoot;


/** @taskunit Revision Writing */


- (void)writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                          revisionUUID: (ETUUID *)aRevisionUUID
                              metadata: (nullable NSDictionary<NSString *, id> *)metadata
                      parentRevisionID: (nullable ETUUID *)aParent
                 mergeParentRevisionID: (nullable ETUUID *)aMergeParent
                    persistentRootUUID: (ETUUID *)aUUID
                            branchUUID: (ETUUID *)branch;


/** @taskunit Persistent Root Creation */


- (void)createPersistentRootWithUUID: (ETUUID *)persistentRootUUID
               persistentRootForCopy: (nullable ETUUID *)persistentRootForCopyUUID;
/**
 * Convenience method
 */
- (COPersistentRootInfo *)createPersistentRootCopyWithUUID: (ETUUID *)uuid
                                  parentPersistentRootUUID: (nullable ETUUID *)aParentPersistentRoot
                                                branchUUID: (ETUUID *)aBranchUUID
                                          parentBranchUUID: (nullable ETUUID *)aParentBranch
                                       initialRevisionUUID: (ETUUID *)aRevision;
/**
 * Convenience method
 */
- (COPersistentRootInfo *)createPersistentRootWithInitialItemGraph: (COItemGraph *)contents
                                                              UUID: (ETUUID *)persistentRootUUID
                                                        branchUUID: (ETUUID *)aBranchUUID
                                                  revisionMetadata: (nullable NSDictionary<NSString *, id> *)metadata;


/** @taskunit Persistent Root Modification */


/**
 * Sets the current branch. The current branch is used to resolve inter-persistent-root references
 * when no explicit branch is named.
 */
- (void)setCurrentBranch: (ETUUID *)aBranch
       forPersistentRoot: (ETUUID *)aRoot;
- (void)createBranchWithUUID: (ETUUID *)branchUUID
                parentBranch: (nullable ETUUID *)aParentBranch
             initialRevision: (ETUUID *)revId
           forPersistentRoot: (ETUUID *)aRoot;
/**
 * All-in-one method for updating the current revision of a persistent root.
 * You can pass nil for headRev to not change the headRev.
 */
- (void)setCurrentRevision: (ETUUID *)currentRev
              headRevision: (nullable ETUUID *)headRev
                 forBranch: (ETUUID *)aBranch
          ofPersistentRoot: (ETUUID *)aRoot;
- (void)setMetadata: (nullable NSDictionary<NSString *, id> *)metadata
          forBranch: (ETUUID *)aBranch
   ofPersistentRoot: (ETUUID *)aRoot;
- (void)setMetadata: (nullable NSDictionary<NSString *, id> *)metadata
  forPersistentRoot: (ETUUID *)aRoot;


/** @taskunit Persistent Root Deletion */


/**
 * Marks the given persistent root as deleted, can be reverted by -undeletePersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (void)deletePersistentRoot: (ETUUID *)aRoot;
/**
 * Unmarks the given persistent root as deleted
 */
- (void)undeletePersistentRoot: (ETUUID *)aRoot;
/**
 * Marks the given branch of the persistent root as deleted, can be reverted by -undeleteBranch:ofPersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (void)deleteBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot;
/**
 * Unmarks the given branch of a persistent root as deleted
 */
- (void)undeleteBranch: (ETUUID *)aBranch
      ofPersistentRoot: (ETUUID *)aRoot;


/** @taskunit Querying For Changes in the Transaction */


/**
 * Returns the last current revision set for a branch in the transaction.
 * Note that the transaction contents are ordered, so a branch could
 * be set to r1 earlier in the transaction, and later set to r2.
 *
 * Returns nil if the branch's current revision is not modified in this transaction.
 */
- (nullable ETUUID *)lastSetCurrentRevisionInTransactionForBranch: (ETUUID *)aBranch
                                                 ofPersistentRoot: (ETUUID *)aRoot;

@end

NS_ASSUME_NONNULL_END
