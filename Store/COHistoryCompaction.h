/**
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COSQLiteStore.h>

@class COUndoTrack, COCommand;

@interface COHistoryCompaction : NSObject
{
	@private
	COUndoTrack *_undoTrack;
	COCommand *_oldestCommandToKeep;
	NSMutableSet *_deadPersistentRootUUIDs;
	NSMutableSet *_livePersistentRootUUIDs;
	NSMutableDictionary *_deadRevisionUUIDs;
	NSMutableDictionary *_liveRevisionUUIDs;
}

- (instancetype)initWithUndoTrack: (COUndoTrack *)aTrack upToCommand: (COCommand *)aCommand;

@property (nonatomic, readonly) COUndoTrack *undoTrack;

/**
 * Scans the history to divide persistent roots, branches and revisions into 
 * them into live and dead ones.
 */
- (void)compute;

/**
 * @taskunit Computed Results
 */

/**
 * The persistent roots to be deleted when compacting the history.
 */
@property (nonatomic, readonly) NSSet *deadPersistentRootUUIDs;
/**
 * The persistent roots to be kept when compacting the history, but whose 
 * branches and revisions can be deleted.
 *
 * Peristent roots not included in this set won't have their revision examined, 
 * when the history is compacted.
 */
@property (nonatomic, readonly) NSSet *livePersistentRootUUIDs;
/**
 * The deletable revision sets when compacting the history, organized by 
 * persistent root UUID.
 *
 * These revisions won't be deleted, when they are inside a live revision range. 
 * See -liveRevisionUUIDs.
 */
@property (nonatomic, readonly) NSDictionary *deadRevisionUUIDs;
/**
 * The revisions sets to be kept when compacting the history, organized by 
 * persistent root UUID.
 *
 * These revisions can include dead revisions in their range, see 
 * -deadRevisionUUIDs.
 */
@property (nonatomic, readonly) NSDictionary *liveRevisionUUIDs;

- (NSSet *)deadRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs;
- (NSSet *)liveRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs;

@end


@interface COSQLiteStore (COHistoryCompaction)
/**
 * Compacts the history with the given strategy.
 */
- (BOOL)compactHistory: (COHistoryCompaction *)aCompactionStrategy;
@end
