#import <EtoileFoundation/EtoileFoundation.h>
#import "COHistoryGraphNode.h"
#import "COObjectGraphDiff.h"
#import "COStore.h"

@class COHistoryGraphNode;
@class COObjectGraphDiff;
@class COObjectContext;

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
 */
- (COHistoryGraphNode *)tip;

//- (NSArray*)rootHistoryGraphNodes;

/**
 * Creates a new history graph node afer the given node which is a branch.
 * Returns the new node.
 */
- (COHistoryGraphNode *) createBranchOfNode: (COHistoryGraphNode*)node;
/**
 * Creates a new history graph node merging two existing nodes.
 * Returns the new node.
 */
- (COHistoryGraphNode *) createMergeOfNode: (COHistoryGraphNode*)node1 andNode: (COHistoryGraphNode*)node2;
/**
 * Commits the changes in the given object context as a new history graph node
 * Returns the new node
 */
- (COHistoryGraphNode *) commitChangesInObjectContext: (COObjectContext *)ctx  afterNode: (COHistoryGraphNode*)node;
/**
 * Commits some changed objects as a new history graph 
 * Returns the new node
 */
- (COHistoryGraphNode *) commitChangesInObjects: (NSArray *)objects afterNode: (COHistoryGraphNode*)node;

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
- (NSDictionary*) dataForObjectWithUUID: (ETUUID*)uuid atHistoryGraphNode: (COHistoryGraphNode *)node;

- (COHistoryGraphNode *) historyGraphNodeForUUID: (ETUUID*)uuid;
- (void) commitHistoryGraphNode: (COHistoryGraphNode *)node;

@end