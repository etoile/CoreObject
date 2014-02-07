/**
	Copyright (C) 2011 Quentin Mathe

	Date:  December 2011
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COSQLiteStore.h>

@class COObject, COEditingContext, CORevision;
@protocol COTrackNode;

/** 
 * @group Undo
 *
 * TODO: Rewrite
 *
 * COTrack is an abstract class to represent a commit sequence, that can be 
 * persistent or lazily constructed (this depends on the subclass).
 *
 * A track provides a custom view on the history graph that describes the 
 * relations between the persistent object revisions. Each node in the history 
 * graph is a commit or revision.
 *
 * Each track refers to commits or revisions indirectly through COTrackNode 
 * rather CORevision. Hence a track is a track node collection, where every node 
 * is a simple wrapper around a revision object. A track node allows to know to 
 * which track a revision object belongs to.
 */
@protocol COTrack <ETCollection>

/** @taskunit Accessing Track Nodes */

- (NSArray *)nodes;
/**
 * <override-subclass />
 * Returns the node that follows aNode on the track when back is NO, otherwise
 * when back is YES, returns the node that precedes aNode.
 */
- (id <COTrackNode>)nextNodeOnTrackFrom: (id <COTrackNode>)aNode backwards: (BOOL)back;

/** @taskunit Changing Track Nodes */

/**
 * The current node represents the change that was applied to arrive at the
 * current state, or in other words, the change that will be undone if -undo
 * is called.
 */
- (id <COTrackNode>)currentNode;
/**
 * <override-subclass />
 * Sets the current position in the the track timeline to match the track node.
 */
- (BOOL)setCurrentNode: (id <COTrackNode>)node;

/** @taskunit Selective Undo */

/**
 * <override-subclass />
 * Does a selective undo to cancel the changes involved in the track node revision.
 *
 * How the track decides between selective undo vs normal undo/redo is up to 
 * the track subclass.
 */
- (void)undoNode: (id <COTrackNode>)aNode;
/**
 * Same as -undoNode:, but for redoing a node
 */
- (void)redoNode: (id <COTrackNode>)aNode;

/** @taskunit Undo and Redo */

/**
 * Returns whether an undo can be performed
 */
- (BOOL)canUndo;
/**
 * Returns whether a redo can be performed
 */
- (BOOL)canRedo;
/**
 * Performs an undo. The meaning of undo is left up to subclasses.
 */
- (void)undo;
/**
 * Performs a redo. The meaning of redo is left up to subclasses.
 */
- (void)redo;

@end


/**
 * @group Undo
 */
@protocol COTrackNode <NSObject>
/**
 * See -[CORevision metadata].
 */
- (NSDictionary *)metadata;
/**
 * See -[CORevision UUID].
 */
- (ETUUID *)UUID;
/**
 * See -[CORevision persistentRootUUID].
 */
- (ETUUID *)persistentRootUUID;
/**
 * See -[CORevision branchUUID].
 */
- (ETUUID *)branchUUID;
/**
 * See -[CORevision date].
 */
- (NSDate *)date;
/**
 * See -[CORevision localizedTypeDescription].
 */
- (NSString *)localizedTypeDescription;
/** 
 * See -[CORevision localizedShortDescription].
 */
- (NSString *)localizedShortDescription;
@end
