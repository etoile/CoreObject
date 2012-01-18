#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "CORevision.h"

@class FMDatabase;

@interface COStore : NSObject
{
@package
	FMDatabase *db;
	NSURL *url;
	NSMutableDictionary *commitObjectForID;
	
	NSNumber *commitInProgress;
	NSNumber *rootInProgress;
	ETUUID *objectInProgress;

	BOOL hasPushedChanges;
}

/** @taskunit Initialization */

- (id)initWithURL: (NSURL*)aURL;

/** @taskunit Identity and Location */

/**
 * Returns the store location.
 */
- (NSURL *)URL;
/**
 * Returns the store UUID.
 *
 * The URL can vary by moving the store, but the UUID won't.
 */
- (ETUUID *)UUID;

/** @taskunit Store Metadata */

/**
 * Returns the metadata attached to the store.
 *
 * See -metadata to learn about the keys in the returned plist.
 */
- (NSDictionary *) metadata;
/**
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
 */
- (void) setMetadata: (NSDictionary *)plist;

/** @taskunit Persistent Roots  */

/** 
 * Returns whether the UUID corresponds to a persistent root in the store. 
 */
- (BOOL)isRootObjectUUID: (ETUUID *)aUUID;
/** 
 * Returns the UUIDs that correspond to persistent roots in the store. 
 *
 * For a new store, will return an empty set. 
 */
- (NSSet *)rootObjectUUIDs;
/** 
 * Returns the UUIDs of the objects owned by the the persistent root UUID. 
 *
 * The persistent root UUID is included in the returned set.<br />
 * When the UUID is not a persistent root in the store, returns an empty set.
 *
 * The UUID must not be nil.
 */
- (NSSet *)UUIDsForRootObjectUUID: (ETUUID *)aUUID;

/**
  * Returns the persistent UUIDs of objects owned by root object, on the revision
  * track. This method is needed to reload an object a particular revision, where
  * some of its objects don't exist.
  */
- (NSSet*)UUIDsForRootObjectUUID: (ETUUID*)aUUID atRevision: (CORevision*)revision;

/** 
 * Returns the UUID of the persistent root that owns the object UUID.
 *
 * For a persistent root UUID, returns the same UUID.<br />
 * When the UUID is not a persistent root in the store, returns nil.
 *
 * The UUID must not be nil.
 */
- (ETUUID *)rootObjectUUIDForUUID: (ETUUID *)aUUID;
/** 
 * Inserts new UUIDs marked as persistent roots. 
 *
 * These UUIDs must not exist in the store, otherwise a 
 * NSInvalidArgumentException is raised.
 *
 * The UUID set must not be nil.
 */
- (void)insertRootObjectUUIDs: (NSSet *)UUIDs;

/** @taskunit Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary *)meta 
                 rootObjectUUID: (ETUUID *)rootUUID
                   baseRevision: (CORevision*)revision;

- (void)beginChangesForObjectUUID: (ETUUID*)object;

- (void)setValue: (id)value
	 forProperty: (NSString*)property
		ofObject: (ETUUID*)object
	 shouldIndex: (BOOL)shouldIndex;

- (void)finishChangesForObjectUUID: (ETUUID*)object;

- (CORevision*)finishCommit;

- (CORevision*)revisionWithRevisionNumber: (uint64_t)anID;
- (NSArray *)revisionsForObjectUUIDs: (NSSet *)uuids;

/** @taskunit Full-text Search */

- (NSArray*)resultDictionariesForQuery: (NSString*)query;

/** @taskunit Revision history */

- (uint64_t) latestRevisionNumber;

/** @taskunit Private */

- (BOOL)setupDB;
- (NSNumber*)keyForUUID: (ETUUID*)uuid;
- (ETUUID*)UUIDForKey: (int64_t)key;
- (NSNumber*)keyForProperty: (NSString*)property;
- (NSString*)propertyForKey: (int64_t)key;
- (CORevision*)createCommitTrackForRootObjectUUID: (NSNumber*)rootObjectUUID
                                    currentNodeId: (int64_t*)currentNodeId;
- (void)updateCommitTrackForRootObjectUUID: (NSNumber*)rootObjectUUIDIndex
                               newRevision: (NSNumber*)newRevision;
- (NSArray*)loadCommitTrackForObject: (ETUUID*)objectUUID
                        fromRevision: (CORevision*)revision
                        nodesForward: (NSUInteger)nodes
                       nodesBackward: (NSUInteger)nodes;
- (CORevision*)undoOnCommitTrack: (ETUUID*)commitTrack;
- (CORevision*)redoOnCommitTrack: (ETUUID*)commitTrack;
- (CORevision*)maxRevision: (int64_t)maxRevNumber forRootObjectUUID: (ETUUID*)uuid;
/**
 * Returns whether the UUID corresponds to a track in the store. 
 */
- (BOOL)isTrackUUID: (ETUUID *)aUUID;

@end

/** Wraps a dictionary into an object which is a value rather a collection.

Should be provided by SQLClient or moved to EtoileFoundation. */
@interface CORecord : NSObject
{
	NSDictionary *dictionary;
}

- (id) initWithDictionary: (NSDictionary *)aDict;

@end
