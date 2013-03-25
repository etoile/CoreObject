/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>,
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COTrack.h>

@class COObject, CORevision, COPersistentRoot;

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
	ETUUID *UUID;
	COPersistentRoot *persistentRoot;
	COCommitTrack *parentTrack;
	NSString *label;
	BOOL isMainBranch;
	BOOL isCopy;
	BOOL isLoaded;
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
@property (retain, nonatomic) NSString *label;
/**
 * The parent commit track from which the receiver is derived.
 *
 * If the parent track is nil, this means the receiver is a commit track that 
 * was created at the same time than its persistent root. The parent revision 
 * is also nil in this case.
 */
@property (readonly, nonatomic) COCommitTrack *parentTrack;
/**
 * The revision at which the receiver was forked from the parent track.
 *
 * If the parent revision is nil, this means the receiver is a commit track that
 * was created at the same time than its persistent root. The parent track 
 * is also nil in this case.
 */
@property (readonly, nonatomic) CORevision *parentRevision;
/**
 * The persistent root owning the commit track.
 *
 * The persistent doesn't retain the commit track unless the receiver is the 
 * same than -[COPersistentRoot commitTrack]. The ownership implied here is at 
 * the store level.
 */
@property (readonly, nonatomic) COPersistentRoot *persistentRoot;

/** @taskunit Creating Branches and Cheap copies */

- (COCommitTrack *)makeBranchWithLabel: (NSString *)aLabel;
- (COCommitTrack *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev;
- (COCommitTrack *)makeCopyFromRevision: (CORevision *)aRev;

/** @taskunit Merging Between Tracks */

- (BOOL)mergeChangesFromTrack: (COCommitTrack *)aSourceTrack;
- (BOOL)mergeChangesFromRevision: (CORevision *)startRev
							  to: (CORevision *)endRev
						 ofTrack: (COCommitTrack *)aSourceTrack;
- (BOOL)mergeChangesFromRevisionSet: (NSSet *)revs
							ofTrack: (COCommitTrack *)aSourceTrack;

/** @taskunit Private */

/**
 * COStore takes care of updating the database, so we just use this as a
 * notification to update our cache.
 */
- (void)didMakeNewCommitAtRevision: (CORevision *)revision;

@end
