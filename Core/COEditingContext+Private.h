/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  August 2013
	License:  Modified BSD  (see COPYING)
 */

#import <CoreObject/COEditingContext.h>

@class COUndoTrack;

@interface COEditingContext ()

@property (readwrite, nonatomic) BOOL isRecordingUndo;

/**
 * @taskunit Framework Private
 */

/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COPersistentRoot *)insertNewPersistentRootWithRevisionID: (CORevisionID *)aRevid;
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
 */
- (void)didFailValidationWithError: (NSError *)anError;
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
- (COCrossPersistentRootReferenceCache *) crossReferenceCache;

- (CORevision *) revisionForRevisionID: (CORevisionID *)aRevid;

@end

@interface COEditingContext (Debugging)

/**
 * @taskunit Loaded Objects
 */

/**
 * Returns the objects presently managed by the receiver in memory.
 *
 * The returned objects include -insertedObjects.
 *
 * Faults can be included among the returned objects.
 *
 * See also -loadedObjectUUIDs.
 */
- (NSSet *)loadedObjects;
/**
 * Returns the root objects presently managed by the receiver in memory.
 *
 * Faults and inserted objects can be included among the returned objects.
 *
 * The returned objects are a subset of -loadedObjects.
 */
- (NSSet *)loadedRootObjects;

/**
 * @taskunit Pending Changes
 */

/**
 * Returns the new objects added to the context with -insertObject: and to be
 * added to the store on the next commit.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)insertedObjects;
/**
 * Returns the objects whose properties have been edited in the context and to
 * be updated in the store on the next commit.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)updatedObjects;
/**
 * Returns the union of the inserted and updated objects. See -insertedObjects
 * and -updatedObjects.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)changedObjects;

@end
