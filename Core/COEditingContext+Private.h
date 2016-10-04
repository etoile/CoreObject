/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COEditingContext.h>
#import <CoreObject/CORevision.h>

@class COCrossPersistentRootDeadRelationshipCache, COPath, COUndoTrack;

NS_ASSUME_NONNULL_BEGIN

@interface COEditingContext ()


/** @taskunit Undo Integration */


@property (nonatomic, readwrite, assign, getter=isRecordingUndo) BOOL recordingUndo;


/** @taskunit Managing Persistent Roots */


- (COPersistentRoot *)insertNewPersistentRootWithRevisionUUID: (ETUUID *)aRevid
                                                 parentBranch: (COBranch *)aParentBranch;
/**
 * Instantiates, registers among the loaded persistent roots and returns the
 * persistent root known by the given UUID.
 * Unlike -persistentRootForUUID:, this method doesn't access the store to
 * retrieve the main branch UUID, but just use the given commit track UUID.
 *
 * In addition, a past revision can be passed to prevent loading the persistent
 * root at the latest revision.
 */
- (COPersistentRoot *)makePersistentRootWithInfo: (nullable COPersistentRootInfo *)info
                              objectGraphContext: (nullable COObjectGraphContext *)anObjectGraphContext;
- (void)deletePersistentRoot: (COPersistentRoot *)aPersistentRoot;
- (void)undeletePersistentRoot: (COPersistentRoot *)aPersistentRoot;


/** @taskunit Committing Changes */


/**
 * Commits the current changes to the store with the provided metadatas and
 * returns the resulting revisions.
 */
- (BOOL)commitWithMetadata: (nullable NSDictionary *)metadata;
/**
 * Commits some changes to the store with the provided metadatas, and returns
 * the resulting revisions.
 *
 * Changes must belong to the given persistent root subset, otherwise they
 * won't be committed. -hasChanges can still be YES on return.
 */
- (BOOL) commitWithMetadata: (nullable NSDictionary *)metadata
restrictedToPersistentRoots: (nullable NSArray *)persistentRoots
              withUndoTrack: (nullable COUndoTrack *)track
                      error: (COError *_Nullable *_Nullable)anError;


/** @taskunit Cross Persistent Root References */


@property (nonatomic, readonly) COCrossPersistentRootDeadRelationshipCache *deadRelationshipCache;

- (id)crossPersistentRootReferenceWithPath: (COPath *)aPath shouldLoad: (BOOL)shouldLoad;
- (void)updateCrossPersistentRootReferencesToPersistentRoot: (COPersistentRoot *)aPersistentRoot
                                                     branch: (nullable COBranch *)aBranch
                                                    isFault: (BOOL)faulting;


/** @taskunit Accessing Store Revisions and Branches */


- (nullable CORevision *)revisionForRevisionUUID: (ETUUID *)aRevid
                              persistentRootUUID: (ETUUID *)aPersistentRoot;
- (nullable COBranch *)branchForUUID: (ETUUID *)aBranch;


/** @taskunit Transaction IDs */


- (nullable NSNumber *)lastTransactionIDForPersistentRootUUID: (ETUUID *)aUUID;
- (void)setLastTransactionID: (int64_t)lastTransactionID forPersistentRootUUID: (ETUUID *)aUUID;

@end

NS_ASSUME_NONNULL_END
