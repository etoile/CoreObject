/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>
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
	COPersistentRoot *editingContext;
	COCommitTrack *parentTrack;
	NSString *label;
	BOOL isMainBranch;
	BOOL isCopy;
}

- (id)initWithUUID: (ETUUID *)aUUID editingContext: (COPersistentRoot *)aContext;

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

@property (readonly, nonatomic) ETUUID *UUID;
@property (retain, nonatomic) NSString *label;
@property (readonly, nonatomic) COCommitTrack *parentTrack;
@property (readonly, nonatomic) CORevision *parentRevision;
/**
 * The persistent root owning the commit track.
 */
@property (readonly, nonatomic) COPersistentRoot *editingContext;

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
- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward;

@end
