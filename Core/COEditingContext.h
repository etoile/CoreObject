/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COPersistentObjectContext.h>

@class COSQLiteStore, COEditingContext, COPersistentRoot, COBranch, COObjectGraphContext, COObject;
@class COUndoTrackStore, COUndoTrack, COCommandGroup;
@class COCrossPersistentRootDeadRelationshipCache, CORevisionCache;
@class COError;

#ifndef NS_ENUM
#   if __has_feature(objc_fixed_enum)
#       define NS_ENUM(type, name) enum name : type name; enum name : type
#   else
#       define NS_ENUM(type, name) type name; enum
#   endif
#endif // NS_ENUM

/**
 * The behavior to decide when the editing context should unload persistent 
 * roots.
 *
 * TODO: If we keep it around, this should probably become a mask.
 */
typedef NS_ENUM(NSUInteger, COEditingContextUnloadingBehavior)
{
    /**
     * Persistent roots are never unloaded automatically, except uncommitted 
     * persistent roots on deletion.
     *
     * -unloadPersistentRoot: can still be used to unload persistent roots explicitly.
     */
    COEditingContextUnloadingBehaviorManual,
    /**
     * Persistent roots are unloaded on deletion.
     *
     * For external deletions committed in other editing contexts, persistent
     * roots will be unloaded in the current one.
     */
    COEditingContextUnloadingBehaviorOnDeletion
};

/**
 * @group Core
 * @abstract An editing context exposes an in-memory snapshot of a CoreObject 
 * store, allows the user to queue changes in memory and commit them atomically. 
 *
 * Its functionality is split across 5 main classes (there is a owner chain 
 * where each element owns the one just below in the list):
 *
 * <deflist>
 * <term>COEditingContext</term><desc>Entry point for opening and creating stores.
 * Handles persistent root insertion and deletion</desc>
 * <term>COPersistentRoot</term><desc>Versioned sandbox of inner objects,
 * with a history graph (CORevision), and one or more branches (COBranch).</desc>
 * <term>COBranch</term><desc>A position on the history graph, with the revision
 * contents exposed as a COObjectGraphContext</desc>
 * <term>COObjectGraphContext</term><desc>manages COObject graph, tracks 
 * changes and handles reloading new states</desc>
 * <term>COObject</term><desc>Mutable inner object</desc>
 * </deflist>
 *
 * CORevision also fits this set although it is not directly owned by one object.
 *
 * @section Common Use Cases
 *
 * Typically COEditingContext is used at application startup to create or open 
 * a store (+contextWithURL:), when creating, deleting or accessing persistent 
 * roots, and to track and commit changes in all persistent roots.
 *
 * To create, delete or access persistent roots, see Creation and Deletion 
 * sections in COPersistentRoot documentation.
 *
 * @section Metamodel
 *
 * For all the persistent root inner objects, a valid entity description must 
 * exist in -[COEditingContext modelDescriptionRepository].
 *
 * The metamodel in the model description repository is passed downwards 
 * from the editing context to the object graph contexts that manages the inner 
 * objects (see -[COObjectGraphContext modelDescriptionRepository])
 *
 * To register a new entity description that describe a COObject subclass, 
 * override +[NSObject newEntityDescription], and COEditingContext will
 * automatically register it in
 * -[COEditingContext initWithStore:modelDescriptionRepository:].
 *
 * To register a new entity description without writing a COObject subclass, 
 * see ETModelDescriptionRepository documentation. To instantiate the correct 
 * inner objects or entities, those can be passed to 
 * -[COObject initWithEntityDescription:objectGraphContext:], as 
 * -insertNewPersistentRootWithEntityName: does. For more details about inner 
 * object initialization, see COObject.
 *
 * @section Change Tracking
 *
 * COEditingContext, COPersistentRoot, COBranch, and COObjectGraphContext 
 * tracks the uncommitted or pending changes in their persistent properties, 
 * and in their owned element among the 5 core classes (see the ownership list 
 * at the beginning of the overview).
 *
 * For the editing context, -hasChanges computes the current change 
 * tracking state based on its own changes and the changes in the persistent 
 * roots, -[COPersistentRoot hasChanges] is based on its own changes and the 
 * changes in the branches, and so on until reaching COObjectGraphContext. 
 * Take note that the same recursive model applies to -discardChanges.
 *
 * For pending changes, each class has a distinct change tracking API, but 
 * all declare the same basic methods: -hasChanges and -discardsChanges.
 * 
 * @section Object Equality
 *
 * COEditingContext, COPersistentRoot, COBranch, and COObjectGraphContext do 
 * not override -hash or -isEqual:, so instances of these classes are only
 * considered equal to the same instances.
 *
 * These classes form an in-memory view on a database, and the notion of two of 
 * these views being equal isn't useful or interesting.
 *
 * @section Commits and Undo
 *
 * In the current implementation, all changes made in a COEditingContext are
 * committed atomically in one SQLite transaction. However, when you consider 
 * CoreObject as a version control system, atomicity only exists per-persistent 
 * root, since persistent roots are the units of versioning and each can be 
 * manipulated independently (rolled back, etc.).
 *
 * For committing changes, see -commitWithIdentifier:metadata:undoTrack:error: 
 * and other similar commit methods. Take note that COCommitDescriptor provides 
 * support to localize the commit metadata.
 *
 * For recording these commits as undoable actions, see COUndoTrack. CoreObject 
 * supports two undo/redo models that both conform to the COTrack protocol: 
 * 
 * <list>
 * <item>a branch undo/redo model, that moves the current revision pointer on 
 * the branch path (this model cannot undo/redo commits involving changes that 
 * don't create a new revision, or span several persistent roots or 
 * branches)</item>
 * <item>a rich undo/redo model based on recording commits on an undo track 
 * (and even aggregating commits accross multiple undo tracks)</item>
 * </list>
 *
 * In most cases, to support undo/redo in an application, use a COUndoTrack. 
 * Branch undo/redo can be used to inspect and navigate a single persistent 
 * root history (e.g. in a timeline UI presenting a document history). 
 */
@interface COEditingContext : NSObject <COPersistentObjectContext>
{
@private
    COSQLiteStore *_store;
    ETModelDescriptionRepository *_modelDescriptionRepository;
    Class _migrationDriverClass;
    /** Loaded (or inserted) persistent roots by UUID */
    NSMutableDictionary *_loadedPersistentRoots;
    COEditingContextUnloadingBehavior _unloadingBehavior;
    /** Set of persistent roots pending deletion */
    NSMutableSet *_persistentRootsPendingDeletion;
    /** Set of persistent roots pending undeletion */
    NSMutableSet *_persistentRootsPendingUndeletion;
    COCrossPersistentRootDeadRelationshipCache *_deadRelationshipCache;
    /** Undo */
    COUndoTrackStore *_undoTrackStore;
    BOOL _recordingUndo;
    COCommandGroup *_currentEditGroup;
    CORevisionCache *_revisionCache;
    /** Detect illegal recursive calls to commit */
    BOOL _inCommit;
    COObjectGraphContext *_internalTransientObjectGraphContext;
    NSMutableDictionary *_lastTransactionIDForPersistentRootUUID;
    BOOL _hasLoadedPersistentRootUUIDs;
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
 * The model repository is set to +[ETModelDescription mainRepository].
 *
 * See also -initWithStore:modelDescriptionRepository:.
 */
- (instancetype)initWithStore: (COSQLiteStore *)store;
/**
 * <init />
 * Initializes a context which persists its content in the given store,
 * manages it using the metamodel provided by the model description repository 
 * and migration driver, and whose undo tracks are backed by the last store argument.
 *
 * When COObject entity description doesn't appear in the repository, this 
 * initializer invokes +newEntityDescription on COObject and its subclasses, 
 * then it registers the resulting entity descriptions.
 *
 * For attribute types not directly supported by CoreObject (transient or
 * serialized with a value transformer), ETModelDescriptionRepository will 
 * attempt to register entity descriptions corresponding to these types,
 * by invoking +[NSObject newEntityDescription] on the class with the same name.
 *
 * To register types bound to classes manually, see
 * -[ETModelDescriptionRepository registerEntityDescriptionsForClasses:resolveNow:].
 *
 * For a nil model repository, or a repository that doesn't a COObject entity
 * description, raises a NSInvalidArgumentException.
 *
 * For a migration driver class that is not a subclass of COSchemaMigrationDriver, 
 * raises a NSInvalidArgumentException.
 *
 * For a nil undo track store, raises a NSInvalidArgumentException.
 */
- (instancetype)initWithStore: (COSQLiteStore *)store
   modelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
         migrationDriverClass: (Class)aDriverClass
               undoTrackStore: (COUndoTrackStore *)aUndoTrackStore NS_DESIGNATED_INITIALIZER;
/**
 * Initializes a context which persists its content in the given store, and
 * manages it using the metamodel provided by the model description repository.
 *
 * The undo track store is set to +[COUndoTrackStore defaultStore].
 *
 * See also -initWithStore:modelDescriptionRepository:undoTrackStore:.
 */
- (instancetype)initWithStore: (COSQLiteStore *)store
   modelDescriptionRepository: (ETModelDescriptionRepository *)aRepo;
/**
 * Initializes the context with no store. 
 * As a result, the context content is not persisted.
 *
 * See also -initWithStore:.
 */
- (instancetype)init;


/** @taskunit Accessing All Persistent Roots */


/**
 * Returns all persistent roots in the store (excluding those that are marked as 
 * deleted on disk), plus those pending insertion and undeletion (and minus 
 * those pending deletion).
 */
@property (nonatomic, readonly) NSSet *persistentRoots;
/**
 * Returns persistent roots marked as deleted on disk, excluding those that
 * are pending undeletion, plus those pending deletion.
 */
@property (nonatomic, readonly) NSSet *deletedPersistentRoots;
/**
 * Returns all persistent roots loaded in memory.
 *
 * The returned set includes those that are pending insertion, undeletion or 
 * deletion, and deleted ones (explicitly loaded with -persistentRootForUUID: or 
 * when using COEditingContextUnloadingBehaviorManual).
 */
@property (nonatomic, readonly) NSSet *loadedPersistentRoots;


/** @taskunit Store and Metamodel Access */


/**
 * Returns the store for which the editing context acts a working copy.
 */
@property (nonatomic, readonly, strong) COSQLiteStore *store;
/**
 * Returns the model description repository, which holds the metamodel that 
 * describes all the persistent objects editable in the context.
 */
@property (nonatomic, readonly, strong) ETModelDescriptionRepository *modelDescriptionRepository;
/**
 * The migration driver used to migrate items to the latest package versions.
 *
 * By default, returns COSchemaMigrationDriver.
 *
 * You should usually use COSchemaMigration rather than writing your own custom 
 * migration driver subclass.
 */
@property (nonatomic, readonly) Class migrationDriverClass;
/**
 * Returns the store backing the undo tracks initialized with the receiver.
 */
@property (nonatomic, readonly, strong) COUndoTrackStore *undoTrackStore;



/** @taskunit Managing Persistent Roots */


/**
 * Returns the persistent root bound the the given UUID in the store or nil.
 *
 * The editing context retains the returned persistent root.
 *
 * This method can return any persistent roots among -persistentRoots and 
 * -deletedPersistentRoots (including those pending deletion and undeletion), 
 * but the loading is restricted to the requested persistent root.
 */
- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)aUUID;
/**
 * Same as -persistentRootForUUID: but doesn't cause loading.
 */
- (COPersistentRoot *)loadedPersistentRootForUUID: (ETUUID *)aUUID;
/**
 * Unloads the persistent root including its branches, object graphs and inner
 * objects.
 *
 * To reload a persistent root, use -persistentRootForUUID:.
 *
 * Cross persistent root references pointing to inner objects that belongs to 
 * the unloaded persistent root will be turned into faults. Any future attempts
 * to access them with -[COObject valueForProperty:] will cause this persistent 
 * root to be transparently reloaded.
 *
 * See -[COEditingContext setUnloadingBehavior:] to control when persistent 
 * roots are unloaded or prevent unloading to happen.
 */
- (void)unloadPersistentRoot: (COPersistentRoot *)aPersistentRoot;
/**
 * Returns a new persistent root that uses the given root object.
 *
 * The returned persistent root is added to -persistentRootsPendingInsertion 
 * and will be saved to the store on the next commit.
 *
 * The object graph context of the root object must be transient, otherwise 
 * a NSInvalidArgumentException is raised.
 *
 * The object graph context of the root object must also use the same model 
 * description repository than the receiver, otherwise a 
 * NSInvalidArgumentException is raised.
 *
 * For a nil root object, raises a NSInvalidArgumentException.
 */
- (COPersistentRoot *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject;
/**
 * Creates a root object of the requested entity and returns a new persistent
 * root using that root object.
 */
- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName;
/**
 * The conditions to unload persistent roots.
 *
 * By default, returns COEditingContextUnloadingOnDeletion.
 */
@property (nonatomic, readwrite, assign) COEditingContextUnloadingBehavior unloadingBehavior;


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
@property (nonatomic, readonly) BOOL hasChanges;
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
                       error: (COError **)anError;
/**
 * Commits the current changes to the store, bound to a commit descriptor 
 * identifier along the additional metadatas, and returns whether it 
 * succeeds.
 *
 * The metadata dictionary must be a valid property list or nil, otherwise a
 * serialization exception is raised.
 *
 * The changed objects are validated with -[COObject validate], and an aggregate 
 * validation error per object is returned in <code>[anError errors]</code>. 
 * For each aggregate validation error, -[COError errors] will return 
 * validation suberrors. For example, 
 * <code>[[[anError errors] firstObject] errors] mappedCollection] validationResult]</code> 
 * returns validation issues that pertain to the first validated object.
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
                       error: (COError **)anError;
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
                     error: (COError **)anError;
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
 * See also -commitWithMetadata:undoTrack:error:.
 */
- (BOOL)commitWithUndoTrack: (COUndoTrack *)aTrack;


/** @taskunit Description */


/**
 * Returns a short description to summarize the receiver.
 */
@property (readonly, copy) NSString *description;
/**
 * Returns a multi-line description including informations about the pending 
 * changes.
 */
@property (nonatomic, readonly) NSString *detailedDescription;


/** @taskunit Deprecated */


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
extern NSString *const COEditingContextDidChangeNotification;
/**
 * See userInfo explanation in COEditingContextDidChangeNotification.
 */
extern NSString *const kCOCommandKey;


/**
 * Posted by when one ore more persistent roots have been unloaded (usually due 
 * to deletion).
 *
 * Use this notification to release any references to these persistent roots. 
 *
 * To get a new reference immediately, you can force a reloading with 
 * -persistentRootForUUID:.
 *
 * The sender is the COEditingContext that does the unloading.
 */
extern NSString *const COEditingContextDidUnloadPersistentRootsNotification;
/**
 * The unloaded COPersistentRoot set.
 */
extern NSString *const kCOUnloadedPersistentRootsKey;
