/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COEditingContext, CORevisionInfo, CORevisionID;

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
@interface CORevision : NSObject
{
	@private
	COEditingContext * __weak editingContext;
	CORevisionInfo *revisionInfo;
}

/** @taskunit Editing Context */

/** 
 * Returns the editing context to which the revision belongs to.
 */
- (COEditingContext *)editingContext;

/** @taskunit History Properties and Metadata */

/** 
 * Returns the revision number.
 *
 * This number shouldn't be used to uniquely identify the revision, unlike -UUID. 
 */
- (CORevisionID *)revisionID;
/**
 * The revision upon which this one is based i.e. the main previous revision. 
 * 
 * This is nil when this is the first revision for a root object.
 */
- (CORevision *)parentRevision;
/**
 * Returns the persistent object UUID involved in the revision.
 * It is possible that this persistent root no longer exists.
 */
- (ETUUID *)persistentRootUUID;
/**
 * Returns the commit track UUID involved in the revision.
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

/** @taskunit Private */

/** 
 * <init />
 * Initializes and returns a new revision object to represent a precise revision 
 * number in the given store. 
 */
- (id)initWithEditingContext: (COEditingContext *)aContext
                revisionInfo: (CORevisionInfo *)aRevInfo;

@end
