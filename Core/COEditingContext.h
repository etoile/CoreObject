/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COPersistentObjectContext.h>

@class COSQLiteStore, COEditingContext, COPersistentRoot, COBranch, COObjectGraphContext, COObject;
@class COUndoTrack, COCommandGroup;

/**
 * @group Core
 * @abstract An editing context exposes an in-memory snapshot of a CoreObject store,
 * allows the user to queue changes in memory and commit them atomically.
 * 
 * This functionality is split across the classes COEditingContext, which handles
 * persistent root insertion and deletion as well as general information about the
 * store, COPersistentRoot, which handles state specific to a persistent root - 
 * the metadata, the current branch, COBranch, which handles the state of a branch
 * and COObjectGraphContext, which finally exposes the snapshot of inner objects
 * in a branch and queues changes.
 *
 * @section Object Equality
 *
 * COEditingContext, COPersistentRoot, COBranch, and COObjectGraphContext
 * do not override -hash or -isEqual:, so instances of these classes are only
 * considered equal to the same instances.
 *
 * These classes form an in-memory view on a database, and the notion
 * of two of these views being equal isn't useful or interesting.
 *
 * @section Commits
 *
 * In the current implementation, all changes made in a COEditingContext are
 * committed atomically. However, it is best to think of atomicity only existing
 * per-persistent root, since persistent roots are the units of versioning.
 *
 * We usually advice to commit a single persistent root at time to prevent
 * multiple revisions per commit. In this way, you can provide precise undo/redo
 * support matching the user expectations.
 */
@interface COEditingContext : NSObject <COPersistentObjectContext>
{
	@private
	COSQLiteStore *_store;
	ETModelDescriptionRepository *_modelRepository;
	/** Loaded (or inserted) persistent roots by UUID */
	NSMutableDictionary *_loadedPersistentRoots;
    /** Set of persistent roots pending deletion */
	NSMutableSet *_persistentRootsPendingDeletion;
    /** Set of persistent roots pending undeletion */
	NSMutableSet *_persistentRootsPendingUndeletion;
    /** Undo */
    BOOL _isRecordingUndo;
    COCommandGroup *_currentEditGroup;
}


/** @taskunit Creating a New Context */


/**
 * Returns a new autoreleased context initialized with the store located at the 
 * given URL.
 *
 * See also -initWithStore: and -[COSQLiteStore initWithURL:].
 */
+ (COEditingContext *)contextWithURL: (NSURL *)aURL;
/**
 * Initializes a context which persists its content in the given store.
 *
 * The model repository is set to -[ETModelDescription mainRepository].
 *
 * See also -initWithStore:modelRepository:.
 */
- (id)initWithStore: (COSQLiteStore *)store;
/**
 * <init />
 * Initializes a context which persists its content in the given store, and 
 * manages it using the metamodel provided by the model description repository.
 *
 * For a nil model repository, or a repository that doesn't a COObject entity 
 * description, raises a NSInvalidArgumentException.
 */
- (id)initWithStore: (COSQLiteStore *)store
    modelRepository: (ETModelDescriptionRepository *)aRepo;
/**
 * Initializes the context with no store. 
 * As a result, the context content is not persisted.
 *
 * See also -initWithStore:.
 */
- (id)init;


/** @taskunit Accessing All Persistent Roots */


/**
 * Returns all persistent roots in the store (excluding those that are marked as 
 * deleted on disk), plus those pending insertion and undeletion (and minus 
 * those pending deletion).
 */
@property (nonatomic, readonly) NSSet *persistentRoots;
/**
 * Returns persistent roots marked as deleted on disk, excluding those that
 * are pending undeletion.
 *
 * -persistentRootsPendingDeletion are not included in the returned set.
 */
@property (nonatomic, readonly) NSSet *deletedPersistentRoots;


/** @taskunit Store and Metamodel Access */


/**
 * Returns the store for which the editing context acts a working copy.
 */
@property (nonatomic, readonly, strong) COSQLiteStore *store;
/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the persistent objects editable in the context.
 */
@property (nonatomic, readonly, strong) ETModelDescriptionRepository *modelRepository;


/** @taskunit Managing Persistent Roots */


/**
 * Returns the persistent root bound the the given UUID in the store or nil.
 *
 * The editing context retains the returned persistent root.
 */
- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)aUUID;
/**
 * Returns a new persistent root that uses the given root object.
 *
 * The returned persistent root is added to -persistentRootsPendingInsertion 
 * and will be saved to the store on the next commit.
 *
 * The object graph context of the root object must be transient, otherwise 
 * a NSInvalidArgumentException is raised.
 *
 * For a nil root object, raises a NSInvalidArgumentException.
 */
- (COPersistentRoot *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject;
/**
 * Creates a root object of the requested entity and returns a new persistent
 * root using that root object.
 */
- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName;


/** @taskunit Pending Changes */

/**
 * The new persistent roots to be saved in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *persistentRootsPendingInsertion;
/**
 * The persistent roots to be deleted in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *persistentRootsPendingDeletion;
/**
 * The persistent roots to be undeleted in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *persistentRootsPendingUndeletion;
/**
 * The persistent roots to be updated in the store on the next commit.
 */
@property (nonatomic, readonly) NSSet *persistentRootsPendingUpdate;
/**
 * Returns whether the context contains uncommitted changes.
 *
 * Persistent root insertions, deletions, undeletions, and modifications (e.g., 
 * changing main branch, deleting branches, adding branches, editing branch 
 * metadata, reverting branch to a past revision) all count as uncommitted 
 * changes.
 *
 * See also -discardAllChanges and -[COPersistentRoot hasChanges].
 */
- (BOOL)hasChanges;
/**
 * Discards the uncommitted changes to reset the context to its last commit state.
 *
 * Persistent root insertions, deletions, undeletions and modifications (e.g., 
 * changing main branch, deleting branches, adding branches, editing branch 
 * metadata, reverting branch to a past revision) will be cancelled.
 *
 * All uncommitted inner object edits in child persistent roots will be
 * cancelled.
 *
 * -persistentRootsPendingInsertion, -persistentRootsPendingDeletion, 
 * -persistentRootsPendingUndeletion and -persistentRootsPendingUpdate  will all 
 * return empty sets once the changes have been discarded.
 *
 * See also -hasChanges and -[COPersistentRoot discardAllChanges].
 */
- (void)discardAllChanges;


/** @taskunit Committing Changes */

/**
 * Commits the current changes to the store bound to a commit descriptor
 * identifier, and returns whether it succeeds.
 *
 * See -commitWithIdentitifer:metadata:undoTrack:error.
 */
- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
				   undoTrack: (COUndoTrack *)undoTrack
                       error: (NSError **)anError;
/**
 * Commits the current changes to the store, bound to a commit descriptor 
 * identifier along the additional metadatas, and returns whether it 
 * succeeds.
 *
 * The metadata dictionary must be a valid property list or nil, otherwise a
 * serialization exception is raised.
 *
 * If the method returns NO, the error argument is set, otherwise it is nil.
 *
 * One or more undo tracks can be passed to record the commit as a command.
 *
 * For programs exposing the history to an end user, you must use this method 
 * that supports history localization through COCommitDescriptor and not 
 * -commitWithMetadata:undoTrack:error:.
 *
 * See COCommitDescriptor to understand how the localization works.
 */
- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
					metadata: (NSDictionary *)additionalMetadata
				   undoTrack: (COUndoTrack *)undoTrack
                       error: (NSError **)anError;
/**
 * Commits the current changes to the store along the metadatas and returns 
 * whether it succeeds.
 *
 * The metadata dictionary must be a valid JSON object or nil, otherwise a 
 * serialization exception is raised.
 *
 * If the method returns NO, the error argument is set, otherwise it is nil.
 *
 * One or more undo tracks can be passed to record the commit as a command.
 *
 * For programs exposing the history to an end user, you must not use this 
 * method, but -commitWithIdentifier:metadata:undoTrack:error: or 
 * -commitWithIdentifier:undoTrack:error: that both support history 
 * localization through COCommitDescriptor.
 */
- (BOOL)commitWithMetadata: (NSDictionary *)metadata
				 undoTrack: (COUndoTrack *)undoTrack
                     error: (NSError **)anError;
/**
 * Commits the current changes to the store and returns whether it succeeds.
 *
 * You should avoid using this method in release code, it is mainly useful for 
 * debugging and quick development.
 *
 * See also -commitWithMetadata:undoTrack:error:.
 */
- (BOOL)commit;
/**
 * Commits the current changes to the store, records them on the undo track and 
 * returns whether it succeeds.
 * 
 * You should avoid using this method in release code, it is mainly useful for
 * debugging and quick development.
 *
 *  See also -commitWithMetadata:undoTrack:error:.
 */
- (BOOL)commitWithUndoTrack: (COUndoTrack *)aStack;


/** @taskunit Deprecated */


/**
 * Commits the current changes to the store with some basic metadatas and 
 * returns whether it succeeds.
 *
 * The description will be visible at the UI level when browsing the history.
 *
 * See -commitWithMetadata:undoTrack:error:.
 */
- (BOOL)commitWithType: (NSString *)type
      shortDescription: (NSString *)shortDescription;
/**
 * Returns YES.
 *
 * See also -[NSObject isEditingContext].
 */
@property (nonatomic, readonly) BOOL isEditingContext;
/**
 * Returns self.
 *
 * See also -[COPersistentObjectContext editingContext].
 */
@property (nonatomic, readonly) COEditingContext *editingContext;

@end

/**
 * Posted when any changes are committed to this editing context root, including
 * changes committed in another process.
 *
 * The userInfo dictionary contains the command produced by the commit, under 
 * the key kCOCommandKey. For a  commit was produced by an undo/redo action 
 * (see COUndoTrack) or changes committed in another processes, the dictionary 
 * doesn't contain the command.<br />
 * The kCOCommandKey object is provided just for debugging purpose (e.g. to log 
 * each commit done locally, while not reporting concurrent commits from other 
 * processes that trigger an automatic reloading).
 *
 * The sender is the affected COEditingContext object.
 */
extern NSString * const COEditingContextDidChangeNotification;
/**
 * See userInfo explanation in COEditingContextDidChangeNotification.
 */
extern NSString * const kCOCommandKey;
