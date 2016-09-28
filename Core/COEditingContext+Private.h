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

/**
 * This property is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, readwrite, assign, getter=isRecordingUndo) BOOL recordingUndo;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COPersistentRoot *)insertNewPersistentRootWithRevisionUUID: (ETUUID *)aRevid
                                                 parentBranch: (COBranch *)aParentBranch;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
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
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits the current changes to the store with the provided metadatas and
 * returns the resulting revisions.
 */
- (BOOL)commitWithMetadata: (nullable NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
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
/**
 * This property is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, readonly) COCrossPersistentRootDeadRelationshipCache *deadRelationshipCache;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (id)crossPersistentRootReferenceWithPath: (COPath *)aPath shouldLoad: (BOOL)shouldLoad;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)updateCrossPersistentRootReferencesToPersistentRoot: (COPersistentRoot *)aPersistentRoot
                                                     branch: (nullable COBranch *)aBranch
                                                    isFault: (BOOL)faulting;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)deletePersistentRoot: (COPersistentRoot *)aPersistentRoot;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)undeletePersistentRoot: (COPersistentRoot *)aPersistentRoot;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (nullable CORevision *)revisionForRevisionUUID: (ETUUID *)aRevid
                              persistentRootUUID: (ETUUID *)aPersistentRoot;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (nullable COBranch *)branchForUUID: (ETUUID *)aBranch;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (nullable NSNumber *)lastTransactionIDForPersistentRootUUID: (ETUUID *)aUUID;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)setLastTransactionID: (int64_t)lastTransactionID forPersistentRootUUID: (ETUUID *)aUUID;

@end

NS_ASSUME_NONNULL_END
