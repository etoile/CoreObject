/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import <CoreObject/COBranch.h>

@interface COBranch ()

/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (id)        initWithUUID: (ETUUID *)aUUID
        objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
            persistentRoot: (COPersistentRoot *)aPersistentRoot
          parentBranchUUID: (ETUUID *)aParentBranchUUID
parentRevisionForNewBranch: (ETUUID *)parentRevisionForNewBranch;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)updateWithBranchInfo: (COBranchInfo *)branchInfo;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COBranchInfo *)branchInfo;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Forces the branch to reload an older or more recent state.
 *
 * The public API -setCurrentRevision: uses this method.
 */
- (void)reloadAtRevision: (CORevision *)revision;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)didMakeInitialCommitWithRevisionID: (ETUUID *)aRevisionID
                               transaction: (COStoreTransaction *)txn;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void) saveCommitWithMetadata: (NSDictionary *)metadata
                    transaction: (COStoreTransaction *)txn;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)saveDeletionWithTransaction: (COStoreTransaction *)txn;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (BOOL) isBranchUncommitted;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)updateRevisions;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
@property (nonatomic) CORevision *headRevision;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Searches for whether the given revision is on this branch.
 * Returns the corresponding CORevision if it is, or nil if not.
 *
 * Note that this means nil will be returned if the given revision is not on
 * this branch, even if it on another branch of this persistent root.
 */
- (CORevision *) revisionWithUUID: (ETUUID *)aRevisionID;

@end
