/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>,
	         Quentin Mathe <quentin.mathe@gmail.com>,
	         Eric Wasylishen <ewasylishen@gmail.com>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COTrack.h>

@class COObject, CORevision, CORevisionID, COPersistentRoot, COBranchInfo, COObjectGraphContext, COEditingContext;
@class COItemGraphDiff, COMergeInfo;

extern NSString * const kCOBranchLabel;

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
@interface COBranch : NSObject <COTrack>
{
	@private
    ETUUID *_UUID;
    
    /**
     * Weak reference
     */
	COPersistentRoot *__weak _persistentRoot;

    BOOL _isCreated;
    
    /** 
     * If _isCreated is NO, this is the parent revision to use for the branch.
     *
     * If this is different than the current revision for this branch
     * recorded in _persistentRoot's _savedState, it means the user has reverted
     * to a past revision.
     */
	CORevisionID *_currentRevisionID;
    
    /**
     * If different than the metadata for this branch in _persistentRoot's _savedState,
     * then a metadata change is staged for commit.     
     */
    NSMutableDictionary *_metadata;
    
    BOOL _metadataChanged;
    
    COObjectGraphContext *_objectGraph;

    ETUUID *_parentBranchUUID;
	NSMutableArray *_revisions;
}


/** @taskunit Branch Kind */


/**
 * Returns whether the branch represents a cheap copy.
 */
@property (readonly, nonatomic) BOOL isCopy;
/**
 * Returns whether the receiver is the current branch of its persistent root.
 */
@property (readonly, nonatomic) BOOL isCurrentBranch;

/**
 * Returns whether the receiver was the first branch of its persistent root
 */
@property (readonly, nonatomic) BOOL isTrunkBranch;


/** @taskunit Basic Properties */


/**
 * The branch UUID.
 *
 * The UUID is never nil.
 */
@property (strong, readonly, nonatomic) ETUUID *UUID;
/**
 * The branch label (used as the branch name in most cases).
 */
@property (readwrite, copy, nonatomic) NSString *label;
/**
 * The metadata attached to the branch.
 *
 * Any changes to the metadata is saved on the next object graph context commit.
 */
@property (readwrite, copy, nonatomic) NSDictionary *metadata;
/** 
 * The branch deletion status.
 *
 * If the branch is marked as deleted, the deletion is committed to the store 
 * on the next persistent root commit.
 */
@property (readwrite, nonatomic, getter=isDeleted, setter=setDeleted:) BOOL deleted;


/** @taskunit History */


/**
 * The parent branch from which the receiver is derived.
 *
 * If the parent branch is nil, this means the receiver is a branch that was 
 * created at the same time than its persistent root. The parent revision is 
 * also nil in this case.
 *
 * For a cheap copy, the parent branch is never nil.
 */
@property (strong, readonly, nonatomic) COBranch *parentBranch;
/**
 * The revision at which the receiver was forked from the parent branch.
 *
 * If the parent revision is nil, this means the receiver is a branch that was 
 * created at the same time than its persistent root. The parent branch is also 
 * nil in this case.
 */
@property (strong, readonly, nonatomic) CORevision *initialRevision;
/**
 * The revision bound to the state loaded in the object graph context.
 *
 * If the branch is uncommitted, the current revision is nil.
 */
@property (readwrite, strong, nonatomic) CORevision *currentRevision;

- (void)reloadAtRevision: (CORevision *)revision;


/** @taskunit Persistent Root and Object Graph Context */


/**
 * The editing context owning the branch's persistent root
 */
@property (weak, readonly, nonatomic) COEditingContext *editingContext;
/**
 * The persistent root owning the branch.
 */
@property (weak, readonly, nonatomic) COPersistentRoot *persistentRoot;
/**
 * The object graph context owned by the branch.
 */
@property (readonly, nonatomic) COObjectGraphContext *objectGraphContext;
/**
 * The root object of the object graph context owned by the branch.
 */
@property (nonatomic, strong) id rootObject;

/**
 * @taskunit Pending Changes
 */


/**
 * Returns whether any object has been inserted, deleted or updated since the
 * last commit.
 *
 * See also -changedObjects.
 */
- (BOOL)hasChanges;
- (void)discardAllChanges;
/**
 * If set to YES, the next  commit in the editing context will write a
 * new revision on this branch, even if there are no changes to be written.
 *
 * Would be used to cause a "checkpoint" revision to be written.
 */
@property (readwrite, nonatomic) BOOL shouldMakeEmptyCommit;


/** @taskunit Creating Branches and Cheap copies */


/**
 * Returns a new commit track by branching the receiver last revision and using 
 * the given label.
 *
 * The receiver must be committed.
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
 *
 * One restriction is that the receiver must be committed - not a newly
 * created branch, or the default branch of a persistent root. This is just for
 * implementation simplicity, not a fundamental design limitation.
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
 *
 * The receiver must be committed.
 */
- (COPersistentRoot *)makeCopyFromRevision: (CORevision *)aRev;


/** @taskunit Merging Between Tracks */

/**
 * Branch that is currently being merged. Always returns nil unless explicitly
 * set. If it is set at commit time, records the _current revision_ of the
 * mergingBranch as the merge parent of the new commit.
 */
@property (readwrite, nonatomic, strong) COBranch *mergingBranch;

- (COMergeInfo *) mergeInfoForMergingBranch: (COBranch *)aBranch;

- (COMergeInfo *) mergeInfoForMergingRevision:(CORevision *)aRevision;

/**
 * Searches for whether the given revision is on this branch.
 * Returns the corresponding CORevision if it is, or nil if not.
 *
 * Note that this means nil will be returned if the given revision is not on
 * this branch, even if it on another branch of this persistent root.
 */
- (CORevision *) revisionWithID: (CORevisionID *)aRevisionID;

@end
