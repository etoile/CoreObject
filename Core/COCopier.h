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
 * Options to control COCopier behavior.
 */
typedef NS_OPTIONS(NSInteger, COCopierOptions) {
    /**
     ** Whether copies have different UUIDs in destination than original items in source.
     *
     * This is useful to duplicate items when source and destination are the same. You can also use 
     * it to implement copy/paste semantics whether source and destination are the same or not.
     */
    COCopierUsesNewUUIDs = 2,
    /**
     * Whether items reachable through non composite references are copied, when they dont'
     * exist in the destination.
     *
     * Be careful with this option, the entire source item graph can be copied into the destination.
     *
     * Can be used alone and in combination with
     * COCopierCopiesNonCompositeReferencesExistingInDestination.
     */
    COCopierCopiesNonCompositeReferencesMissingInDestination = 4,
    /**
     * Whether items reachable through non composite references are copied, when they exist in the
     * the destination.
     *
     * Be careful with this option, the entire source item graph can be copied into the destination.
     *
     * You should usually not use it alone, but in combination with
     * COCopierCopiesNonCompositeReferencesMissingInDestination.
     */
    COCopierCopiesNonCompositeReferencesExistingInDestination = 16
};

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
 *
 * COCopierUsesNewUUIDs option is used. For more control over COCopier options, use -copyItemWithUUID:fromGraph:toGraph:options:.
 */
- (ETUUID *)copyItemWithUUID: (ETUUID *)aUUID
                   fromGraph: (id <COItemGraph>)source
                     toGraph: (id <COItemGraph>)dest NS_RETURNS_NOT_RETAINED;
/**
 * Copies a single item between two item graphs and returns the UUID of the item inserted in the 
 * destination item graph.
 *
 * If source and destination item graphs are identical, the item is duplicated.
 */
- (ETUUID *)copyItemWithUUID: (ETUUID *)aUUID
                   fromGraph: (id <COItemGraph>)source
                     toGraph: (id <COItemGraph>)dest
                     options: (COCopierOptions)options NS_RETURNS_NOT_RETAINED;
/**
 * Copies the given items between two item graphs and returns the UUIDs of the items inserted in 
 * the destination item graph.
 *
 * If source and destination item graphs are identical, the items are duplicated.
 */
- (NSArray<ETUUID *> *)copyItemsWithUUIDs: (NSArray<ETUUID *> *)uuids
                                fromGraph: (id <COItemGraph>)source
                                  toGraph: (id <COItemGraph>)dest 
                                  options: (COCopierOptions)options NS_RETURNS_NOT_RETAINED;

@end

NS_ASSUME_NONNULL_END
