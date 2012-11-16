#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COEditingContext, COCommitTrack, COObject, CORevision;

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
@interface COPersistentRootEditingContext : NSObject
{
	@private
	COEditingContext *parentContext;
	ETUUID *persistentRootUUID;
	COCommitTrack *commitTrack;
	COObject *rootObject;
	CORevision *revision;
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
 * A root object isn't a core object and doesn't represent a core object either. 
 * The persistent root represents the core object. As such, use the persistent 
 * root UUID to refer to core objects and never 
 * <code>[[self rootObject] UUID]</code>.
 *
 * For now, this object must remain the same in the entire persistent root 
 * history including the branches (and derived cheap copies) due to limitations 
 * in EtoileUI.
 */
@property (nonatomic, retain) COObject *rootObject;
/**
 * The persistent root revision.
 *
 * This revision applies to the root object and inner objects. See -[COObject revision].
 */
@property (nonatomic, retain) CORevision *revision;

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

/** @taskunit Editing Context Nesting */

/**
 * The editing context managing the receiver.
 *
 * The parent context makes possible to edit multiple persistent roots 
 * simultaneously and provide an aggregate view on the editing underway.
 *
 * COPersistentRootEditingContext objects are instantiated and released by the
 * parent context.
 *
 * The parent context is managed by the user.
 */
@property (nonatomic, readonly) COEditingContext *parentContext;

/** @taskunit Framework Private */

- (id)initWithPersistentRootUUID: (ETUUID *)aUUID
				 commitTrackUUID: (ETUUID *)aTrackUUID
					  rootObject: (COObject *)aRootObject
				   parentContext: (COEditingContext *)aCtxt;
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

@end
