#import <Cocoa/Cocoa.h>
#import "CORevision.h"
#import "COObject.h"

@class COHistoryTrackNode;

/**
 * A history track is a view on the database of commits, presenting
 * them as a history graph. It is not persistent or cached in any way.
 *
 * It also allow exposes a simlpe NSUndoManager-like way of navigating
 * history.
 */
@interface COHistoryTrack : NSObject
{
	COObject *obj;
	BOOL affectsContainedObjects;
}

/**
 * COHistoryTrack gives lets you make manipulations to the state of the store
 * like doing an undo with respect to a particular group of objects. It delegates
 * the actual changes to an editing context, where they must be committed.
 */
- (id)initTrackWithObject: (COObject*)container containedObjects: (BOOL)contained;

- (COHistoryTrackNode*)currentNode;

- (void)redo;
- (void)undo;

/**
 * This figures out what current nodes need to be moved on the object
 * history graph, and moves them in ctx
 */
- (void)setCurrentNode: (COHistoryTrackNode*)node;


/* Private */

- (NSArray*)changedObjectsForCommit: (CORevision*)commit;
- (COHistoryTrackNode*)parentForCommit: (CORevision*)commit;
- (COHistoryTrackNode*)mergedNodeForCommit: (CORevision*)commit;
- (NSArray*)childNodesForCommit: (CORevision*)commit;

@end


@interface COHistoryTrackNode
{
	CORevision *commit;
	COHistoryTrack *ownerTrack;
}

- (NSDictionary*)metadata;
- (NSArray*)changedObjects;

/* History graph */

- (COHistoryTrackNode*)parent;
- (COHistoryTrackNode*)mergedNode;
- (NSArray*)childNodes;

/* Private */

- (CORevision*)underlyingCommit;

@end