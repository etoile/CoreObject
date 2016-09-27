/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COPersistentRoot.h>

/**
 * Metadata dictionary key used by the `name` property.
 */
extern NSString * const COPersistentRootName;

@class COStoreTransaction;

@interface COPersistentRoot ()

/** @taskunit Framework Private */

@property (nonatomic, readwrite, assign) int64_t lastTransactionID;

/**
 * <init />
 * This method is only exposed to be used internally by CoreObject.
 *
 * If info is nil, creates a new persistent root.
 *
 * cheapCopyRevisionID is normally nil, and only set to create a cheap copy.
 * See -[COBranch makeCopyFromRevision:]
 */
- (instancetype) initWithInfo: (COPersistentRootInfo *)info
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
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * We must clear the branch status as late as possible to ensure the
 * deserialization code can decide whether references to another persistent root 
 * are alive or dead at any time during the commit.
 *
 * If we clear the branch status too early when preparing a persistent root
 * commit is done with -saveCommitWithMetadata:transaction:, then this branch 
 * will appear with an opposite status when the deserialization code checks it
 * with -[COBranch isDeleted] (the deserialization being requested by another
 * persistent root processed afterwards in the same commit).
 *
 * This situation will arise when cross persistent root references updated 
 * usually on the initial status change, are updated in the current branch at
 * commit time. The commit code applies the tracking branch item graph
 * containing the fixed references to the non-tracking current branch. For 
 * updating cross persistent root references at commit time, each branch will
 * access other persistent roots and branches, and this requires to maintain a 
 * coherent view until the store transaction is constructed.
 */
- (void)clearBranchesPendingDeletionAndUndeletion;
@property (nonatomic, readonly, strong) COPersistentRootInfo *persistentRootInfo;

- (void)didMakeNewCommit;

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev parentBranch: (COBranch *)aParent;

- (COBranch *)makeBranchWithUUID: (ETUUID *)aUUID metadata: (NSDictionary *)metadata atRevision: (CORevision *)aRev parentBranch: (COBranch *)aParent;

@property (nonatomic, readonly, getter=isPersistentRootUncommitted) BOOL persistentRootUncommitted;

- (void)storePersistentRootDidChange: (NSNotification *)notif isDistributed: (BOOL)isDistributed;

- (void) sendChangeNotification;

/**
 * This property is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, readonly) NSSet *allBranches;

- (void)deleteBranch: (COBranch *)aBranch;
- (void)undeleteBranch: (COBranch *)aBranch;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)assertNotZombie;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)makeZombie;
@end
