/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COSQLiteStore.h>

@class COObject, COEditingContext, CORevision;
@protocol COTrackNode;

/** 
 * @group History Navigation
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
 * Returns the current track node that reflects the current position in the 
 * the track timeline. 
 */
- (id <COTrackNode>)currentNode;
/**
 * <override-subclass />
 * Sets the current position in the the track timeline to match the track node.
 */
- (void)setCurrentNode: (id <COTrackNode>)node;

/** @taskunit Selective Undo */

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
- (void)undoNode: (id <COTrackNode>)aNode;

@end


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
