#import <Foundation/Foundation.h>
#import <ObjectMerging/COTrack.h>

@class COObject, CORevision;

/**
 * A persistent history track on an object.
 * 
 * Unlike COHistoryTrack, COCommitTrack is built to:
 * <list>
 * <item>track a single object</item>
 * <item>persist the track nodes and the current node</item>
 * <item>move the current node to the next or previous track node, to move the 
 * undo/redo pointer in the track timeline</item>
 * </list>
 */
@interface COCommitTrack : COTrack
{
	@private
	COObject *trackedObject;
}

/** @taskunit Tracked Objects */

/**
 * The root object for which the commit track persists the history.
 */
@property (readonly, nonatomic) COObject *trackedObject;

/** @taskunit Private */

- (void)newCommitAtRevision: (CORevision*)revision;
- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward;

@end
