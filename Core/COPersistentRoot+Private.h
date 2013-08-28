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
- (void) saveCommitWithMetadata: (NSDictionary *)metadata;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the class that represents a reference to the provided root object
 * argument.
 *
 * Valid reference kinds are COCommitTrack and COPersistentRoot classes.
 *
 * The root object argument must be belong to another persistent root, otherwise
 * NSInvalidArgumentException is raised.
 */
- (Class)referenceClassForRootObject: (COObject *)aRootObject;

- (COPersistentRootInfo *) persistentRootInfo;

- (void) reloadPersistentRootInfo;

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev;

- (COBranch *)makeBranchWithUUID: (ETUUID *)aUUID metadata: (NSDictionary *)metadata atRevision: (CORevision *)aRev;

- (BOOL) isPersistentRootCommitted;

- (void)storePersistentRootDidChange: (NSNotification *)notif;

- (void) updateCrossPersistentRootReferences;

- (void) sendChangeNotification;


@end