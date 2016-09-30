/**
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  November 2010
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COTrack.h>

@class COEditingContext, CORevisionInfo, CORevisionCache, COCommitDescriptor;

NS_ASSUME_NONNULL_BEGIN

/** 
 * @group Core
 * @abstract CORevision represents a revision in the history graph.
 *
 * A revision contains:
 *
 * <list>
 * <item>a snapshot of the inner objects</item>
 * <item>various metadata including parent revisions (one, or two for a merge 
 * commit)</item>
 * <item>a UUID</item>
 * <item>the UUID of the branch that the revision was originally made on</item>
 * <item>an arbitrary JSON dictionary for application use</item>
 * </list>
 *
 * For each COBranch that contains uncommitted object graph context changes 
 * (i.e. changes to the inner objects), a new revision will be created on 
 * commit.
 *
 * As explained in COUndoTrack and the Commits section of COEditingContext, a 
 * commit can create multiple revisions or even none.
 *
 * Revisions are immutable.
 */
@interface CORevision : NSObject <COTrackNode>
{
@private
    CORevisionCache *__weak cache;
    CORevisionInfo *revisionInfo;
}


/** @taskunit History Properties and Metadata */


/** 
 * Returns the revision identifier.
 *
 * This revision UUID is unique accross all CoreObject stores.
 */
@property (nonatomic, readonly, copy) ETUUID *UUID;
/**
 * The revision upon which this one is based i.e. the main previous revision. 
 * 
 * For the first revision in a persistent root, returns nil (unless the 
 * persistent root is a cheap copy).
 */
@property (nonatomic, readonly, nullable) CORevision *parentRevision;
/**
 * If this revision is the result of merging another branch into the this branch,
 * returns the revision that was merged in, otherwise nil.
 */
@property (nonatomic, readonly, nullable) CORevision *mergeParentRevision;
/**
 * Returns the persistent root UUID involved in the revision.
 *
 * It is possible that this persistent root no longer exists.
 */
@property (nonatomic, readonly, copy) ETUUID *persistentRootUUID;
/**
 * Returns the branch UUID involved in the revision.
 *
 * It is possible that this branch no longer exists.
 */
@property (nonatomic, readonly) ETUUID *branchUUID;
/** 
 * Returns the date at which the revision was committed. 
 */
@property (nonatomic, readonly) NSDate *date;
/**
 * Returns the metadata attached to the revision at commit time. 
 */
@property (nonatomic, readonly, copy) NSDictionary *metadata;
/**
 * Returns the commit descriptor matching the commit identifier in -metadata.
 */
@property (nonatomic, readonly, nullable) COCommitDescriptor *commitDescriptor;
/**
 * Returns -[COCommitDescriptor localizedTypeDescription].
 */
@property (nonatomic, readonly, nullable) NSString *localizedTypeDescription;
/**
 * Returns the commit descriptor short description evaluated with the arguments 
 * provided under the key kCOCommitMetadataShortDescriptionArguments in 
 * -metadata.
 *
 * See -[COCommitDescriptor localizedShortDescriptionWithArguments:]
 */
@property (nonatomic, readonly, nullable) NSString *localizedShortDescription;
/**
 * Returns -parentRevision.
 */
@property (nonatomic, readonly, nullable) id <COTrackNode> parentNode;
/**
 * Returns -mergeParentRevision.
 */
@property (nonatomic, readonly, nullable) id <COTrackNode> mergeParentNode;


/** @taskunit History Graph Inspection */


/**
 * Returns whether the receiver is equal to an ancestor of the given revision. 
 */
- (BOOL)isEqualToOrAncestorOfRevision: (CORevision *)aRevision;


/** @taskunit Framework Private */


/** 
 * <init />
 * Initializes and returns a new revision object to represent a precise revision 
 * number in the given revision cache.
 *
 * For a nil cache or revision info, raises a NSInvalidArgumentException.
 */
- (instancetype)initWithCache: (CORevisionCache *)aCache
                 revisionInfo: (CORevisionInfo *)aRevInfo NS_DESIGNATED_INITIALIZER;


@end

NS_ASSUME_NONNULL_END
