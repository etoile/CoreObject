/**
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COSQLiteStore.h>

/**
 * @group Store
 * @abstract A compaction strategy to free space in a CoreObject store.
 *
 * -[COSQLiteStore compactHistory:] uses this protocol to determine which
 * persistent roots, branches and revisions can be deleted and finalized.
 *
 * By default, CoreObject comes bundled with a two compaction strategies:
 *
 * <list>
 * <item>the one behind -[COSQLiteStore finalizeDeletionsForPersistentRoot:error:]</item>
 * <item>COUndoTrackHistoryCompaction</item>
 * </list>
 *
 * To implement a custom strategy, see COUndoTrackCompaction as an example.
 *
 * Both -finalizablePersistentRootUUIDs and -compactablePersistentRootUUIDs can 
 * be overlapping sets (as explained in -finalizablePersistentRootUUIDs).
 */
@protocol COHistoryCompaction <NSObject>
/**
 * The persistent roots to be finalized when compacting the history.
 *
 * Persistent roots not previously marked as deleted are ignored.
 *
 * To attempt finalizing all persistent roots, return -compactablePersistentRootUUIDs.
 */
@property (nonatomic, readonly) NSSet *finalizablePersistentRootUUIDs;
/**
 * The persistent roots to be kept when compacting the history, but whose 
 * branches and revisions can be deleted.
 *
 * Peristent roots not included in this set won't have their revisions examined, 
 * when the history is compacted.
 *
 * If some of these persistent roots are returned among -finalizablePersistentRootUUIDs 
 * and end up being finalized, they will be ignored.
 */
@property (nonatomic, readonly) NSSet *compactablePersistentRootUUIDs;

- (NSSet *)deadRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs;
- (NSSet *)liveRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs;
@end


/**
 * @group Store
 * @abstract Additions to control the store size.
 *
 * For freeing space in a CoreObject store, call -compactHistory: with a custom
 * COHistoryCompaction object providing hints about what to delete and finalize.
 */
@interface COSQLiteStore (COHistoryCompaction)
/**
 * Compacts the history with the given strategy.
 */
- (BOOL)compactHistory: (id <COHistoryCompaction>)aCompactionStrategy;
@end
