/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  August 2013
	License:  Modified BSD  (see COPYING)
 */

#import <CoreObject/COPersistentRoot.h>

@interface COPersistentRoot ()

/** @taskunit Framework Private */

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
cheapCopyRevisionID: (CORevisionID *)cheapCopyRevisionID
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
- (CORevision *)commitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Extracts the current changes, saves them to the store with the provided
 * metadatas and returns the resulting revision.
 */
- (void) saveCommitWithMetadata: (NSDictionary *)metadata transactionUUID: (ETUUID *)transactionUUID;

- (COPersistentRootInfo *) persistentRootInfo;

- (void) reloadPersistentRootInfo;

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev parentBranch: (COBranch *)aParent;

- (COBranch *)makeBranchWithUUID: (ETUUID *)aUUID metadata: (NSDictionary *)metadata atRevision: (CORevision *)aRev parentBranch: (COBranch *)aParent;

- (BOOL) isPersistentRootUncommitted;

- (void)storePersistentRootDidChange: (NSNotification *)notif;

- (void) updateCrossPersistentRootReferences;

- (void) sendChangeNotification;

- (void)deleteBranch: (COBranch *)aBranch;
- (void)undeleteBranch: (COBranch *)aBranch;
 
@end