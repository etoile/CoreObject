/*
	Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

	Date:  November 2010
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COTrack.h>

@class COEditingContext, CORevisionInfo, CORevisionCache, COCommitDescriptor;

/** 
 * @group Core
 * @abstract CORevision represents a revision in the history graph.
 * A revision contains a snapshot of the inner objects, various metadata including
 * parent revisions (one, or two for a merge commit), a UUID, the UUID of the
 * branch that the revision was originally made on, and a arbitrary JSON dictionary
 * for application use. Revisions are immutable.
 */
@interface CORevision : NSObject <COTrackNode>
{
	@private
	CORevisionCache * __weak cache;
	CORevisionInfo *revisionInfo;
}


/** @taskunit History Properties and Metadata */


/** 
 * Returns the revision identifier.
 *
 * This revision UUID is unique accross all CoreObject stores.
 */
- (ETUUID *)UUID;
/**
 * The revision upon which this one is based i.e. the main previous revision. 
 * 
 * For the first revision in a persistent root, returns nil (unless the 
 * persistent root is a cheap copy).
 */
- (CORevision *)parentRevision;
/**
 * If this revision is the result of merging another branch into the this branch,
 * the revision that was merged in, otherwise nil
 */
- (CORevision *)mergeParentRevision;
/**
 * Returns the persistent root UUID involved in the revision.
 *
 * It is possible that this persistent root no longer exists.
 */
- (ETUUID *)persistentRootUUID;
/**
 * Returns the branch UUID involved in the revision.
 *
 * It is possible that this branch no longer exists.
 */
- (ETUUID *)branchUUID;
/** 
 * Returns the date at which the revision was committed. 
 */
- (NSDate *)date;
/**
 * Returns the metadata attached to the revision at commit time. 
 */
- (NSDictionary *)metadata;
/**
 * Returns the commit descriptor matching the commit identifier in -metadata.
 */
- (COCommitDescriptor *)commitDescriptor;
/**
 * Returns -[COCommitDescription localizedTypeDescription].
 */
- (NSString *)localizedTypeDescription;
/**
 * Returns the commit descriptor short description evaluated with the arguments 
 * provided under the key kCOCommitMetadataShortDescriptionArguments in 
 * -metadata.
 *
 * See -[COCommitDescription localizedShortDescriptionWithArguments:]
 */
- (NSString *)localizedShortDescription;

/** @taskunit History Graph Inspection */

/**
 * Returns whether the receiver is equal to an ancestor of the given revision 
 */
- (BOOL) isEqualToOrAncestorOfRevision: (CORevision *)aRevision;

/** @taskunit Framework Private */


/** 
 * <init />
 * Initializes and returns a new revision object to represent a precise revision 
 * number in the given revision cache. 
 */
- (id)initWithCache: (CORevisionCache *)aCache revisionInfo: (CORevisionInfo *)aRevInfo;

/** @taskunit Deprecated */

/** 
 * Returns the revision type.
 *
 * e.g. merge, persistent root creation, minor edit, etc.
 * 
 * Note: This type notion is a bit vague currently. 
 */
- (NSString *)type;
/** 
 * Returns the revision short description.
 * 
 * This description is optional.
 */
- (NSString *)shortDescription;

@end
