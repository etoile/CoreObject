#import <EtoileFoundation/EtoileFoundation.h>
#import "COCommit.h"
#import "COObjectGraphDiff.h"
#import "COStore.h"

@class COCommit;
@class COObjectGraphDiff;
@class COEditingContext;

extern NSString * const COStoreDidCommitNotification;

/**
 * High-level interface to the storage layer.
 *
 * The CoreObject store contains two types of data:
 *
 *  1. COCommit objects. These are the fundamental storage unit in CoreObject
 *
 *  2. Metadata describing the current state of the object graph. This supports 
 *     branches, and history tracks for undo/redo.
 *
 *     In general, the history (commit) graph for each CoreObject has a pair of
 *     tags ('tip' and 'current') for each branch of that object.
 *     The 'tip' tag points to the newest commit on a branch; typically,
 *     'current' will be equal to 'tip', however, undo operations move the 
 *     'current' tag away from 'tip' to point to older commits.
 *
 * The difference between named and anonymous branches is that named branches 
 * preserve the tip/current tags, whereas anonymous branches do not (they are 
 * just parts of the graph that happen to be branches)
 *
 * Will probably also handle things like network collaboration, generating notifications
 * when the underlying store is modified by another process, and presenting
 * several stores (i.e. on-disk object bundle directories) together as one.
 */
@interface COStoreCoordinator : NSObject
{
@package
	COStore *_store;
	NSMutableDictionary *_historyGraphNodes;
}

- (id)initWithURL: (NSURL*)url;

- (COHistoryView*)globalHistoryView;
- (COHistoryView*)historyViewWithNamedBranch: (CONamedBranch*)branch;
- (COHistoryView*)historyTrackForObjectsWithUUIDs: (NSArray*)uuids;
- (COHistoryView*)historyTrackForContainer: (COObject*)container;

- (COCommit *) commitObjectDatas: (NSArray *)objectDatas
				parentNodeArrays: (COCommit*)node
				 onNamedBranches: (NSArray*)branches
					withMetadata: (NSDictionary*)metadata
						setAsTip: (BOOL)setAsTip;


@end









// Old API

#if 0
/**
 * The
 */
- (COCommit *)headCommitForObjectUUID: (ETUUID*)uuid;


/**
 * Commits the changes in the given object context as a new history graph node
 * Returns the new node
 */
- (COCommit *) commitChangesInObjectContext: (COEditingContext *)ctx
                                            afterNode: (COCommit*)node
							   withMetadata: (NSDictionary*)metadata
					setAsLatestCommit: (BOOL)setAsLatest;
/**
 * Commits some changed objects as a new history graph 
 * Returns the new node
 */
- (COCommit *) commitChangesInObjects: (NSArray *)objects
                                      afterNode: (COCommit*)node
                                   withMetadata: (NSDictionary*)metadata
					setAsLatestCommit: (BOOL)setAsLatest;

/**
 * Low-level commit method. Usually use one of the helper methods instead.
 */
- (COCommit *) commitChangesInObjects: (NSArray *)objects
  					parentNodeArrays: (COCommit*)node
						 withMetadata: (NSDictionary*)metadata
					setAsLatestCommit: (BOOL)setAsLatest;


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
- (NSDictionary*) dataForObjectWithUUID: (ETUUID*)uuid atCommit: (COCommit *)node;

- (COCommit *) historyGraphNodeForUUID: (ETUUID*)uuid;
- (void) commitHistoryGraphNode: (COCommit *)node;

@end
#endif