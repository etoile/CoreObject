/**
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COUndoTrack, COCommand;

@interface COHistoryCompaction : NSObject
{
	@private
	COUndoTrack *_undoTrack;
	COCommand *_oldestCommandToKeep;
	NSMutableSet *_deadPersistentRootUUIDs;
	NSMutableSet *_livePersistentRootUUIDs;
	NSMutableSet *_deadRevisionUUIDs;
	NSMutableSet *_liveRevisionUUIDs;
}

- (instancetype)initWithUndoTrack: (COUndoTrack *)aTrack upToCommand: (COCommand *)aCommand;

@property (nonatomic, readonly) COUndoTrack *undoTrack;

/**
 * Scans the history to divide persistent roots, branches and revisions into 
 * them into live and dead ones.
 */
- (void)compute;

@end
