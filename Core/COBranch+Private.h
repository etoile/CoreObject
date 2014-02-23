/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COBranch.h>

@interface COBranch ()

/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (id)        initWithUUID: (ETUUID *)aUUID
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
- (void)didMakeInitialCommitWithRevisionUUID: (ETUUID *)aRevisionUUID
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
- (BOOL)isBranchUncommitted;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)updateRevisions;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * A head revision change is saved on the next branch commit.
 */
@property (nonatomic) CORevision *headRevision;

- (COObjectGraphContext *) objectGraphContextWithoutUnfaulting;
- (BOOL)objectGraphContextHasChanges;

@end
