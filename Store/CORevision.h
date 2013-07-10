/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COSQLiteStore, CORevisionInfo, CORevisionID;

/** 
 * @group Store
 * @abstract A revision represents a commit in the store history.
 *
 * A revision corresponds to various changes, that were committed at the same 
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
@interface CORevision : NSObject <ETCollection>
{
	@private
	COSQLiteStore *store;
	CORevisionInfo *revisionInfo;
}

/** @taskunit Store */

/** 
 * Returns the store to which the revision and its changed objects belongs to. 
 */
- (COSQLiteStore *)store;

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
 * Returns the revision UUID. 
 */
- (ETUUID *)UUID;
/**
 * Returns the persistent object UUID involved in the revision.
 */
- (ETUUID *)persistentRootUUID;
/**
 * Returns the commit track UUID involved in the revision.
 */
- (ETUUID *)branchUUID;
/** 
 * Returns the date at which the revision was committed. 
 */
- (NSDate *)date;
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
/** 
 * Returns the revision long description.
 * 
 * This description is optional.
 */
- (NSString *)longDescription;

/** 
 * Returns the metadata attached to the revision at commit time. 
 */
- (NSDictionary *)metadata;

/** @taskunit Changes */

#if 0
/** 
 * Returns the UUIDs that correspond to the objects changed by the revision. 
 */ 
- (NSArray *)changedObjectUUIDs;
#endif

/** @taskunit Private */

/** 
 * <init />
 * Initializes and returns a new revision object to represent a precise revision 
 * number in the given store. 
 */
- (id)initWithStore: (COSQLiteStore *)aStore
       revisionInfo: (CORevisionInfo *)aRevInfo;

@end
