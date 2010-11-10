#import <EtoileFoundation/EtoileFoundation.h>
#import "COHistoryNode.h"
#import "COObjectGraphDiff.h"
#import "COStore.h"

@class COHistoryNode;
@class COObjectGraphDiff;
@class COEditingContext;

extern NSString * const COStoreDidCommitNotification;

/**
 * High-level interface to the storage layer. Creates and manages HistoryGraphNodes.
 *
 * Will probably also handle things like network collaboration, generating notifications
 * when the underlying store is modified by another process, and presenting
 * several stores (i.e. on-disk object bundle directories) together as one.
 */
@interface COStoreCoordinator : NSObject
{
	COStore *_store;
	NSMutableDictionary *_historyGraphNodes;
}

- (id)initWithURL: (NSURL*)url;

/**
 * most recently changed head history node (from mercurial terminology)
 * FIXME: is this guaranteed to be non-nil? 
 */
- (COHistoryNode *)tip;

//- (NSArray*)rootHistoryGraphNodes;

/**
 * Creates a new history graph node afer the given node which is a branch.
 * Returns the new node.
 */
- (COHistoryNode *) createBranchOfNode: (COHistoryNode*)node;
/**
 * Creates a new history graph node merging two existing nodes.
 * Returns the new node.
 */
- (COHistoryNode *) createMergeOfNode: (COHistoryNode*)node1 andNode: (COHistoryNode*)node2;
/**
 * Commits the changes in the given object context as a new history graph node
 * Returns the new node
 */
- (COHistoryNode *) commitChangesInObjectContext: (COEditingContext *)ctx
                                            afterNode: (COHistoryNode*)node
                                         withMetadata: (NSDictionary*)metadata;
/**
 * Commits some changed objects as a new history graph 
 * Returns the new node
 */
- (COHistoryNode *) commitChangesInObjects: (NSArray *)objects
                                      afterNode: (COHistoryNode*)node
                                   withMetadata: (NSDictionary*)metadata;
@end

/**
 * Interface used in the implementation of COObject/COObjectContext
 */
@interface COStoreCoordinator (Private)

/**
 * Returns the internal data dictionary for the given object UUID,
 * in the state it was in at the given history graph node.
 *
 * If the object with that UUID was not modified in the given hist. node,
 * This would handle finding the nearest anestor node where it was modified
 * and then fetch that particular version of the object from the underlying
 * store.
 *
 * Note: not cached
 * Note: caller's responsibility to modify output to have actualy COObject references
 */
- (NSDictionary*) dataForObjectWithUUID: (ETUUID*)uuid atHistoryGraphNode: (COHistoryNode *)node;

- (COHistoryNode *) historyGraphNodeForUUID: (ETUUID*)uuid;
- (void) commitHistoryGraphNode: (COHistoryNode *)node;

- (COHistoryNode *) commitObjectDatas: (NSArray *)datas
                                 afterNode: (COHistoryNode*)node
                              withMetadata: (NSDictionary*)metadata
                       withHistoryNodeUUID: (ETUUID*)uuid;

@end