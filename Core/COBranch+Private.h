/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COBranch.h>

NS_ASSUME_NONNULL_BEGIN

@interface COBranch ()


/** @taskunit Initialization */


- (instancetype)initWithUUID: (ETUUID *)aUUID
              persistentRoot: (COPersistentRoot *)aPersistentRoot
            parentBranchUUID: (nullable ETUUID *)aParentBranchUUID
  parentRevisionForNewBranch: (nullable ETUUID *)parentRevisionForNewBranch NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) COSQLiteStore *store;

- (void)updateWithBranchInfo: (COBranchInfo *)branchInfo
                   compacted: (BOOL)wasCompacted;

@property (nonatomic, readonly, strong) COBranchInfo *branchInfo;


/** @taskunit Status */


@property (nonatomic, readonly, getter=isDeletedInStore) BOOL deletedInStore;
@property (nonatomic, readonly, getter=isBranchUncommitted) BOOL branchUncommitted;
@property (nonatomic, readonly, getter=isBranchPersistentRootUncommitted) BOOL branchPersistentRootUncommitted;


/** @taskunit Object Graph */


@property (nonatomic, readonly, strong) COObjectGraphContext *objectGraphContextWithoutUnfaulting;
@property (nonatomic, readonly) BOOL objectGraphContextHasChanges;


/** @taskunit Committing Changes */


- (void)saveCommitWithMetadata: (nullable NSDictionary<NSString *, id> *)metadata
                   transaction: (COStoreTransaction *)txn;
- (void)saveDeletionWithTransaction: (COStoreTransaction *)txn;
- (void)didMakeInitialCommitWithRevisionUUID: (ETUUID *)aRevisionUUID
                                 transaction: (COStoreTransaction *)txn;


/** @taskunit Revisions */


/**
 * A head revision change is saved on the next branch commit.
 */
@property (nonatomic, readwrite, nullable) CORevision *headRevision;
/**
 * Same as -setCurrentRevision:, but doesn't check the supportsRevert
 * property. This is used by COSynchronizerServer/COSynchronizerClient,
 * which need to violate the supportsRevert flag.
 *
 * The public API -setCurrentRevision: uses this method.
 */
- (void)setCurrentRevisionSkipSupportsRevertCheck: (CORevision *)currentRevision;
/**
 * Forces the branch to reload an older or more recent state.
 *
 * The public API -setCurrentRevision: uses this method.
 */
- (void)reloadAtRevision: (CORevision *)revision;
- (void)updateRevisions: (BOOL)reload;

@end

NS_ASSUME_NONNULL_END