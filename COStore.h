#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "CORevision.h"

@class FMDatabase;

@interface COStore : NSObject
{
	@package
	NSURL *url;
	FMDatabase *db;
	NSMutableDictionary *commitObjectForID;
	
	NSNumber *commitInProgress;
	NSNumber *rootInProgress;
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
 * Returns whether the UUID corresponds to a persistent root in the store.
 *
 * For a nil UUID, raises a NSInvalidArgumentException.
 */
- (BOOL)isRootObjectUUID: (ETUUID *)aUUID;
/**
 * <override-subclass />
 * Returns the UUIDs that correspond to persistent roots in the store. 
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
- (NSSet *)UUIDsForRootObjectUUID: (ETUUID *)aUUID;

/**
 * <override-subclass />
 * Returns the persistent UUIDs of objects owned by root object, on the revision
 * track. This method is needed to reload an object a particular revision, where
 * some of its objects don't exist.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 */
- (NSSet *)UUIDsForRootObjectUUID: (ETUUID *)aUUID atRevision: (CORevision *)revision;

/** 
 *  <override-subclass />
 * Returns the UUID of the persistent root that owns the object UUID.
 *
 * For a persistent root UUID, returns the same UUID.<br />
 * When the UUID is not a persistent root in the store, returns nil.
 *
 * The UUID must not be nil, otherwise raises a NSInvalidArgumentException.
 */
- (ETUUID *)rootObjectUUIDForUUID: (ETUUID *)aUUID;
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

- (void)beginCommitWithMetadata: (NSDictionary *)meta 
                 rootObjectUUID: (ETUUID *)rootUUID
                   baseRevision: (CORevision *)revision;

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

/** @taskunit Private */

/**
 * <override-subclass />
 */
- (CORevision*)createCommitTrackForRootObjectUUID: (NSNumber*)rootObjectUUID
                                    currentNodeId: (int64_t*)currentNodeId;
/**
 * <override-subclass />
 */
- (void)addRevision: (CORevision *)newRevision toTrackUUID: (ETUUID *)aTrackUUID;
/**
 * <override-subclass />
 */
- (NSArray *)revisionsForTrackUUID: (ETUUID *)objectUUID
                  currentNodeIndex: (NSUInteger *)currentNodeIndex
                     backwardLimit: (NSUInteger)backward
                      forwardLimit: (NSUInteger)forward;
- (CORevision *) currentRevisionForTrackUUID: (ETUUID *)aTrackUUID;
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
- (CORevision*)maxRevision: (int64_t)maxRevNumber forRootObjectUUID: (ETUUID*)uuid;
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
