#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COEditingContext.h>

@class COCommitTrack, COObject, CORevision, COStore;

/**
 * A persistent root editing context exposes as a working copy a CoreObject 
 * store snapshot restricted to a single persistent root (see COEditingContext also).
 *
 * It queues changes and when the user requests it, it attempts to commit them
 * to the store.
 *
 * For each new persistent root, CoreObject produces a new UUID triplet based on:
 *
 * <deflist>
 * <item>a persistent root</item>a commit track collection that results in 
 * a history graph describing all the changes made to a document
 * (document has a very loose meaning here)</desc>
 * <item>a commit track</item><desc>the persistent root main branch, more 
 * commit tracks can be created by branching this initial track</desc>
 * <item>a root object</item><desc>the document main object e.g. the top node 
 * of a structed document, a photo object or a contact object</desc>
 * </deflist>
 *
 * Each UUID in this UUID triplet is unique (never reused) accross all 
 * CoreObject stores, unless a persistent root has been replicated accross 
 * stores (not supported for now).<br />
 * Generally speaking, CoreObject constructs (tracks, revisions, objects, 
 * stores etc.) are not allowed to share the same UUID. For the unsupported 
 * replication case, constructs using the same UUID are considered to be 
 * identical (same type and data) but replicated.  
 *
 * A persistent root represents a core object but a root object doesn't (see 
 * -rootObject). As such, use -persistentRootUUID to track core objects. 
 * A root object UUID might appear in multiple persistent roots (e.g. 
 * a persistent root copy will use the same root object UUID than the original 
 * persistent root although both core objects or persistent roots are distinct.<br />
 * From a terminology standpoint, persistent root and core object can be used 
 * interchangeably.
 */
@interface COPersistentRoot : NSObject <COPersistentObjectContext>
{
	@private
	COEditingContext *_parentContext;
	ETUUID *_persistentRootUUID;
	COCommitTrack *_commitTrack;
	COObject *_rootObject;
	CORevision *_revision;
	/** Loaded (or inserted) objects by UUID */
	NSMutableDictionary *_loadedObjects;
	NSMutableSet *_insertedObjects;
	NSMutableSet *_deletedObjects;
	/** Array of updated property names by inner object */
	NSMapTable *_updatedPropertiesByObject;
}

/** @taskunit Persistent Root Properties */

/**
 * The UUID that is bound to a single persistent root per CoreObject store.
 *
 * Two persistent roots belonging to distinct CoreObject stores cannot use the 
 * same UUID unless they point to the same persistent root replicated accross 
 * stores.
 * For now, persistent root replication accross distinct CoreObject stores 
 * is not supported and might never be.
 */
@property (nonatomic, readonly) ETUUID *persistentRootUUID;
/**
 * The persistent root branch edited in the editing context.
 *
 * By default, it is the persistent root current branch.
 * 
 * Changing the commit track switches the edited branch but not the current 
 * branch (the branch switch is not replicated to other applications). See 
 * COCommitTrack API to control the current branch.
 */
@property (nonatomic, retain) COCommitTrack *commitTrack;
/**
 * The entry point to navigate the object graph bound to the persistent root.
 *
 * The returned object is COObject class or subclass instance.
 *
 * A root object isn't a core object and doesn't represent a core object either. 
 * The persistent root represents the core object. As such, use the persistent 
 * root UUID to refer to core objects and never 
 * <code>[[self rootObject] UUID]</code>.
 *
 * For now, this object must remain the same in the entire persistent root 
 * history including the branches (and derived cheap copies) due to limitations 
 * in EtoileUI.
 */
@property (nonatomic, retain) id rootObject;
/**
 * The persistent root revision.
 *
 * This revision applies to the root object and inner objects. See -[COObject revision].
 */
@property (nonatomic, retain) CORevision *revision;
/**
 * The store for which the editing context acts a working copy.
 *
 * The store is the same than the parent context.
 *
 * See also -[COEditingContext store].
 */
@property (nonatomic, readonly) COStore *store;

/** @taskunit Editing Context Nesting */

/**
 * The editing context managing the receiver.
 *
 * The parent context makes possible to edit multiple persistent roots 
 * simultaneously and provide an aggregate view on the editing underway.
 *
 * COPersistentRoot objects are instantiated and released by the
 * parent context.
 *
 * The parent context is managed by the user.
 */
@property (nonatomic, readonly) COEditingContext *parentContext;

/** @taskunit Object Access and Loading */

/**
 * Returns the object identified by the UUID, by loading it to its last revision
 * when no instance managed by the receiver is present in memory.
 *
 * When the UUID doesn't correspond to a persistent object, returns nil.
 *
 * When the object is a inner object, the last revision is the one that is tied
 * to its root object last revision.
 *
 * See also -objectWithUUID:atRevision: and -loadedObjectForUUID:.
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid;
/**
 * Returns the object identified by the UUID, by loading it to the given
 * revision when no instance managed by the receiver is present in memory.
 *
 * When the UUID doesn't correspond to a persistent object, returns nil.
 *
 * For a nil revision, the object is loaded is loaded at its last revision.
 *
 * When the object is a inner object, the last revision is the one that is tied
 * to its root object last revision.
 *
 * When the object is already loaded, and its revision is not the requested
 * revision, raises an invalid argument exception.
 *
 * See also -loadedObjectForUUID:.
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid atRevision: (CORevision *)revision;

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
 * Returns the UUIDs of the objects presently managed by the receiver in memory.
 *
 * The returned objects include the inserted object UUIDs.
 *
 * Faults can be count as loaded objects.
 *
 * See also -loadedObjects.
 */
- (NSSet *)loadedObjectUUIDs;
/**
 * Returns the root objects presently managed by the receiver in memory.
 *
 * Faults and inserted objects can be included among the returned objects.
 *
 * The returned objects are a subset of -loadedObjects.
 */
- (NSSet *)loadedRootObjects;
/**
 * Returns the object identified by the UUID if presently loaded in memory.
 *
 * When the object is not loaded, or when there is no persistent object that
 * corresponds to this UUID, returns nil.
 */
- (id)loadedObjectForUUID: (ETUUID *)uuid;

/** @taskunit Pending Changes */

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
 * Returns the UUIDs of the objects updated since the last commit. See -updatedObjects.
 */
- (NSSet *)updatedObjectUUIDs;
/**
 * Returns whether the object has been updated since the last commit. See
 * -updatedObjects.
 *
 * Won't return YES if the object has just been inserted or deleted.
 */
- (BOOL)isUpdatedObject: (COObject *)anObject;
/**
 * Returns the objects deleted in the context with -deleteObject: and to be
 * deleted in the store on the next commit.
 *
 * After a commit, returns an empty set.
 *
 * Doesn't include newly inserted or deleted objects.
 */
- (NSSet *)deletedObjects;
/**
 * Returns the union of the inserted, updated and deleted objects. See
 * -insertedObjects, -updatedObjects and -deletedObjects.
 *
 * After a commit, returns an empty set.
 */
- (NSSet *)changedObjects;
/**
 * Returns whether any object has been inserted, deleted or updated since the
 * last commit.
 *
 * See also -changedObjects.
 */
- (BOOL)hasChanges;
/**
 * Discards the uncommitted changes to reset the context to its last commit state.
 *
 * Every object insertion or deletion is cancelled.<br />
 * Every updated property is reverted to its last committed value.
 *
 * -insertedObjects, -updatedObjects, -deletedObjects and -changedObjects will
 * all return empty sets once the changes have been discarded.
 *
 * See also -discardChangesInObject:.
 */
- (void)discardAllChanges;
/**
 * Discards the uncommitted changes in a particular object to restore the state
 * it was in at the last commit.
 *
 * Every updated property in the object is reverted to its last committed value.
 *
 * See also -discardAllChanges:.
 */
- (void)discardChangesInObject: (COObject *)object;

/** @taskunit Object Insertion */

/**
 * Creates a new instance of the given entity name (assigning the instance a new UUID)
 * and returns the object.
 *
 * The entity name must correspond to the COObject class or a subclass. Thereby
 * returned objects will be COObject class or subclass instances in all cases.
 *
 * This is the factory method for COObject class hierarchy.
 */
- (id)insertObjectWithEntityName: (NSString *)aFullName;

/** @taskunit Object Deletion */

/**
 * Schedules the object to be deleted both in memory and in store on the next
 * commit.
 */
- (void)deleteObject: (COObject *)anObject;

/** @taskunit Committing Changes */

/**
 * Commits the current changes to the store and returns the resulting revision.
 *
 * See -commitWithType:shortDescription: and -commitWithMetadata:.
 */
- (CORevision *)commit;
/**
 * Commits the current changes to the store with some basic metadatas and
 * returns the resulting revision.
 *
 * A commit on a single persistent root is atomic.
 *
 * Each root object that belong to -changedObjects results in a new revision.
 * We usually advice to commit a single root object at time to prevent multiple
 * revisions per commit.
 *
 * The description will be visible at the UI level when browsing the history.
 *
 * See -commitWithMetadata:.
 */
- (CORevision *)commitWithType: (NSString *)type
              shortDescription: (NSString *)shortDescription;

/** @taskunit Framework Private */

- (id)initWithPersistentRootUUID: (ETUUID *)aUUID
				 commitTrackUUID: (ETUUID *)aTrackUUID
						revision: (CORevision *)aRevision
				   parentContext: (COEditingContext *)aCtxt;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Declares the object as newly inserted and puts it among the loaded objects.
 *
 * The first registered object becomes the root object.
 */
- (void)registerObject: (COObject *)object;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COObject *)objectWithUUID: (ETUUID *)uuid entityName: (NSString *)name atRevision: (CORevision *)revision;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)discardLoadedObjectForUUID: (ETUUID *)aUUID;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the context a property value has changed in a COObject class or
 * subclass instance.
 */
- (void)markObjectUpdated: (COObject *)obj forProperty: (NSString *)aProperty;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Inserts the object into the context by checking the relationship consistency
 * if requested.
 *
 * When the object is not yet persistent, it is inserted into the context and
 * the new UUID hint is ignored.
 *
 * When the object is already persistent, based on the new UUID hint, the new
 * object inserted into the context will be:
 *
 * <deflist>
 * <item>newUUID is YES</item><desc>a copy (new instance and UUID)</desc>
 * <item>newUUID is NO</item><desc>a new context-relative instance (new
 * instance but same UUID)</desc>
 * </deflist>
 *
 * For a persistent object, multiples instance can exist in the same process,
 * one per editing context.
 *
 * You can pass an object that belongs to another context to this method.
 */
- (id)insertObject: (COObject *)sourceObject withRelationshipConsistency: (BOOL)consistency newUUID: (BOOL)newUUID;
/**
 * This method is deprecated but has no replacement yet.
 *
 * Copies an object from another context into this context.
 *
 * The copy refers to the same underlying persistent object (same UUID).
 */
- (id)insertObject: (COObject *)sourceObject;
/**
 * This method is deprecated but has no replacement yet.
 * 
 * Creates a copy of an object (assigning it a new UUID), including copying
 * all strongly contained objects (composite properties).
 */
- (id)insertObjectCopy: (COObject *)sourceObject;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Loads the object at its last revision.
 *
 * For a inner object, its last revision is its root object last revision.
 */
- (void)loadObject: (COObject *)obj;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Reloads the root object and its inner objects at a new revision.
 */
- (void)reloadAtRevision: (CORevision *)revision;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Unloads the root object and its inner objects.
 *
 * Can be used to implement undo on root object creation.
 */
- (void)unload;
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
- (CORevision *)saveCommitWithMetadata: (NSDictionary *)metadata;
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
@end
