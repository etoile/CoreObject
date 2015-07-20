/**
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COHistoryCompaction.h>

@class COUndoTrack, COCommandGroup;

/** 
 * @group Undo
 * @abstract A compaction strategy that targets the history located in the undo
 * track tail or outside the undo track.
 *
 * @section Conceptual Model
 *
 * This strategy ensures that an undo track will continue to work flawlessly 
 * for all operations (undo, redo, selective undo, set current node etc.), even 
 * after compacting the history in the store.
 *
 * The undo track tail can be cut, but the remaing part up to the head will
 * be kept intact.
 *
 * Revisions, persistent roots and branches referenced by other undo tracks or
 * none are not protected by this strategy. This means you must be careful not 
 * to break other undo tracks, when you are using multiple ones.
 *
 * @section Common Use Cases
 *
 * The most common use case is when you want to free space in a CoreObject store.
 *
 * Before passing the compaction strategy to -[COSQLiteStore compactHistory:], 
 * you must always call -compute. You can do this in a background thread.
 */
@interface COUndoTrackHistoryCompaction : NSObject <COHistoryCompaction>
{
	@private
	COUndoTrack *_undoTrack;
	COCommandGroup *_oldestCommandToKeep;
	NSMutableSet *_finalizablePersistentRootUUIDs;
	NSMutableSet *_compactablePersistentRootUUIDs;
	NSMutableSet *_finalizableBranchUUIDs;
	NSMutableSet *_compactableBranchUUIDs;
	NSMutableDictionary *_deadRevisionUUIDs;
	NSMutableDictionary *_liveRevisionUUIDs;
}

- (instancetype)initWithUndoTrack: (COUndoTrack *)aTrack upToCommand: (COCommandGroup *)aCommand;

@property (nonatomic, readonly) COUndoTrack *undoTrack;

/**
 * Scans the history to divide persistent roots, branches and revisions into 
 * them into live and dead ones.
 *
 * You must call it this method before passing the receiver to 
 * -[COSQLiteStore compactHistory:].
 */
- (void)compute;

/**
 * @taskunit Computed Results
 */

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

@end
