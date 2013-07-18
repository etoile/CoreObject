/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>,
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COTrack.h>

@class COObject, CORevision, COPersistentRoot, COBranchInfo;

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
@interface COBranch : NSObject
{
	@private
    ETUUID *UUID;
    
    /**
     * Weak reference
     */
	COPersistentRoot *persistentRoot;
}

/** @taskunit Initialization */

/**
 * <init />
 * Intializes and returns a new commit track known by the given UUID and bound 
 * to a particular persistent root.
 *
 * For nil UUID or persistent root, raises a NSInvalidArgumentException.
 */
- (id)initWithUUID: (ETUUID *)aUUID persistentRoot: (COPersistentRoot *)aContext;

/** @taskunit Track Kind */

/**
 * Returns whether the commit track represents a cheap copy.
 *
 * When the receiver is a cheap copy, -isBranch returns NO.
 */
@property (readonly, nonatomic) BOOL isCopy;

// FIXME: Rename to isTrunk (opposite)
/**
 * Returns whether the commit track represents a branch.
 *
 * When the receiver is a branch, -isCopy returns NO.
 */
@property (readonly, nonatomic) BOOL isBranch;
/**
 * Returns whether the commit track represents a persistent root main branch.
 *
 * Unless an explicit branch is requested, a persistent root uses the main 
 * branch as its current branch at loading time.<br />
 * For a nil commit track, COPersistentRoot initializer retrieves 
 * the main branch commit track and sets it as the current commit track (aka 
 * current branch). See 
 * -[COPersistentRoot initWithPersistentRootUUID:commitTrackUUID:rootObject:parentContext:].
 */
@property (readonly, nonatomic) BOOL isMainBranch;

/** @taskunit Basic Properties */

/**
 * The commit track UUID.
 *
 * The UUID is never nil.
 */
@property (readonly, nonatomic) ETUUID *UUID;
/**
 * The commit track label, that serves a branch name in most cases.
 */
@property (readonly, nonatomic) NSString *label;
/**
 * The parent commit track from which the receiver is derived.
 *
 * If the parent track is nil, this means the receiver is a commit track that 
 * was created at the same time than its persistent root. The parent revision 
 * is also nil in this case.
 */
@property (readonly, nonatomic) COBranch *parentTrack;
/**
 * The revision at which the receiver was forked from the parent track.
 *
 * If the parent revision is nil, this means the receiver is a commit track that
 * was created at the same time than its persistent root. The parent track 
 * is also nil in this case.
 */
@property (readonly, nonatomic) CORevision *parentRevision;
@property (readonly, nonatomic) CORevision *currentRevision;
/**
 * The persistent root owning the commit track.
 *
 * The persistent doesn't retain the commit track unless the receiver is the 
 * same than -[COPersistentRoot commitTrack]. The ownership implied here is at 
 * the store level.
 */
@property (readonly, nonatomic) COPersistentRoot *persistentRoot;

/** @taskunit Creating Branches and Cheap copies */

// TODO: Convert these methods to logging the change in the editing context and saving it
// at commit time.

/**
 * Returns a new commit track by branching the receiver last revision and using 
 * the given label.
 *
 * See also -makeBranchWithLabel:atRevision:.
 */
- (COBranch *)makeBranchWithLabel: (NSString *)aLabel;
/**
 * Returns a new commit track by branching a particular revision and using
 * the given label.
 *
 * The revision must belong to the receiver track, otherwise a 
 * NSInvalidArgumentException is raised.
 *
 * The branch creation results in a new revision on the store structure track. 
 * See -[COStore createCommitTrackWithUUID:name:parentRevision:rootObjectUUID:persistentRootUUID:isNewPersistentRoot:].
 *
 * You can assign the returned commit track to the receiver persistent root to 
 * switch the current branch. For example:
 *
 * <example>
 * [persistentRoot setCommitTrack: [[persistentRoot commitTrack] makeBranchWithLabel: @"Sandbox"]];
 * </example>
 */
- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev;
/**
 * Returns a new persistent root bound to a new commit track by branching a 
 * particular revision.
 * 
 * The resulting persistent root is known as a cheap copy, because the copy 
 * doesn't cause the history leading to the new persistent root state to be 
 * duplicated in the store.
 *
 * Although we usually don't call a cheap copy a branch, the new commit track 
 * is a branch from the viewpoint of the history graph.
 *
 * The revision must belong to the receiver track, otherwise a
 * NSInvalidArgumentException is raised.
 */
- (COPersistentRoot *)makeCopyFromRevision: (CORevision *)aRev;

/** @taskunit Merging Between Tracks */

/**
 * This method is not yet implemented.
 */
- (BOOL)mergeChangesFromTrack: (COBranch *)aSourceTrack;
/**
 * This method is not yet implemented.
 */
- (BOOL)mergeChangesFromRevision: (CORevision *)startRev
							  to: (CORevision *)endRev
						 ofTrack: (COBranch *)aSourceTrack;
/**
 * This method is not yet implemented.
 */
- (BOOL)mergeChangesFromRevisionSet: (NSSet *)revs
							ofTrack: (COBranch *)aSourceTrack;

/** @taskunit Private */

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the receiver that its persistent root just committed a new revision. 
 * 
 * The committed revision is included among the loaded track nodes as a result,  
 * and without accessing the store.
 */
- (void)didMakeNewCommitAtRevision: (CORevision *)revision;

@end
