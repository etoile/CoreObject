/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COPersistentRoot, COEditingContext, COObjectGraphContext;
@class COSQLiteStore, CORevision, COObject, COGroup, COSmartGroup, COBranch, COError, COPersistentRootInfo, CORevisionID, COPath;
@class COCrossPersistentRootReferenceCache, COUndoStackStore, COCommandGroup;
@class COUndoTrack, CORevisionCache;

// I'm skeptical that there is ever a legitimate case where code is working
// with an id<COPersistentObjectContext> and doesn't know whether it's an
// editing context or persistent root... but I guess it's harmless to keep for
// now --Eric
/** 
 * Protocol to support managing either persistent roots or inner objects
 * inside an object graph context without knowing the context type in advance.
 *
 * For example, based on -[ETController persistentObjectContext:], a 
 * ETController object can instantiate either persistent roots or inner objects.
 */
@protocol COPersistentObjectContext <NSObject>
@optional
/**
 * See -[NSObject isEditingContext].
 */
- (BOOL)isEditingContext;
/**
 * See -[NSObject isObjectGraphContext].
 */
- (BOOL)isObjectGraphContext;
@required
/**
 * Returns the editing context for the receiver.
 *
 * Either returns self or a parent context.
 *
 * See COEditingContext and -[COPersistentRoot parentContext].
 */
- (COEditingContext *)editingContext;
/**
 * See -[COEditingContext discardAllChanges], -[COPersistentRoot discardAllChanges], 
 * -[COBranch discardAllChanges] and -[COObjectGraphContext discardAllChanges].
 */
- (void)discardAllChanges;
/**
 * See -[COEditingContext hasChanges], -[COPersistentRoot hasChanges], 
 *  -[COBranch hasChanges] and -[COObjectGraphContext hasChanges].
 */
- (BOOL)hasChanges;
@end

/**
 * An editing context exposes a CoreObject store snapshot as a working copy 
 * (in revision control system terminology).
 *
 * It queues changes and when the user requests it, it attempts to commit them 
 * to the store.
 *
 * FIXME: Expand
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
 * A commit involving multiple persistent roots or branches is not atomic, it 
 * results in a new revision per persistent root branch that was containing 
 * changes.
 * In addition to branch content changes that result in new revisions, a commit 
 * can create various store stucture changes (e.g. renaming a branch, deleting a 
 * persistent root) not visible in the store history. You can use COUndoTrack 
 * to record all these changes as commands.
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
	COError *_error;
    COCrossPersistentRootReferenceCache *_crossRefCache;
    CORevisionCache *_revisionCache;
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
 * <init />
 * Initializes a context which persists its content in the given store.
 */
- (id)initWithStore: (COSQLiteStore *)store;
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
@property (weak, nonatomic, readonly) NSSet *persistentRoots;
/**
 * Returns persistent roots marked as deleted on disk, excluding those that
 * are pending undeletion.
 *
 * -persistentRootsPendingDeletion are not included in the returned set.
 */
@property (nonatomic, copy, readonly) NSSet *deletedPersistentRoots;


/** @taskunit Store and Metamodel Access */


/**
 * Returns the store for which the editing context acts a working copy.
 */
@property (strong, nonatomic, readonly) COSQLiteStore *store;
/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the persistent objects editable in the context.
 */
@property (nonatomic, readonly) ETModelDescriptionRepository *modelRepository;


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
@property (nonatomic, copy, readonly) NSSet *persistentRootsPendingInsertion;
/**
 * The persistent roots to be deleted in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *persistentRootsPendingDeletion;
/**
 * The persistent roots to be undeleted in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *persistentRootsPendingUndeletion;
/**
 * The persistent roots to be updated in the store on the next commit.
 */
@property (nonatomic, copy, readonly) NSSet *persistentRootsPendingUpdate;
/**
 * Returns whether the context contains uncommitted changes.
 *
 * Persistent root insertions, deletions, undeletions, and modifications (e.g., 
 * changing main branch, deleting branches, adding branches, editing branch 
 * metadata, reverting branch to a past revision) all count as uncommitted 
 * changes.
 *
 * See also -discardAllChanges.
 */
- (BOOL)hasChanges;
/**
 * Discards the uncommitted changes to reset the context to its last commit state.
 *
 * Persistent root insertions, deletions, undeletions and modifications (e.g., 
 * changing main branch, deleting branches, adding branches, editing branch 
 * metadata, reverting branch to a past revision) will be cancelled.
 *
 * All uncommitted embedded object edits in child persistent roots will be
 * cancelled.
 *
 * -persistentRootsPendingInsertion, -persistentRootsPendingDeletion, 
 * -persistentRootsPendingUndeletion and -persistentRootsPendingUpdate  will all 
 * return empty sets once the changes have been discarded.
 *
 * See also -hasChanges.
 */
- (void)discardAllChanges;


/** @taskunit Committing Changes */

/**
 * Commits the current changes to the store bound to a commit descriptor
 * identifier, and returns whether it succeeds.
 *
 * See -commitWithIdentitifer:metadata:undoTracks:error.
 */
- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
                  undoTracks: (NSArray *)undoTracks
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
 * -commitWithMetadata:undoTracks:error:.
 *
 * See COCommitDescriptor to understand how the localization works.
 */
- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
					metadata: (NSDictionary *)additionalMetadata
                  undoTracks: (NSArray *)undoTracks
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
 * method, but -commitWithIdentifier:metadata:undoTracks:error: or 
 * -commitWithIdentifier:undoTracks:error: that both support history 
 * localization through COCommitDescriptor.
 */
- (BOOL)commitWithMetadata: (NSDictionary *)metadata
                undoTracks: (NSArray *)undoTracks
                     error: (NSError **)anError;
/**
 * Commits the current changes to the store and returns whether it succeeds.
 *
 * You should avoid using this method in release code, it is mainly useful for 
 * debugging and quick development.
 *
 * See also -commitWithMetadata:undoTracks:error:.
 */
- (BOOL)commit;
/**
 * Commits the current changes to the store, records them on the undo track and 
 * returns whether it succeeds.
 * 
 * You should avoid using this method in release code, it is mainly useful for
 * debugging and quick development.
 *
 *  See also -commitWithMetadata:undoTracks:error:.
 */
- (BOOL)commitWithUndoTrack: (COUndoTrack *)aStack;


/** @taskunit Deprecated */


/**
 * Commits the current changes to the store with some basic metadatas and 
 * returns whether it succeeds.
 *
 * The description will be visible at the UI level when browsing the history.
 *
 * See -commitWithMetadata:undoTracks:error:.
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
@property (weak, nonatomic, readonly) COEditingContext *editingContext;

@end

extern NSString * const COEditingContextDidCommitNotification;
extern NSString * const kCOCommandKey;
