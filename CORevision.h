#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COStore, COSQLStore;

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
	COSQLStore *store;
	int64_t revisionNumber;
	int64_t baseRevisionNumber;
}

/** @taskunit Store */

/** 
 * Returns the store to which the revision and its changed objects belongs to. 
 */
- (COStore *)store;

/** @taskunit History Properties and Metadata */

/** 
 * Returns the revision number.
 *
 * This number shouldn't be used to uniquely identify the revision, unlike -UUID. 
 */
- (int64_t)revisionNumber;

/**
 * The revision upon which this one is based i.e. the main previous revision. 
 * 
 * This is nil when this is the first revision for a root object.
 */
- (CORevision *)baseRevision;


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
- (ETUUID *)trackUUID;
/** 
 * Returns the root object UUID involved in the revision. 
 */
- (ETUUID *)objectUUID;
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

/** 
 * Returns the UUIDs that correspond to the objects changed by the revision. 
 */ 
- (NSArray *)changedObjectUUIDs;
/** 
 * Returns the properties (along their values) changed for the given object at 
 * this revision.
 *
 * If the object wasn't changed in the revision, returns an empty dictionary.
 *
 * For retrieving the object state bound to the revision (and not just the 
 * properties changed at this revision), you must use 
 * -valuesAndPropertiesForObjectUUID:fromRevision:.
 *
 * For a nil object UUID, raises a NSInvalidArgumentException.
 */
- (NSDictionary *)valuesAndPropertiesForObjectUUID: (ETUUID *)objectUUID;
/**
 * Returns the properties and values for the given object at this revision, if 
 * the object was changed between the receiver revision and the given past 
 * revision.
 *
 * When no object changes exist between the receiver revision and the given past 
 * revision, returns en empty dictionary.
 *
 * Passing nil as the properties argument means the returned properties are 
 * determined by looking at serialized properties in each revision until the 
 * given past revision is reached (this is a lot slower than passing a 
 * predetermined property set since it involves deserializing all the commit 
 * track revisions in the targeted revision range).
 *
 * Passing nil as the revision argument is the same than passing the result 
 * of -[COStore revisionForRevisionNumber:] for 0 as revision number.
 * 
 * Passing the same revision than the receiver returns the same result than 
 * -valuesAndPropertiesForObjectUUID:.
 *
 * For a nil object UUID, raises a NSInvalidArgumentException.
 *
 * For properties that have never been serialized, raises an 
 * NSInternalInconsistencyException. Usually this means you are passing 
 * properties that don't belong to this object or there is a schema mismatch 
 * between the object metamodel and the store content.
 */
- (NSDictionary *)valuesForProperties: (NSSet *)properties
                         ofObjectUUID: (ETUUID *)aUUID
                         fromRevision: (CORevision *)aRevision;
/** @taskunit Private */

/** 
 * <init />
 * Initializes and returns a new revision object to represent a precise revision 
 * number in the given store. 
 */
- (id)initWithStore: (COSQLStore *)aStore revisionNumber: (int64_t)anID baseRevisionNumber: (int64_t)baseID;

/**
 * Returns the next revision after this one. 
 *
 * Note that in a non-linear history model, there are multiple <em>next 
 * revisions<em/>. Therefore this method is only meaningful in linear revision 
 * models, where each revision has only one next revision that calls it its 
 * <em>base revision</em>.<br />
 * In the non-linear case, it returns the <em>next revision</em> that has the 
 * highest revision number.
 *
 * See also -baseRevision.
 */
- (CORevision *)nextRevision;
@end
