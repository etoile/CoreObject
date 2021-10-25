/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  May 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COItemGraph.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @group Core
 * @abstract Metamodel-driven copy support
 *
 * COCopier can be used to copy objects or items between object or item graphs (both conform to
 * the same COItemGraph protocol).
 *
 * This API implements the semantics documented in "Scraps/Slides/copy semantics.key".
 *
 * See also COItem, COItemGraph and COObjectGraphContext.
 */
@interface COCopier : NSObject

/**
 * Copies a single item between two item graphs and returns the UUID of the item inserted in the 
 * destination item graph.
 *
 * If source and destination item graphs are identical, the item is duplicated.
 */
- (ETUUID *)copyItemWithUUID: (ETUUID *)aUUID
                   fromGraph: (id <COItemGraph>)source
                     toGraph: (id <COItemGraph>)dest
                usesNewUUIDs: (BOOL)usesNewUUIDs NS_RETURNS_NOT_RETAINED;
/**
 * Copies the given items between two item graphs and returns the UUIDs of the items inserted in 
 * the destination item graph.
 *
 * If source and destination item graphs are identical, the items are duplicated.
 */
- (NSArray<ETUUID *> *)copyItemsWithUUIDs: (NSArray<ETUUID *> *)uuids
                                fromGraph: (id <COItemGraph>)source
                                  toGraph: (id <COItemGraph>)dest 
                             usesNewUUIDs: (BOOL)usesNewUUIDs NS_RETURNS_NOT_RETAINED;

@end

NS_ASSUME_NONNULL_END
