/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COPersistentRoot.h>

@class COStoreTransaction;

@interface COPersistentRoot ()

/** @taskunit Framework Private */

@property (nonatomic, assign) int64_t lastTransactionID;

/**
 * <init />
 * This method is only exposed to be used internally by CoreObject.
 *
 * If info is nil, creates a new persistent root.
 *
 * cheapCopyRevisionID is normally nil, and only set to create a cheap copy.
 * See -[COBranch makeCopyFromRevision:]
 */
- (id) initWithInfo: (COPersistentRootInfo *)info
cheapCopyRevisionUUID: (ETUUID *)cheapCopyRevisionID
cheapCopyPersistentRootUUID: (ETUUID *)cheapCopyPersistentRootID
   parentBranchUUID: (ETUUID *)aBranchUUID
 objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
      parentContext: (COEditingContext *)aCtxt;

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits the current changes to the store with the provided metadatas and
 * returns the resulting revision.
 *
 * The commit procedure is the parent context responsability, the parent context
 * calls back -saveCommitWithMetadata:.
 */
- (BOOL)commitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Extracts the current changes, saves them to the store with the provided
 * metadatas and returns the resulting revision.
 */
- (void) saveCommitWithMetadata: (NSDictionary *)metadata transaction: (COStoreTransaction *)txn;

- (COPersistentRootInfo *) persistentRootInfo;

- (void)didMakeNewCommit;

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev parentBranch: (COBranch *)aParent;

- (COBranch *)makeBranchWithUUID: (ETUUID *)aUUID metadata: (NSDictionary *)metadata atRevision: (CORevision *)aRev parentBranch: (COBranch *)aParent;

- (BOOL) isPersistentRootUncommitted;

- (void)storePersistentRootDidChange: (NSNotification *)notif isDistributed: (BOOL)isDistributed;

- (void) sendChangeNotification;

- (void)deleteBranch: (COBranch *)aBranch;
- (void)undeleteBranch: (COBranch *)aBranch;

@end
