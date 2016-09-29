/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COBranch.h>

NS_ASSUME_NONNULL_BEGIN

@interface COBranch ()

/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (instancetype)initWithUUID: (ETUUID *)aUUID
              persistentRoot: (COPersistentRoot *)aPersistentRoot
            parentBranchUUID: (nullable ETUUID *)aParentBranchUUID
  parentRevisionForNewBranch: (nullable ETUUID *)parentRevisionForNewBranch NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) COSQLiteStore *store;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)updateWithBranchInfo: (COBranchInfo *)branchInfo
                   compacted: (BOOL)wasCompacted;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, readonly, strong) COBranchInfo *branchInfo;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, readonly, getter=isDeletedInStore) BOOL deletedInStore;
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
- (void)saveCommitWithMetadata: (nullable NSDictionary<NSString *, id> *)metadata
                   transaction: (COStoreTransaction *)txn;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)saveDeletionWithTransaction: (COStoreTransaction *)txn;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, readonly, getter=isBranchUncommitted) BOOL branchUncommitted;
@property (nonatomic, readonly, getter=isBranchPersistentRootUncommitted) BOOL branchPersistentRootUncommitted;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)updateRevisions: (BOOL)reload;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * A head revision change is saved on the next branch commit.
 */
@property (nonatomic, readwrite, nullable) CORevision *headRevision;

@property (nonatomic, readonly, strong) COObjectGraphContext *objectGraphContextWithoutUnfaulting;
@property (nonatomic, readonly) BOOL objectGraphContextHasChanges;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Same as -setCurrentRevision:, but doesn't check the supportsRevert
 * property. This is used by COSynchronizerServer/COSynchronizerClient,
 * which need to violate the supportsRevert flag.
 *
 * The public API -setCurrentRevision: uses this method.
 */
- (void)setCurrentRevisionSkipSupportsRevertCheck: (CORevision *)currentRevision;

@end

NS_ASSUME_NONNULL_END