/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  January 2013
	License:  MIT  (see COPYING)
 */

#import <CodeObject/COObjectGraphContext.h>

/** 
 * @group Debugging
 * @abstract Change tracking debugging additions related to COObjectGraphContext
 *
 * This category isn't part of the official public API. 
 */
@interface COObjectGraphContext (CODebugging)

/**
 * Returns the object UUIDs inserted since change tracking was cleared.
 *
 * After a commit, returns an empty set.
 */
- (NSArray *)insertedObjects;
/**
 * Returns the objects whose properties have been edited since change tracking
 * was cleared.
 *
 * After a commit, returns an empty set.
 */
- (NSArray *)updatedObjects;
/**
 * Returns the union of the inserted and updated objects. See -insertedObjects
 * and -updatedObjects.
 *
 * After a commit, returns an empty set.
 */
- (NSArray *)changedObjects;
/**
 * A table listing the properties updated per object since change tracking was
 * cleared.
 *
 * Useful to debug the object changes reported to the context since the last 
 * commit.
 */
- (NSDictionary *)updatedPropertiesByUUID;

@end
