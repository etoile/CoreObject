#import <EtoileFoundation/EtoileFoundation.h>
#import "COStoreCoordinator.h"

@class COStoreCoordinator;

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
 * A node in the store's history graph. Managed by a COStoreCoordinator.
 *
 * History graph nodes are identified by a UUID. They represent one commit
 * in the revision control system (the state of all objects after the commit).
 *
 * Each node can have zero or more parents, and zero or more children.
 *
 * A history node also has a properties dictionary which can be used to 
 * attach arbitray metadata to the node, such as author's name, date,
 * description/log message, etc. It could also be used to mark a node 
 * as a major checkpoint vs. a minor tweak. Then the UI in a document editor
 * could show only, by default, the "major checkpoint" nodes, but the edge
 * between two major checkpoints could be expanded to see each individual 
 * edit. (In a text editor, I expect the COHistoryGraphNodes would have
 * the same granularity as undo manager actions; i.e. one sentence of typing?)
 */
@interface COHistoryGraphNode : NSObject
{
@private
  ETUUID *_uuid;
  COStoreCoordinator *_store;
  NSMutableDictionary *_properties;
  NSMutableArray *_parentNodeUUIDs;
  NSMutableArray *_childNodeUUIDs;
  NSDictionary *_uuidToObjectVersionMaping;
}

- (COStoreCoordinator *) storeCoordinator;

/**
 * Returns the parents of this history node.
 * 
 * History nodes can have zero parents, which indicates they are a root node.
 * One parent corresponds to a normal edit, and two or more corresponds to a merge.
 */
- (NSArray *)parents;

/**
 * Returns the children of this history node.
 */
- (NSArray *)branches;

/**
 * Mapping of UUID->Version which fully describes what the result of this
 * graph node is. (can be used to get the objects which were modified in this
 * node).
 * Keys are ETUUID, values are NSData containing hashes (which can be used
 * witht the COStore API)
 */
- (NSDictionary *)uuidToObjectVersionMaping;

/**
 * Properties/metadata of the history graph node. Not versioned.
 * Value must be a property-list compatible data type.
 */
- (NSDictionary *)properties;
- (void)setValue: (NSObject*)value forProperty: (NSString*)property;

@end

@interface COHistoryGraphNode (Private)

- (id)       initWithUUID: (ETUUID*)uuid
         storeCoordinator: (COStoreCoordinator*)store
               properties: (NSDictionary*)properties
          parentNodeUUIDs: (NSArray*)parents
           childNodeUUIDs: (NSArray*)children
uuidToObjectVersionMaping: (NSDictionary*)mapping;

- (id) initWithPropertyList: (NSDictionary*)plist storeCoordinator: (COStoreCoordinator *)store;
- (NSDictionary *)propertyList;

- (ETUUID*)uuid;

- (void) addChildNodeUUID: (ETUUID*)child;
@end
