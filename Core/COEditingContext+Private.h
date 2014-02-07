/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COEditingContext.h>

@class COPath, COUndoTrack;

@interface COEditingContext ()

/**
 * This property is only exposed to be used internally by CoreObject.
 */
@property (nonatomic, assign) BOOL isRecordingUndo;
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
- (COPersistentRoot *)makePersistentRootWithInfo: (COPersistentRootInfo *)info
                              objectGraphContext: (COObjectGraphContext *)anObjectGraphContext;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits the current changes to the store with the provided metadatas and
 * returns the resulting revisions.
 */
- (BOOL)commitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Commits some changes to the store with the provided metadatas, and returns
 * the resulting revisions.
 *
 * Changes must belong to the given persistent root subset, otherwise they
 * won't be committed. -hasChanges can still be YES on return.
 */
- (BOOL)commitWithMetadata: (NSDictionary *)metadata
restrictedToPersistentRoots: (NSArray *)persistentRoots
			 withUndoTrack: (COUndoTrack *)track
					 error: (NSError **)anError;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (id)crossPersistentRootReferenceWithPath: (COPath *)aPath;
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
- (CORevision *)revisionForRevisionUUID: (ETUUID *)aRevid
                     persistentRootUUID: (ETUUID *)aPersistentRoot;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COBranch *)branchForUUID: (ETUUID *)aBranch;

@end
