/**
    Copyright (C) 2011 Quentin Mathe, Eric Wasylishen, Christopher Armstrong

    Date:  September 2011
    License:  MIT  (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COTrack.h>

@class COObject, CORevision, COPersistentRoot, COBranchInfo, COObjectGraphContext, COEditingContext;
@class CODiffManager, COMergeInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * The key that corresponds to the branch name in -[COBranch metadatata].
 *
 * See also -[COBranch name].
 */
extern NSString *const kCOBranchLabel;

/**
 * @group Core
 * @abstract A branch is a pointer to a revision in the history graph. It 
 * represents a variation of a persistent root.
 *
 * @section Conceptual Model
 *
 * -currentRevision is the most important property of a branch, that defines 
 * which revision the branch views. 
 *
 * Branches are central to the process of committing changes in inner objects.
 * To commit changes in the branch's COObjectGraphContext, a new revision
 * is created with the changes, and the -currentRevision property is modified 
 * to point to the new revision.
 *
 * The -headRevision is an extra detail that gives branches a primitive form of 
 * undo/redo. When -currentRevision is reverted to an older revision, 
 * -headRevision remains in the same place, making it possible to "redo", i.e. 
 * move the current revision back towards -headRevision. This primitive 
 * undo/redo is exposed by the COTrack API.
 *
 * @section Common Use Cases
 *
 * The most common use case would be accessing the object graph through
 * -objectGraphContext, or reverting to an old revision with the 
 * -currentRevision property.
 *
 * @section Attributes and Metadata
 *
 * The -metadata property behaves just like COPersistentRoot's. It can be set 
 * to a JSON compatible NSDictionary to store arbitrary application metadata. 
 * This property is persistent, but not versioned (although metadata changes 
 * can will be undone/redone by COUndoTrack, if the commit that changes the 
 * metadata is recorded to a track).
 *
 * @section Creation
 *
 * Branches are never instantiated directly, but each new persistent root 
 * includes an initial branch. You can access persistent root's branches 
 * through -[COPersistentRoot branchForUUID:] and 
 * -[COPersistentRoot currentBranch] for the "default" branch.
 *
 * For existing persistent roots, new branches can be created by branching 
 * existing branches with -makeBranchWithLabel:atRevision: or 
 * -makeBranchWithLabel:.
 *
 * @section Cheap Copies
 *
 * Branches support a kind of cheap copy, which is really just creating a new
 * branch starting at the same revision as the receiver (and with the parent 
 * branch metadata set). See -makePersistentRootCopyFromRevision: or  
 * -makePersistentRootCopy.
 *
 * @section Deletion
 *
 * Branches follow a similar pattern for deletion as Persistent Roots, with a 
 * -deleted flag. Modifying the flag marks the branch as having changes to 
 * commit. Having the -deleted flag set and committed is like having a file in 
 * the trash. The branch can be undeleted by simply setting the -deleted flag 
 * to NO and committing that change.
 *
 * Branches play a role in the deletion model for revisions, which are garbage 
 * collected (like git). When a branch has the deleted flag set to YES, it is 
 * possible for CoreObject to irreversibly delete the branch and any revisions
 * that are only accessible by the branch. Revisions will never be deleted if 
 * there is some non-deleted branch that can access them.
 */
@interface COBranch : NSObject <COTrack>
{
@private
    ETUUID *_UUID;
    COPersistentRoot *__weak _persistentRoot;
    BOOL _isCreated;
    /** 
     * If _isCreated is NO, this is the parent revision to use for the branch.
     *
     * If this is different than the current revision for this branch
     * recorded in _persistentRoot's _savedState, it means the user has reverted
     * to a past revision.
     */
    ETUUID *_currentRevisionUUID;
    ETUUID *_headRevisionUUID;
    /**
     * If different than the metadata for this branch in _persistentRoot's 
     * _savedState, then a metadata change is staged for commit.     
     */
    NSMutableDictionary *_metadata;
    BOOL _metadataChanged;
    BOOL _supportsRevert;
    COObjectGraphContext *_objectGraph;
    BOOL _shouldMakeEmptyCommit;
    ETUUID *_parentBranchUUID;
    NSMutableArray *_revisions;
    COBranch *_mergingBranch;
    CORevision *_mergingRevision;
}


/** @taskunit Branch Kind */


/**
 * Returns whether the branch represents a cheap copy.
 *
 * See also -parentBranch.
 */
@property (nonatomic, readonly) BOOL isCopy;
/**
 * Returns whether the receiver is the current branch of its persistent root.
 */
@property (nonatomic, readonly) BOOL isCurrentBranch;

/**
 * Returns whether the receiver was the first branch of its persistent root.
 */
@property (nonatomic, readonly) BOOL isTrunkBranch;


/** @taskunit Basic Properties */


/**
 * The branch UUID.
 *
 * The UUID is never nil.
 */
@property (nonatomic, readonly, strong) ETUUID *UUID;
/**
 * The branch label (used as the branch name in most cases).
 */
@property (nonatomic, readwrite, copy, nullable) NSString *label;
/**
 * The metadata in JSON format attached to the branch.
 *
 * Any changes to the metadata is saved on the next branch commit.
 *
 * You must never overwrite any existing metadata set by CoreObject.
 */
@property (nonatomic, readwrite, copy) NSDictionary<NSString *, id> *metadata;
/** 
 * The branch deletion status.
 *
 * If the branch is marked as deleted, the deletion is committed to the store 
 * on the next persistent root commit.
 *
 * You can't delete the current branch (if -isCurrentBranch is YES, 
 * setting -deleted to YES throws an exception) because persistent roots must
 * always have a current branch.
 */
@property (nonatomic, readwrite, assign, getter=isDeleted) BOOL deleted;
/**
 * Controls whether -setCurrentRevision: can be used to revert the branch to an 
 * older state.
 *
 * This property is non-persistent, and returns YES by default.
 *
 * The main use case is when a branch is used for collaborative editing, this 
 * is set to NO by COSynchronizer, since the collaborative editing protocol 
 * we're using doesn't support making reverts, only forward changes.
 *
 * The undo framework checks this property to see whether to perform a revert
 * or commit the equivalent selective undo. Also, if NO, the -undo and -redo 
 * methods on COBranch are disabled (-canUndo and -canRedo return NO).
 */
@property (nonatomic, readwrite, assign) BOOL supportsRevert;


/** @taskunit History */


/**
 * The parent branch from which the receiver is derived.
 *
 * If the parent branch is nil, this means the receiver is a branch that was 
 * created at the same time than its persistent root. The parent revision is 
 * also nil in this case.
 *
 * For a cheap copy, the parent branch is never nil. See -isCopy.
 */
@property (nonatomic, readonly, nullable) COBranch *parentBranch;
/**
 * The revision at which the receiver was forked from the parent branch.
 *
 * If the parent revision is nil, this means the receiver is a branch that was 
 * created at the same time than its persistent root. The parent branch is also 
 * nil in this case.
 *
 * See also -parentBranch and -firstRevision.
 */
@property (nonatomic, readonly, nullable) CORevision *initialRevision;
/**
 * The oldest revision in the entire branch history.
 *
 * To find the first revision, parent branches are traversed until reaching a 
 * branch without a parent branch, then the last examined branch initial 
 * revision is returned.
 *
 * If -parentBranch is nil, then the first revision is the same than the initial 
 * revision.
 *
 * For all branches in a persistent root, returns the same revision.
 *
 * This is the same than <code>self.nodes.firstObject</code>.
 *
 * See also -initialRevision.
 */
@property (nonatomic, readonly, nullable) CORevision *firstRevision;
/**
 * The revision bound to the state loaded in the object graph context.
 *
 * If the branch is uncommitted, the current revision is nil.
 *
 * A current revision change is saved on the next branch commit.
 *
 * Setting the current revision can be used to revert to a past revision
 * or fast-forward to a future revision. If the revision being set is not
 * an ancestor of the head revision, the head revision is also updated to the
 * given revision.
 *
 * For the track protocol, -[COTrack currentNode] is the same than the current 
 * revision. 
 *
 * See also -headRevision.
 */
@property (nonatomic, readwrite, strong, nullable) CORevision *currentRevision;
/**
 * The revision bound to the most recent commit in the branch.
 *
 * This is the same than <code>self.nodes.lastObject</code>.
 *
 * See also -currentRevision.
 */
@property (nonatomic, readonly, nullable) CORevision *headRevision;


/** @taskunit Persistent Root and Object Graph Context */


/**
 * The editing context owning the branch's persistent root.
 */
@property (nonatomic, readonly) COEditingContext *editingContext;
/**
 * The persistent root owning the branch.
 */
@property (nonatomic, readonly, weak) COPersistentRoot *persistentRoot;
/**
 * The object graph context owned by the branch.
 */
@property (nonatomic, readonly, strong) COObjectGraphContext *objectGraphContext;
/**
 * The root object of the object graph context owned by the branch.
 */
@property (nonatomic, readonly) id rootObject;


/** @taskunit Pending Changes */


/**
 * Returns whether the branch contains uncommitted changes.
 *
 * Object insertions and updates in the object graph context, edited branch 
 * metadata (e.g. changing the label or reverting to a past revision), all count 
 * as uncommitted changes.
 *
 * See also -discardAllChanges and -[COObjectGraphContext hasChanges].
 */
@property (nonatomic, readonly) BOOL hasChanges;
/**
 * Discards the uncommitted changes to reset the branch to its last commit state.
 *
 * Object insertions and updates in the object graph context, edited branch 
 * metadata (e.g. changing the label or reverting to a past revision), will be 
 * cancelled.
 *
 * See also -hasChanges and -[COObjectGraphContext discardAllChanges].
 */
- (void)discardAllChanges;
/**
 * If set to YES, the next  commit in the editing context will write a
 * new revision on this branch, even if there are no changes to be written.
 *
 * Use it to cause a "checkpoint" revision to be written.
 */
@property (nonatomic, readwrite, assign) BOOL shouldMakeEmptyCommit;
/**
 * Returns whether the editing context has relinquished
 * control over this object. If YES, this instance can no longer be used
 * and calling any methods may throw an exception
 */
@property (nonatomic, readonly) BOOL isZombie;

/** @taskunit Undo / Redo */


/**
 * Steps backward in the branch history.
 *
 * From a track viewpoint, this method sets -currentNode to the previous node 
 * in -nodes.
 *
 * From the branch viewpoint, the current revision is set the parent of 
 * -currentRevision that lies on the patch towards -firstRevision. 
 *
 * Note that there is no limit related to the -initialRevision. You can step 
 * backwards to before a branch was created, assuming -parentBranch is not nil, 
 * and before a persistent root was created, assuming the receiver is owned by 
 * a persistent root that is a cheap copy.
 *
 * See -[COTrack undo]. Unlike the implementation in -[COUndoTrack undo], does 
 * not automatically cause a commit.
 */
- (void)undo;
/**
 * Steps forwards in the branch history.
 *
 * From a track viewpoint, this method sets the -currentNode to the next node 
 * in -nodes.
 * 
 * From the branch viewpoint, the current revision is set to the child of 
 * -currentRevision that lies on the path towards -headRevision.
 *
 * See -[COTrack redo]. Unlike the implementation in -[COUndoTrack redo],
 * does not automatically cause a commit.
 */
- (void)redo;


/** @taskunit Creating Branches and Cheap copies */


/**
 * Returns a new branch whose current revision is set to the receiver's current 
 * revision, and adds the given label to the branch's metadata. The resulting 
 * branch uses the receiver as its parent branch.
 *
 * The receiver must be committed.
 *
 * See also -makeBranchWithLabel:atRevision:.
 */
- (COBranch *)makeBranchWithLabel: (NSString *)aLabel;
/**
 * Returns a new branch whose current revision is set to the given revision,
 * and adds the given label to the branch's metadata. The resulting branch uses 
 * the receiver as its parent branch.
 *
 * The revision must be equal to or an ancestor of -headRevision.
 *
 * You can assign the returned branch to the receiver persistent root to switch 
 * the current branch. For example:
 *
 * <example>
 * [persistentRoot setCurrentBranch: [persistentRoot.currentBranch makeBranchWithLabel: @"Sandbox"]];
 * </example>
 *
 * The receiver must be committed - not a newly created branch, or the default
 * branch of an uncommitted persistent root.
 */
- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev;
/**
 * Returns a new persistent root whose current revision is set to the given 
 * revision.
 *
 * The resulting persistent root is known as a cheap copy, because the copy 
 * doesn't cause the history leading to the new persistent root state to be 
 * duplicated in the store.
 *
 * The cheap copy current branch uses the receiver as its parent branch.
 *
 * The revision must be equal to or an ancestor of -headRevision.
 *
 * The receiver must be committed.
 *
 * See also -makeBranchWithLabel:atRevision:, -isCopy and 
 * -[COPersistentRoot parentPersistentRoot].
 */
- (COPersistentRoot *)makePersistentRootCopyFromRevision: (CORevision *)aRev;
/**
 * Returns a new persistent root whose current revision is set to the receiver's
 * current revision.
 *
 * See -makePersistentRootCopyFromRevision:
 */
@property (nonatomic, readonly) COPersistentRoot *makePersistentRootCopy;


/** @taskunit Merging Between Branches */


/**
 * The branch that is currently being merged. 
 *
 * Always returns nil unless explicitly set. Only one of mergingBranch
 * or mergingRevision can be set to non-nil.
 * 
 * If it is set at commit time, records the <em>current revision</em> of 
 * the merging branch as the merge parent of the new commit.
 */
@property (nonatomic, readwrite, strong, nullable) COBranch *mergingBranch;
/**
 * The revision that is currently being merged.
 *
 * Always returns nil unless explicitly set. Only one of mergingBranch
 * or mergingRevision can be set to non-nil.
 *
 * If it is set at commit time, records the given revision
 * as the merge parent of the new commit.
 */
@property (nonatomic, readwrite, strong, nullable) CORevision *mergingRevision;
/**
 * Returns a merge info object representing the changes between the receiver and 
 * the given branch to be merged.
 *
 * This method computes the merge (the involved revisions and the diff) based 
 * on each branch current revision, but doesn't apply it. 
 *
 * TODO: Provide an example showing how to apply the diff.
 *
 * NOTE: This is an unstable API which could change in the future when the
 * diff/merge support is finished
 *
 * See also -mergeInfoForMergingRevision:
 */
- (COMergeInfo *)mergeInfoForMergingBranch: (COBranch *)aBranch;
/**
 * Returns a merge info object representing the changes between the receiver 
 * current revision and the given revision to be merged.
 *
 * TODO: Document how the merge is computed if aRevision belongs to the receiver 
 * rather than another branch.
 *
 * This method computes the merge (the involved revisions and the diff), but 
 * doesn't apply it. 
 *
 * TODO: Provide an example showing how to apply the diff.
 *
 * NOTE: This is an unstable API which could change in the future when the
 * diff/merge support is finished
 *
 * See also -mergeInfoForMergingBranch:.
 */
- (COMergeInfo *)mergeInfoForMergingRevision: (CORevision *)aRevision;


/** @taskunit Description */


/**
 * Returns a short description to summarize the receiver.
 */
@property (readonly, copy) NSString *description;
/**
 * Returns a multi-line description including informations about the branch kind, 
 * deletion status, revisions and pending changes.
 */
@property (nonatomic, readonly) NSString *detailedDescription;


@end

NS_ASSUME_NONNULL_END
