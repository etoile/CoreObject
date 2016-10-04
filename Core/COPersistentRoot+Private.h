/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COPersistentRoot.h>

@class COStoreTransaction;

NS_ASSUME_NONNULL_BEGIN

/**
 * Metadata dictionary key used by the `name` property.
 */
extern NSString *const COPersistentRootName;

@interface COPersistentRoot ()


/** @taskunit Initialization */


/**
 * <init />
 * If info is nil, creates a new persistent root.
 *
 * cheapCopyRevisionID is normally nil, and only set to create a cheap copy.
 * See -[COBranch makeCopyFromRevision:]
 */
- (instancetype)initWithInfo: (nullable COPersistentRootInfo *)info
       cheapCopyRevisionUUID: (nullable ETUUID *)cheapCopyRevisionID
 cheapCopyPersistentRootUUID: (nullable ETUUID *)cheapCopyPersistentRootID
            parentBranchUUID: (nullable ETUUID *)aBranchUUID
          objectGraphContext: (nullable COObjectGraphContext *)anObjectGraphContext
               parentContext: (COEditingContext *)aCtxt NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, strong) COPersistentRootInfo *persistentRootInfo;
@property (nonatomic, readonly, getter=isPersistentRootUncommitted) BOOL persistentRootUncommitted;


/** @taskunit Committing Changes */


/**
 * Commits the current changes to the store with the provided metadatas and
 * returns the resulting revision.
 *
 * The commit procedure is the parent context responsability, the parent context
 * calls back -saveCommitWithMetadata:.
 */
- (BOOL)commitWithMetadata: (nullable NSDictionary<NSString *, id> *)metadata;
/**
 * Extracts the current changes, saves them to the store with the provided
 * metadatas and returns the resulting revision.
 */
- (void)saveCommitWithMetadata: (nullable NSDictionary<NSString *, id> *)metadata
                   transaction: (COStoreTransaction *)txn;
/**
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
- (void)didMakeNewCommit;


/** @taskunit Branches */


/**
 * This property is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, readonly) NSSet<COBranch *> *allBranches;

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel
                       atRevision: (CORevision *)aRev
                     parentBranch: (COBranch *)aParent;
- (COBranch *)makeBranchWithUUID: (ETUUID *)aUUID
                        metadata: (nullable NSDictionary<NSString *, id> *)metadata
                      atRevision: (CORevision *)aRev
                    parentBranch: (COBranch *)aParent;
- (void)deleteBranch: (COBranch *)aBranch;
- (void)undeleteBranch: (COBranch *)aBranch;


/** @taskunit Notifications */


- (void)storePersistentRootDidChange: (NSNotification *)notif isDistributed: (BOOL)isDistributed;
- (void)sendChangeNotification;


/** @taskunit Transaction ID */


@property (nonatomic, readwrite, assign) int64_t lastTransactionID;


/** @taskunit Zombie Status */


- (void)assertNotZombie;
- (void)makeZombie;

@end

NS_ASSUME_NONNULL_END
