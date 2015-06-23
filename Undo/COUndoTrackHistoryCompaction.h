/**
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COHistoryCompaction.h>

@class COUndoTrack, COCommand;

@interface COUndoTrackHistoryCompaction : NSObject <COHistoryCompaction>
{
	@private
	COUndoTrack *_undoTrack;
	COCommand *_oldestCommandToKeep;
	NSMutableSet *_finalizablePersistentRootUUIDs;
	NSMutableSet *_compactablePersistentRootUUIDs;
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
