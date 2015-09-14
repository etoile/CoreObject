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


/** @taskunit Persistent Root Status */


/**
 * The persistent roots to be finalized when compacting the history.
 *
 * Persistent roots not previously marked as deleted are ignored.
 *
 * When a persistent root is finalized, it is permanently erased from the store,
 * along with its branches and revisions. If the associated backing store is not 
 * deleted at the same time, all the revisions corresponding to this persistent 
 * root are still erased.
 *
 * To attempt finalizing all persistent roots, return -compactablePersistentRootUUIDs.
 */
@property (nonatomic, readonly) NSSet *finalizablePersistentRootUUIDs;
/**
 * The persistent roots to be kept when compacting the history, but whose 
 * branches and revisions can be deleted.
 *
 * Persistent roots not included in this set won't have their revisions examined, 
 * when the history is compacted.
 *
 * If some of these persistent roots are returned among -finalizablePersistentRootUUIDs,
 * they will be finalized if marked as deleted, or compacted otherwise.
 */
@property (nonatomic, readonly) NSSet *compactablePersistentRootUUIDs;


/** @taskunit Branch Status */


/**
 * The branches to be finalized when compacting the history.
 *
 * Branches not previously marked as deleted are ignored.
 *
 * To attempt finalizing all branches, return -compactableBranchUUIDs.
 */
@property (nonatomic, readonly) NSSet *finalizableBranchUUIDs;
/**
 * The branches to be kept when compacting the history, but whose revisions can 
 * be deleted.
 *
 * Branches not included in this set won't have their revisions examined,
 * when the history is compacted.
 *
 * If some of these branches are returned among -finalizableBranchUUIDs and end
 * up being finalized, they will be ignored.
 */
@property (nonatomic, readonly) NSSet *compactableBranchUUIDs;


/** @taskunit Revision Status */


- (NSSet *)deadRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs;
- (NSSet *)liveRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs;


/** @taskunit Reacting to Compaction Progresses */

/**
 * Tells the receiver the store is going to be compacted according to the 
 * receiver rules.
 *
 * You don't call this method, COSQLiteStore will call it.
 *
 * Use this method to hide high-level objects involved in the compaction 
 * (e.g. COCommand and COUndoTrack), when they don't observe store notifications
 * directly.
 */
- (void)beginCompaction;
/**
 * Tells the receiver the store was compacted according to the receiver rules.
 *
 * You don't call this method, COSQLiteStore will call it.
 *
 * Use this method to discard or show high-level objects involved in the
 * compaction (e.g. COCommand and COUndoTrack), when they don't observe store
 * notifications directly.
 *
 * If the compaction is a success, you should discard these high-level objects,
 * otherwise you should show them again to the user.
 */
- (void)endCompaction: (BOOL)success;

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
 *
 * You should usually compact history when reaching certain conditions (e.g. 
 * a database file size, a number of persistent roots or revisions etc.). 
 *
 * This won't shrink the database file size, but free some internal space that
 * can be reused.
 * 
 * If you need to shrink the database file size, compact the history and call 
 * -vacuum at some point in the future. -vacum is much slower than 
 * -compactHistory: usually, so you should vacuum less often than you compact
 * the history.
 */
- (BOOL)compactHistory: (id <COHistoryCompaction>)aCompactionStrategy;
@end
