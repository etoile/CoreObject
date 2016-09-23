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
 * @abstract COTrack is a protocol to present changes on a timeline, 
 * manipulate them, and provide a custom view on the store history
 *
 * A track represents usually a revision or commit sequence, but it is up to the 
 * class adopting the protocol to decide about the sequence content (the track 
 * nodes). What constitutes a change from the track standpoint is thus under 
 * the track class responsability. COTrack requires the presented changes to be 
 * objects that conform to COTrackNode. All nodes on a track must also be of 
 * the same kind.
 *
 * @section Built-in Tracks
 *
 * In CoreObject, CORevision and COCommand conform to this track node protocol, 
 * and COBranch and COUndoTrack are track classes that present respectively 
 * revisions and commits as track nodes. 
 *
 * @section Persistency
 *
 * A track content can be persistent (e.g. a normal undo track or a branch) or 
 * lazily constructed (e.g. a pattern undo track, see 
 * +[COUndoTrack trackForPattern:withEditingContext:]).
 *
 * @section Track Node Collection 
 *
 * The track protocol is split in several parts, the core part implements the 
 * logic to navigate track node collection: -nodes, -nextNodeOnTrackFrom:backwards:, 
 * -currentNode and -setCurrentNode:.
 *
 * You should implement these methods first, and then the other methods.
 *
 * A track must also implement ETCollection support based on the core method 
 * listed above.
 *
 * @section Basic Undo and Redo
 *
 * Another part in the protocol is the basic Undo and Redo support that makes 
 * possible to move the current node accross the node collection, and 
 * interprets this move as an undo/redo action.
 *
 * -undo and -redo should usually move the current node in a linear way, but 
 * there is no hard requirements on this point.
 *
 * @section Selective Undo
 *
 * All tracks must also implement -undoNode: and -redoNode: to support selective 
 * undo and redo, which usually move the current node in a non-linear way 
 * unlike -undo and -redo.
 *
 * A selective undo means undoing a single action in the past, while keeping 
 * the more recent actions that depend on the undone one. A normal undo can be 
 * seen as a selective undo subcase where the undone action is the most recent 
 * one. The main difference lies in the fact, a selective undo usually requires 
 * to make a new commit that discards the undone changes while keeping the 
 * other changes that follow on the track. To compute this new commit, -undoNode: 
 * and -redoNode: can leverage the Diff API or some API built on top of it 
 * (e.g. -[COCommand inverse]).
 */
@protocol COTrack <ETCollection>


/** @taskunit Accessing Track Nodes */

/**
 * Returns all the nodes on the track.
 *
 * Calling this methods mean all the nodes will be loaded in memory. For tracks 
 * that can contain 10000 nodes or even more, there is a cost involved, so 
 * the track implementation should rely on -nextNodeOnTrackFrom:backwards: as 
 * much as possible.
 */
@property (nonatomic, readonly) NSArray *nodes;
/**
 * Returns the node that follows aNode on the track when back is NO, otherwise
 * when back is YES, returns the node that precedes aNode.
 *
 * See also -nodes.
 */
- (id <COTrackNode>)nextNodeOnTrackFrom: (id <COTrackNode>)aNode backwards: (BOOL)back;


/** @taskunit Changing Track Nodes */


/**
 * The current node represents the change that was applied to arrive at the
 * current state, or in other words, the change that will be undone if -undo
 * is called.
 *
 * See also -setCurrentNode:.
 */
- (id <COTrackNode>)currentNode;
/**
 * Sets the current position in the the track timeline to match the track node.
 *
 * As a result, the receiver current state will correspond to the change 
 * represented by the given track node.
 *
 * See also -currentNode.
 */
- (BOOL)setCurrentNode: (id <COTrackNode>)node;


/** @taskunit Selective Undo */


/**
 * Does a selective undo to cancel the changes involved in the track node revision.
 *
 * How the track decides between selective undo vs normal undo/redo is up to the 
 * track subclass.
 *
 * See also -redoNode: and -undo.
 */
- (void)undoNode: (id <COTrackNode>)aNode;
/**
 * Same as -undoNode:, but for redoing a node.
 *
 * See also -undoNode: and -redo.
 */
- (void)redoNode: (id <COTrackNode>)aNode;


/** @taskunit Undo and Redo */


/**
 * Returns whether an undo can be performed.
 *
 * See also -undo and -canRedo.
 */
@property (nonatomic, readonly) BOOL canUndo;
/**
 * Returns whether a redo can be performed.
 *
 * See also -redo and -canUndo.
 */
@property (nonatomic, readonly) BOOL canRedo;
/**
 * Performs an undo. The meaning of undo is left up to subclasses.
 *
 * See also -redo and -undoNode:.
 */
- (void)undo;
/**
 * Performs a redo. The meaning of redo is left up to subclasses.
 *
 * See also -undo and -redoNode:
 */
- (void)redo;

@end


/**
 * @group Undo
 * @abstract COTrackNode is protocol to represent a change on a track
 *
 * Every track node is a "simple wrapper" around a concrete change object. As 
 * such, COTrackNode provide a protocol to abstract over all possible change 
 * objects such as CORevision or COCommand.
 *
 * For a detailed discussion, see COTrack.
 */
@protocol COTrackNode <NSObject>
/**
 * See -[CORevision metadata].
 */
@property (nonatomic, readonly, copy) NSDictionary *metadata;
/**
 * See -[CORevision UUID].
 */
@property (nonatomic, readonly, copy) ETUUID *UUID;
/**
 * See -[CORevision persistentRootUUID].
 */
@property (nonatomic, readonly, copy) ETUUID *persistentRootUUID;
/**
 * See -[CORevision branchUUID].
 */
@property (nonatomic, readonly) ETUUID *branchUUID;
/**
 * See -[CORevision date].
 */
@property (nonatomic, readonly) NSDate *date;
/**
 * See -[CORevision localizedTypeDescription].
 */
@property (nonatomic, readonly) NSString *localizedTypeDescription;
/** 
 * See -[CORevision localizedShortDescription].
 */
@property (nonatomic, readonly) NSString *localizedShortDescription;
/**
 * Returns the parent node of this node, or nil if there is none.
 */
@property (nonatomic, readonly) id <COTrackNode> parentNode;
/**
 * Returns the merge parent node of this node, or nil if there is none.
 */
@property (nonatomic, readonly) id <COTrackNode> mergeParentNode;

@end
