#import <EtoileFoundation/EtoileFoundation.h>
#import "COStoreCoordinator.h"

@class COStoreCoordinator;

/**
 * Note on metadata: 
 * 
 * A commit has a properties dictionary which can be used to 
 * attach arbitray metadata to the commit, such as author's name, date,
 * description/log message, etc. It could also be used to mark a commit 
 * as a major checkpoint vs. a minor tweak. Then the UI in a document editor
 * could show only, by default, the "major checkpoint" commits, but the edge
 * between two major checkpoints could be expanded to see each individual 
 * edit.
 */
extern const NSString *kCOAuthorHistoryGraphNodeProperty;
extern const NSString *kCODateHistoryGraphNodeProperty;
extern const NSString *kCOTypeHistoryGraphNodeProperty;
extern const NSString *kCOShortDescriptionHistoryGraphNodeProperty;
extern const NSString *kCODescriptionHistoryGraphNodeProperty;

extern const NSString *kCOTypeMinorEdit;
extern const NSString *kCOTypeCheckpoint;
extern const NSString *kCOTypeMerge;
extern const NSString *kCOTypeCreateBranch;
extern const NSString *kCOTypeHidden;

/**
 * We store separate history graphs for each CoreObject.
 *
 * A COCommit is a batch of changes to one or more of these object history graphs.
 */
@interface COCommit : NSObject
{
@private
	ETUUID *_commitUUID;
	COStoreCoordinator *_storeCoordinator;
	NSMutableDictionary *_commitMetadata;
	NSMutableDictionary *_parentNodeUUIDsForObjectUUID;
	NSMutableDictionary *_childNodeUUIDsForObjectUUID;
	NSDictionary *_objectUUIDToObjectVersionMaping;
}

- (COStoreCoordinator *) storeCoordinator;



// Access to the per-object history graphs

/**
 * The principal parent of this commit in the given object's history graph
 */
- (COCommit *)parentCommitInObjectHistoryGraph: (ETUUID*)uuid;

/**
 * Additional parents (coming from merged branches) of this commit in the given
 * object's history graph
 */
- (NSArray *)additionalParentCommitsInObjectHistoryGraph: (ETUUID*)uuid;

/**
 * Returns the children of this commit in the given object's history graph
 */
- (NSArray *)childCommitsInObjectHistoryGraph: (ETUUID*)uuid;


/**
 * Mapping of UUID->Version which fully describes what the result of this
 * graph node is. (can be used to get the objects which were modified in this
 * node).
 * Keys are ETUUID, values are NSData containing hashes (which can be used
 * witht the COStore API)
 */
- (NSDictionary *)objectUUIDToObjectVersionMaping;

/**
 * Properties/metadata of the history graph node. Not versioned.
 * Value must be a property-list compatible data type.
 */
- (NSDictionary *)properties;
- (void)setValue: (NSObject*)value forProperty: (NSString*)property;

@end



@interface COCommit (Private)

- (id)		initWithUUID: (ETUUID*)uuid
	storeCoordinator: (COStoreCoordinator*)store
		  properties: (NSDictionary*)properties
parentNodeUUIDsForObjectUUIDs: (NSDictionary*)parents
childNodeUUIDsForObjectUUIDs: (NSArray*)children
uuidToObjectVersionMaping: (NSDictionary*)mapping;

- (id) initWithPropertyList: (NSDictionary*)plist storeCoordinator: (COStoreCoordinator *)store;
- (NSDictionary *)propertyList;

- (ETUUID*)commitUUID;

- (void) addChildCommitUUID: (ETUUID*)commit inObjectHistoryGraph: (ETUUID*)obj;

@end
