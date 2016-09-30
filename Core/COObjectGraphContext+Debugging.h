/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  January 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COObjectGraphContext.h>

NS_ASSUME_NONNULL_BEGIN

/** 
 * @group Debugging
 * @abstract Additions to debug change tracking in an object graph context
 *
 * This category isn't part of the official public API.
 *
 * See also COEditingContext(CODebugging).
 */
@interface COObjectGraphContext (CODebugging)

/**
 * Returns the object UUIDs inserted since change tracking was cleared.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSArray<__kindof COObject *> *insertedObjects;
/**
 * Returns the objects whose properties have been edited since change tracking
 * was cleared.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSArray<__kindof COObject *> *updatedObjects;
/**
 * Returns the union of the inserted and updated objects. See -insertedObjects
 * and -updatedObjects.
 *
 * After a commit, returns an empty set.
 */
@property (nonatomic, readonly) NSArray<__kindof COObject *> *changedObjects;
/**
 * A table listing the properties updated per object since change tracking was
 * cleared.
 *
 * Useful to debug the object changes reported to the context since the last 
 * commit.
 */
@property (nonatomic, readonly) NSDictionary<ETUUID *, NSString *> *updatedPropertiesByUUID;

@end

NS_ASSUME_NONNULL_END
