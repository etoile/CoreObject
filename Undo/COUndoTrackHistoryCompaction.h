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
 * be kept intact, as explained in -initWithUndoTrack:upToCommand:.
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
 * you must always call -compute.
 *
 * For now, COUndoTrackHistoryCompaction is not thread-safe.
 *
 * @section Pattern Undo Track
 *
 * You can pass a pattern undo track to the initalizer, then the compaction 
 * can discard any commands on child tracks, up to the pattern track current
 * node.
 */
@interface COUndoTrackHistoryCompaction : NSObject <COHistoryCompaction>
{
	@private
	COUndoTrack *_undoTrack;
	COCommandGroup *_newestCommandToDiscard;
	NSMutableSet *_finalizablePersistentRootUUIDs;
	NSMutableSet *_compactablePersistentRootUUIDs;
	NSMutableSet *_finalizableBranchUUIDs;
	NSMutableSet *_compactableBranchUUIDs;
	NSMutableDictionary *_deadRevisionUUIDs;
	NSMutableDictionary *_liveRevisionUUIDs;
	NSMutableDictionary *_newestDeadRevisionUUIDs;
}

/**
 * <init />
 * Initializes a compaction strategy to discard any history older than the given
 * command.
 *
 * After compaction, this command is discarded and the next one becomes the undo
 * track tail. The former command becomes the oldest kept state, represented by
 * the track placeholder node.
 *
 * If you pass the track head or current command, or any command in-between:
 *
 * <list>
 * <item>all commands between tail and current commands are discarded, 
 * including the current command and divergent commands not returned by -[COUndoTrack nodes]</item>
 * <item>all commands more recent than the current command are kept</item>
 * </list>
 *
 * For nil track or command, or a command that doesn't on the track, raises an
 * NSInvalidArgumentException.
 */
- (instancetype)initWithUndoTrack: (COUndoTrack *)aTrack upToCommand: (COCommandGroup *)aCommand NS_DESIGNATED_INITIALIZER;

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
 *
 * This method is a debugging utility, it is never used when compacting the 
 * store unlike -liveRevisionUUIDs.
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
/**
 * Returns the dead revisions per persistent root. 
 *
 * This method is similar to -liveRevisionUUIDsForPersistentRootUUIDs:, but is
 * only available for debugging purpose.
 */
- (NSSet *)deadRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs;

@end
