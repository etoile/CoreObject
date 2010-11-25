#import <Cocoa/Cocoa.h>
#import "COCommit.h"
#import "COObject.h"

@class COHistoryTrackNode;

/**
 * A history track is a view on the database of commits, presenting
 * them as a history graph. It is not persistent or cached in any way.
 *
 * It also allow exposes a simlpe NSUndoManager-like way of navigating
 * history.
 *
 * It's bound to a context so changes to the history track
 */
@interface COHistoryTrack : NSObject
{
	COObject *obj; // we'll make changes to its context
}

/**
 * COHistoryTrack gives lets you make manipulations to the state of the store
 * like doing an undo with respect to a particular group of objects. It delegates
 * the actual changes to an editing context, where they must be committed.
 */
- (id)initTrackWithObject: (COObject*)container containedObjects: (BOOL)contained;

- (COHistoryTrackNode*)tipNode;
- (COHistoryTrackNode*)currentNode;

/**
 * Convience method moves the current node one node closer to the tip, on
 * the path defined by starting at the tipNode and following parent pointers.
 */
- (COHistoryTrackNode*)moveCurrentNodeForward;
/** 
 * Same as above, but moves one node away from the tip.
 */
- (COHistoryTrackNode*)moveCurrentNodeBackward;

/**
 * This figures out what current nodes need to be moved on the object
 * history graph, and moves them in ctx
 */
- (void)setCurrentNode: (COHistoryTrackNode*)node;
/**
 * Moves the tip node
 */
- (void)setTipNode: (COHistoryTrackNode*)node;


- (NSArray*)namedBranches;

- (CONamedBranch*)currentBranch;

/**
 * Changes the branch. Note that this effectively rebuilds the history track,
 * so tip node and current node will be different.
 */
- (void)setNamedBranch: (CONamedBranch*)branch;

/* Private */

- (NSArray*)changedObjectsForCommit: (COCommit*)commit;
- (COHistoryTrackNode*)parentForCommit: (COCommit*)commit;
- (COHistoryTrackNode*)mergedNodeForCommit: (COCommit*)commit;
- (NSArray*)childNodesForCommit: (COCommit*)commit;

@end


@interface COHistoryTrackNode
{
	COCommit *commit;
	COHistoryTrack *ownerTrack;
}

- (NSDictionary*)metadata;
- (NSArray*)changedObjects;

/* History graph */

- (COHistoryTrackNode*)parent;
- (COHistoryTrackNode*)mergedNode;
- (NSArray*)childNodes;

/* Private */

- (COCommit*)underlyingCommit;

@end