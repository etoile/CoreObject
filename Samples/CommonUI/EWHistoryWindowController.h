/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  March 2014
    License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>

#import "EWUtilityWindowController.h"
#import "EWGraphRenderer.h"

@class COPersistentRoot;
@class COUndoTrack;
@class EWDocument;
@class EWGraphRenderer;

@interface EWHistoryWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, EWGraphRendererDelegate>
{
    IBOutlet NSTableView *table;
    IBOutlet NSTextField *stackLabel;

    IBOutlet NSButton *undo;
    IBOutlet NSButton *redo;
    IBOutlet NSButton *selectiveUndo;
    IBOutlet NSButton *selectiveRedo;
    
    IBOutlet EWGraphRenderer *graphRenderer;
    
    COPersistentRoot *inspectedPersistentRoot;
    COBranch *inspectedBranch;
    
    COUndoTrack *undoTrackToCommitTo;
}

- (instancetype) initWithInspectedPersistentRoot: (COPersistentRoot *)aPersistentRoot undoTrack: (COUndoTrack *)aTrack;

- (IBAction) undo: (id)sender;
- (IBAction) redo: (id)sender;

- (IBAction) selectiveUndo: (id)sender;
- (IBAction) selectiveRedo: (id)sender;

- (NSDictionary *) customRevisionMetadata;

@end
