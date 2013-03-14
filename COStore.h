#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "CORevision.h"

@class FMDatabase;

@protocol COTrackNodeBuilder <NSObject>
- (id)makeNodeWithID: (int64_t)aNodeID revision: (CORevision *)aRevision;
@end


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

/** @taskunit Persistent Roots  */

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
 * Returns the UUIDs of the objects owned by the the persistent root UUID. 
 *
 * The persistent root UUID is included in the returned set.<br />
 * When the UUID is not a persistent root in the store, returns an empty set.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 */
- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID;

/**
 * <override-subclass />
 * Returns the persistent UUIDs of objects owned by root object, on the revision
 * track. This method is needed to reload an object a particular revision, where
 * some of its objects don't exist.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 */
- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID atRevision: (CORevision *)revision;

/** 
 *  <override-subclass />
 * Returns the UUID of the persistent root that owns the object UUID.
 *
 * For a persistent root UUID, returns the same UUID.<br />
 * When the UUID is not a persistent root in the store, returns nil.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 */
- (ETUUID *)rootObjectUUIDForObjectUUID: (ETUUID *)aUUID;
- (ETUUID *)rootObjectUUIDForPersistentRootUUID: (ETUUID *)aPersistentRootUUID;
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
- (ETUUID *)persistentRootUUIDForCommitTrackUUID: (ETUUID *)aTrackUUId;
- (ETUUID *)mainBranchUUIDForPersistentRootUUID: (ETUUID *)aUUID;
// TODO: Remove
- (ETUUID *)persistentRootUUIDForRootObjectUUID: (ETUUID *)aUUID;
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

/** @taskunit Revision history */

/**
 * <override-subclass />
 */
- (int64_t)latestRevisionNumber;

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
 */
- (CORevision *)currentRevisionForTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 */
- (void)setCurrentRevision: (CORevision *)newRev
              forTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 */
- (CORevision*)undoOnCommitTrack: (ETUUID*)commitTrack;
/**
 * <override-subclass />
 */
- (CORevision*)redoOnCommitTrack: (ETUUID*)commitTrack;
/**
 * <override-subclass />
 */
- (CORevision *)maxRevision: (int64_t)maxRevNumber forCommitTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 * Returns whether the UUID corresponds to a track in the store. 
 */
- (BOOL)isTrackUUID: (ETUUID *)aUUID;

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
