/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COTrack.h>

@class COEditingContext, CORevisionInfo, CORevisionID, CORevisionCache;

/** 
 * @group Core
 * @abstract A revision represents a commit in the store history.
 *
 * A revision represents a set of changes to 
 
 to various changes, that were committed at the same
 * time and belong to a single root object and its inner objects. See 
 * -[COStore finishCommit]. 
 *
 * -changedObjectUUIDs and -valuesAndPropertiesForObjectUUID: can be used to 
 * retrieve the committed changes. 
 *
 * CORevision adopts the collection protocol and its content is a record 
 * collection where each CORecord represents a changed object whose properties 
 * are:
 *
 * <deflist>
 * <item>objectUUID</item><desc>The changed object UUID</desc>
 * <item>properties</item><desc>The properties changed in the object</desc>
 * </deflist>
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

// TODO: Reintroduce methods like -localizedTitle that use COCommitDescriptor?


/** @taskunit Framework Private */


/** 
 * <init />
 * Initializes and returns a new revision object to represent a precise revision 
 * number in the given revision cache. 
 */
- (id)initWithCache: (CORevisionCache *)aCache revisionInfo: (CORevisionInfo *)aRevInfo;
- (CORevisionID *)revisionID;


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
