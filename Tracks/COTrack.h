/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COStore.h>

@class COObject, COEditingContext, CORevision;
@class COTrackNode;

/** 
 * @group History Navigation
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
@interface COTrack : NSObject <ETCollection, COTrackNodeBuilder>
{
	@private
	NSMutableArray *loadedNodes;
	BOOL isLoading;
	@protected
	// TODO: Would be better to make the ivar below private rather than 
	// protected but this makes the code much more verbose in subclasses.
	NSUInteger currentNodeIndex;
}

/** @taskunit Initialization */

/**
 * <init />
 */
- (id)init;

/** @taskunit Type Querying */

/**
 * Returns YES.
 *
 * See also -[NSObject isTrack].
 */
@property (nonatomic, readonly) BOOL isTrack;

/** @taskunit Tracked Objects */

/**
 * <override-subclass />
 * The tracked objects.
 *
 * By default, returns an empty set.
 */
@property (readonly, nonatomic) NSSet *trackedObjects;

/** @taskunit Loading and Providing Track Nodes */

/**
 * <override-never />
 * Returns the loaded track nodes.
 *
 * The loaded nodes can be all the nodes on the track or a subset.
 *
 * This method is restricted to subclassing purpose. For other purposes, you 
 * must use -[ETCollection content] or -[ETCollection contentArray].
 *
 * Subclasses are allowed to mutate the returned collection.
 *
 * For a new track, returns an empty array.
 */
- (NSMutableArray *)loadedNodes;
/**
 * <override-subclass />
 * Returns track nodes that encloses the current node on the track.
 *
 * The returned track node range is undetermined. The returned range might vary
 * to get a more responsive UI (e.g. browsing a track content).
 *
 * The current node index among these nodes is returned through aNodeIndex.
 */
- (NSArray *)provideNodesAndCurrentNodeIndex: (NSUInteger *)aNodeIndex;
/**
 * <override-never />
 * Asks the receiver to discard the loaded track nodes and get the latest nodes 
 * using -provideNodesAndCurrentNodeIndex:.
 *
 * The track nodes are usually provided by the store.
 */
- (void)reloadNodes;
/**
 * <override-dummy />
 * Tells the receiver that the latest track nodes have been loaded using 
 * -reloadNodes.
 */
- (void)didReloadNodes;
/**
 * <override-subclass />
 * Returns the node that follows aNode on the track when back is NO, otherwise
 * when back is YES, returns the node that precedes aNode.
 *
 * Default implementation returns nil.
 */
- (COTrackNode *)nextNodeOnTrackFrom: (COTrackNode *)aNode backwards: (BOOL)back;
/**
 * Returns a new autoreleased track node based on the given node ID and revision.
 *
 * Default implementation returns a COTrackNode instance.
 *
 * Can be overriden to build objects from a COTrackNode subclass.
 *
 * See COTrackNodeBuilder and 
 * -[COStore nodesForTrackUUID:nodeBuilder:currentNodeIndex:backwardLimit:forwardLimit:].
 */
- (COTrackNode *)makeNodeWithID: (int64_t)aNodeID revision: (CORevision *)aRevision;

/** @taskunit Changing Track Nodes */

/**
 * Returns the current track node that reflects the current position in the 
 * the track timeline. 
 */
- (COTrackNode *)currentNode;
/**
 * <override-subclass />
 * Sets the current position in the the track timeline to match the track node.
 */
- (void)setCurrentNode: (COTrackNode *)node;
/**
 * Posts ETSourceDidUpdateNotification.
 *
 * You must invoke this method every time the track node collection is changed.
 * For example, when you override -setCurrentNode:, -undo, -redo, and -undoNode:.
 *
 * EtoileUI relies on this notification to reload the UI transparently.
 */
- (void)didUpdate;

/** @taskunit Undo Management */

/**
 * <override-subclass />
 * Moves backward on the track to undo.
 *
 * When -canUndo returns NO, the method must return immediately.
 *
 * An undo corresponds to changing the current track node to some previous node. 
 * What <em>previous</em> means precisely is up to the track subclass.
 */
- (void)undo;
/**
 * <override-subclass />
 * Moves forward on the track to redo.
 *
 * When -canRedo returns NO, the method must return immediately.
 *
 * A redo corresponds to changing the current track node to some next node. 
 * What <em>next</em> means precisely is up to the track subclass.
 */
- (void)redo;
/**
 * <override-subclass />
 * Does a selective undo to cancel the changes involved in the track node revision.
 *
 * For a selective undo, this method must invoke 
 * -selectiveUndoWithRevision:inEditingContext:.
 *
 * How the track decides between selective undo vs normal undo/redo is up to 
 * the track subclass.
 */
- (void)undoNode: (COTrackNode *)aNode;
/**
 * <override-never />
 * Does a selective undo to cancel the changes involved in the revision.
 *
 * Both arguments must not be nil, otherwise raises a NSInvalidArgumentException.
 */
- (void)selectiveUndoWithRevision: (CORevision *)revToUndo 
                 inEditingContext: (COEditingContext *)ctxt;
/**
 * <override-never />
 * Returns whether undo is possible (i.e. some revision can be undone).
 *
 * For subclasses, this implies the current node has a valid next node.
 */
- (BOOL)canUndo;
/**
 * <override-never />
 * Returns whether redo is possible (i.e. some revision can be redone).
 *
 * For subclasses, this implies the current node has a valid previous node.
 */
- (BOOL)canRedo;
@end


@interface COTrackNode : NSObject <ETCollection>
{
	@private
	CORevision *revision;
	COTrack *track;
}

/** @taskunit Initialization */

/** <init /> */
+ (id)nodeWithRevision: (CORevision *)aRevision onTrack: (COTrack *)aTrack;

/** @taskunit Basic Properties */

/**
 * Returns the revision wrapped by the track node.
 */
- (CORevision *)revision;
/**
 * Returns the track that owns the receiver.
 */
- (COTrack *)track;

/** @taskunit Node Traversal */

/**
 * Returns the node whose revision is the next on the track.
 */
- (COTrackNode *)previousNode;
/**
 * Returns the node whose revision is the previous on the track.
 */
- (COTrackNode *)nextNode;

/** @taskunit Metadata */

/**
 * See -[CORevision metadata].
 */
- (NSDictionary *)metadata;
/**
 * See -[CORevision UUID].
 */
- (CORevisionID *)revisionID;
/**
 * See -[CORevision persistentRootUUID].
 */
- (ETUUID *)persistentRootUUID;
/**
 * See -[CORevision branchUUID].
 */
- (ETUUID *)branchkUUID;
/**
 * See -[CORevision objectUUID].
 */
- (ETUUID *)objectUUID;
/**
 * See -[CORevision date].
 */
- (NSDate *)date;
/**
 * See -[CORevision type].
 */
- (NSString *)type;
/** 
 * See -[CORevision shortDescription].
 */
- (NSString *)shortDescription;
/** 
 * See -[CORevision longDescription].
 */
- (NSString *)longDescription;
#if 0
/**
 * See -[CORevision changedObjectUUIDs].
 */
- (NSArray *)changedObjectUUIDs;
#endif
@end
