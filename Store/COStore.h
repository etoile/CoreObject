/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "CORevision.h"

@class FMDatabase;

@protocol COTrackNodeBuilder <NSObject>
- (id)makeNodeWithID: (int64_t)aNodeID revision: (CORevision *)aRevision;
@end

/** 
 * Two track nodes can point to the same revision, yet have different previous
 * nodes and/or next nodes. In other words, base revision and previous track 
 * node doesn't represent the same concept. 
 * For example… Suppose a revision C is added to a commit track. The current node 
 * now points to it and the previous node to its base revision B. For commit 
 * tracks, base revision and previous track node represents the same idea.
 * Now suppose the same revision C is added to a custom track (that doesn't 
 * contain B or has additional revisions following B). For the commit track,  
 * the current node and previous node remains the same. However for the 
 * custom track, the current node is the same than commit track current node, 
 * but the previous node doesn't point to the same revision B.
 */
@interface COStore : NSObject
{
	@package
	NSURL *url;
	FMDatabase *db;
	NSMutableDictionary *commitObjectForID;
	
	NSNumber *commitInProgress;
	NSNumber *rootInProgress;
	NSNumber *trackInProgress;
	ETUUID *objectInProgress;

	BOOL hasPushedChanges;
}

/** @taskunit Initialization */

/**
 * <override-subclass />
 * Initializes and returns a new store object for the store content located at 
 * the given URL.
 *
 * The URL can point to the store content directly, or provide a connection to a 
 * server mediating the access to the content.
 *
 * For a nil URL, raises a NSInvalidArgumentException.
 */
- (id)initWithURL: (NSURL *)aURL;

/** @taskunit Identity and Location */

/**
 * Returns the store location.
 */
- (NSURL *)URL;
/**
 * <override-subclass />
 * Returns the store UUID.
 *
 * The URL can vary by moving the store, but the UUID won't.
 */
- (ETUUID *)UUID;

/** @taskunit Store Metadata */

/**
 * <override-subclass />
 * Returns the metadata attached to the store.
 *
 * See -metadata to learn about the keys in the returned plist.
 */
- (NSDictionary *) metadata;
/**
 * <override-subclass />
 * Sets the metadata attached to the store.
 *
 * The dictionary must be a valid plist and can contain the keys:
 *
 * <list>
 * <item>kCOTagGroupUUID</item>
 * <item>kCOLibraryGroupUUID</item>
 * </list>
 *
 * The UUIDs must be NSString objects.
 *
 * For a nil plist, raises a NSInvalidArgumentException.
 */
- (void) setMetadata: (NSDictionary *)plist;

/** @taskunit Listing Persistent Objects */

/** 
 * <override-never />
 * Returns the object UUIDs that appear in changes recorded on the given commit 
 * track.
 *
 * See -objectUUIDsForCommitTrackUUID:atRevision:.
 */
- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID;
/**
 * <override-subclass />
 * Returns the object UUIDs that appear in changes recorded on the given commit
 * track up to a certain revision.
 *
 * This method is needed to list the inner objects that exist at the given  
 * revision for the persistent root owning the commit track.
 *
 * The root object UUID is included in the returned set.
 *
 * When the UUID is not a commit track UUID in the store, returns an empty set.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 */
- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID atRevision: (CORevision *)revision;

/** @taskunit Persistent Roots  */

/**
 * <override-subclass />
 * Returns whether the UUID corresponds to a persistent root in the store.
 *
 * A persistent root UUID is never reused in a store. Since it is unique among 
 * all the persistent roots and tracks in a single store, references to root  
 * objects accross persistent roots can be resolved transparently.
 *
 * For a nil UUID, raises a NSInvalidArgumentException.
 */
- (BOOL)isPersistentRootUUID: (ETUUID *)aUUID;
/**
 * <override-subclass />
 * Returns the UUIDs that correspond to the persistent roots in the store.
 *
 * Deleted persistent roots are not included among the returned UUIDs.
 *
 * For a new store, will return an empty set.
 */
- (NSSet *)persistentRootUUIDs;
/**
 * <override-subclass />
 * Returns the UUID of the persistent root that owns the given commit track.
 *
 * For a nil UUID, raises an NSInvalidArgumentException.
 */
- (ETUUID *)persistentRootUUIDForCommitTrackUUID: (ETUUID *)aTrackUUId;
/**
 * <override-subclass />
 * Returns the main branch root UUID for a persistent root.
 *
 * For a nil UUID, raises an NSInvalidArgumentException.
 *
 * For explanations about the main branch concept, see COCommitTrack.
 */
- (ETUUID *)mainBranchUUIDForPersistentRootUUID: (ETUUID *)aUUID;
/**
 * <override-subclass />
 * Returns the root object UUID for a persistent root.
 *
 * For a nil UUID, raises an NSInvalidArgumentException.
 *
 * For explanations about the root object concept, see COPersistentRoot.
 */
- (ETUUID *)rootObjectUUIDForPersistentRootUUID: (ETUUID *)aPersistentRootUUID;

/** @taskunit Inserting and Deleting Persistent Roots */

/** 
 * <override-subclass />
 * Inserts new UUIDs marked as persistent roots. 
 *
 * These UUIDs must not exist in the store, otherwise a 
 * NSInvalidArgumentException is raised.
 *
 * The UUID set must not be nil, otherwise NSInvalidArgumentException is raised.
 */
- (void)insertPersistentRootUUID: (ETUUID *)aPersistentRootUUID
				 commitTrackUUID: (ETUUID *)aMainBranchUUID
				  rootObjectUUID: (ETUUID *)aRootObjectUUID;
/**
 * <override-subclass />
 * Marks the persistent root as deleted and returns the resulting revision.
 *
 * Unless eraseNow argument is YES, all the persistent root data (commits,  
 * commit tracks, etc.) remains until the CoreObject garbage collector is run.
 *
 * For now, there is no method to restore a deleted object (not yet erased).
 *
 * The returned revision is a store structure change and as such doesn't appear 
 * in the persistent root commit track.
 *
 * If the UUID doesn't exist in the store, raises an NSInvalidArgumentException.
 *
 * For a nil UUID, raises a NSInvalidArgumentException.
 */
- (CORevision *)deletePersistentRootForUUID: (ETUUID *)aPersistentRootUUID
                                   eraseNow: (BOOL)eraseNow;

/** @taskunit Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary *)metadata
			 persistentRootUUID: (ETUUID *)aPersistentRootUUID
				commitTrackUUID: (ETUUID *)aTrackUUID
                   baseRevision: (CORevision *)baseRevision;
- (void)beginChangesForObjectUUID: (ETUUID *)object;
/**
 * <override-subclass />
 */
- (void)setValue: (id)value
	 forProperty: (NSString *)property
		ofObject: (ETUUID *)object
	 shouldIndex: (BOOL)shouldIndex;
- (void)finishChangesForObjectUUID: (ETUUID *)object;
- (CORevision *)finishCommit;

/** @taskunit Accessing Revisions */

/**
 * <override-never />
 * Returns the latest store revision.
 */
- (CORevision *)latestRevision;
/**
 * <override-subclass />
 */
- (int64_t)latestRevisionNumber;
/**
 * <override-subclass />
 */
- (CORevision *)revisionWithRevisionNumber: (int64_t)anID;
/**
 * <override-subclass />
 */
- (NSArray *)revisionsForObjectUUIDs: (NSSet *)uuids;

/** @taskunit Full-text Search */

/**
 * <override-subclass />
 */
- (NSArray *)resultDictionariesForQuery: (NSString *)query;

/** @taskunit Managing Commit Tracks (Low-Level API) */

/**
 * <override-subclass />
 *
 * The commit track creation revision is a store structure change and as such 
 * doesn't appear in the commit track itself.
 */
- (CORevision *)createCommitTrackWithUUID: (ETUUID *)aBranchUUID
							         name: (NSString *)aBranchName
                           parentRevision: (CORevision *)aRevision
				           rootObjectUUID: (ETUUID *)aRootObjectUUID
                       persistentRootUUID: (ETUUID *)aPersistentRootUUID
                      isNewPersistentRoot: (BOOL)isNewPersistentRoot;
/**
 * <override-subclass />
 * Returns the parent track revision from which the commit track has been 
 * derived.
 * 
 * This parent revision belongs to the immediate parent track in  
 * -parentTracksUUIDsForCommitTrackUUID:.
 */
- (CORevision *)parentRevisionForCommitTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Returns the parent commit track UUIDs starting from the oldest parent to 
 * the most recent one.
 *
 * The oldest parent is the initial track that has no parent track and starts 
 * the parent track chain.
 *
 * The most recent parent is the immediate parent from which the commit track 
 * has been derived. This is the same than 
 * <code>[[self parentRevisionForCommitTrackUUID: aTrackUUID] trackUUID]</code>.
 *
 * The commit track UUID is not included in the returned array.
 */
- (NSArray *)parentTrackUUIDsForCommitTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Returns the name for the given commit track.
 *
 * Commit tracks bound to the same persistent root must each use distinct names. 
 *
 * The name is usually a branch label.
 *
 * If the branch hasn't been named, returns an empty string.
 *
 * For a nil UUID, raises an NSInvalidArgumentException.
 */
- (NSString *)nameForCommitTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Returns the most recent revision on the commit track that is less than or 
 * equal to the given revision.
 *
 * Passes 0 or NSIntegerMax as maxRevNumber to get the most recent revisions 
 * with no upper bound among all revisions on the commit track.
 *
 * If the UUID is not a commit track UUID (but a custom track UUID or some other 
 * UUID), returns nil.
 */
- (CORevision *)maxRevision: (int64_t)maxRevNumber forCommitTrackUUID: (ETUUID *)aTrackUUID;

/** @task Managing Tracks (Low-Level API) */

/**
 * <override-subclass />
 * Adds the revision as a new track node to the given track, and returns the new 
 * track node ID.
 *
 * The new track node becomes the track current node.
 *
 * If there is no track for the given UUID, the track is created.<br />
 * The track creation doesn't produce a revision, as custom tracks are usually 
 * implementation details managed by programs and not directly exposed to the 
 * user. As such the user doesn't need Undo/Redo on a custom track creation and 
 * deletion unlike a commit track. 
 *
 * Take note implicit track creation doesn't create a commit track, but just the 
 * most basic track structure in the store. For creating a commit track, see 
 * -createCommitTrackWithUUID:name:parentRevision:rootObjectUUID:persistentRootUUID:isNewPersistentRoot:.
 *
 * If the track creation needs to be recorded, then -addRevision:toTrackUUID: 
 * can be bracketed by -isTrackUUID: to detect a track creation. And a 
 * synthesized revision can be pushed on the custom track used to record the 
 * store structure changes.
 *
 * See also COTrack, COCustomTrack and COCommitTrack.
 */
- (int64_t)addRevision: (CORevision *)newRevision toTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Removes the track content and any dedicated storage structure in the store.
 */
- (void)deleteTrackForUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Returns track nodes ordered from oldest to last, belonging to the given track.
 *
 * If the returned array is not empty, it contains at least the track current 
 * node.
 *
 * The backward and forward limit tells the store it should attempt to return 
 * the given node count in addition to the current node. backwardLimit applies 
 * to the node count before the current node, and forwardLimit to the node count 
 * after the current node. For a track that doesn't contain enough nodes and 
 * depending on the current node position on the track, the returned node counts 
 * can be less than <em>backwardLimit + 1 (current node) + forwardLimit</em>.
 *
 * The track nodes are built by invoking -makeNodeWithID:revision: on 
 * aNodeBuilder.
 *
 * On return, currentNodeIndex points to the track current node among the 
 * returned nodes. For a track without a current node, currentNodeIndex is set 
 * to NSNotFound. See -[COTrack currentNode].
 *
 * If the track doesn't exist, returns an empty array.
 *
 * For a nil track UUID or node builder, raises an NSInvalidArgumentException.
 */
- (NSArray *)nodesForTrackUUID: (ETUUID *)aTrackUUID
                   nodeBuilder: (id <COTrackNodeBuilder>)aNodeBuilder
              currentNodeIndex: (NSUInteger *)currentNodeIndex
                 backwardLimit: (NSUInteger)backward
                  forwardLimit: (NSUInteger)forward;
/**
 * <override-subclass />
 * Returns the current node revision for the given track. 
 *
 * If the track doesn't exist or contains no revisions, returns nil.
 */
- (CORevision *)currentRevisionForTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 */
- (void)setCurrentRevision: (CORevision *)newRev
              forTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Changes the track current node to point on its previous node.
 *
 * The returned revision points to the state resulting from the undo.
 * For a undo targeting a persistent root, you can pass this revision to
 * -[COPersistentRoot reloadAtRevision:] to get the undo applied.
 *
 * The undo doesn't result in a new revision.
 *
 * Each undo is recorded on the track.
 */
- (CORevision *)undoOnTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Changes the track current node to point on its next node, and returns this 
 * next node revision.
 *
 * The returned revision points to the state resulting from the redo. 
 * For a redo targeting a persistent root, you can pass this revision to 
 * -[COPersistentRoot reloadAtRevision:] to get the redo applied.
 *
 * The redo doesn't result in a new revision.
 *
 * Each redo is recorded on the track.
 */
- (CORevision *)redoOnTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Returns whether the UUID corresponds to a track in the store. 
 */
- (BOOL)isTrackUUID: (ETUUID *)aUUID;

/** @taskunit Testing */

/**
 * <override-subclass />
 * Returns whether the UUID corresponds to a root object in the store.
 *
 * A root object is bound to a persistent root and its cheap copies (derived
 * persistent roots).
 *
 * For a nil UUID, raises a NSInvalidArgumentException.
 */
- (BOOL)isRootObjectUUID: (ETUUID *)aUUID;
/**
 * <override-subclass />
 * Returns the UUIDs that correspond to the root objects in the store.
 *
 * When cheap copies exist in the store, the root object count and the
 * persistent root count don't match, because root objects are shared accross
 * a persistent root and its cheap copies.
 *
 * For a new store, will return an empty set.
 */
- (NSSet *)rootObjectUUIDs;
/**
 * <override-subclass />
 * Returns the root object UUID bound to persistent roots that own the given
 * persistent object.
 *
 * For a root object UUID, returns the same UUID.<br />
 * When the UUID is not a persistent object in the store, returns nil.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 *
 * Note: This method could be deprecated.
 */
- (ETUUID *)rootObjectUUIDForObjectUUID: (ETUUID *)aUUID;
/**
 * <override-subclass />
 * Returns the UUID of the persistent root that owns the given root object.
 *
 * When the UUID is not a root object in the store, returns nil.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 *
 * Note: This method could be deprecated.
 */
- (ETUUID *)persistentRootUUIDForRootObjectUUID: (ETUUID *)aUUID;

@end

extern NSString *COStoreDidChangeCurrentNodeOnTrackNotification;
extern NSString *kCONewCurrentNodeIDKey;
extern NSString *kCONewCurrentNodeRevisionNumberKey;
extern NSString *kCOOldCurrentNodeRevisionNumberKey;
extern NSString *kCOStoreUUIDStringKey;


/** Wraps a dictionary into an object which is a value rather a collection.

Should be provided by SQLClient or moved to EtoileFoundation. */
@interface CORecord : NSObject
{
	NSDictionary *dictionary;
}

- (id) initWithDictionary: (NSDictionary *)aDict;

@end
