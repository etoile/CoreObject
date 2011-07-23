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
- (NSURL*)URL;

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
 * Returns the UUIDs that corresponds to objects belonging to the persistent 
 * root UUID. 
 *
 * The persistent root UUID is included in the returned set.<br />
 * When the given UUID is not a persistent root in the store, returns an empty 
 * set.
 */
- (NSSet *) UUIDsForRootObjectUUID: (ETUUID *)aUUID;
/** 
 * Inserts new UUIDs marked as persistent roots. 
 *
 * The UUID set must not be nil.
 * These UUIDs must not exist in the store, otherwise a 
 * NSInvalidArgumentException is raised.
 */
- (void) insertRootObjectUUIDs: (NSSet *)UUIDs;

/** @taskunit Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary *)meta 
                 rootObjectUUID: (ETUUID *)rootUUID;

- (void)beginChangesForObjectUUID: (ETUUID*)object;

- (void)setValue: (id)value
	 forProperty: (NSString*)property
		ofObject: (ETUUID*)object
	 shouldIndex: (BOOL)shouldIndex;

- (void)finishChangesForObjectUUID: (ETUUID*)object;

- (CORevision*)finishCommit;

- (CORevision*)revisionWithRevisionNumber: (uint64_t)anID;

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

@end
