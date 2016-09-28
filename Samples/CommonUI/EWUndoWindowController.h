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

@interface EWUndoWindowController : EWUtilityWindowController <NSTableViewDelegate, NSTableViewDataSource, EWGraphRendererDelegate>
{
    IBOutlet NSTableView *table;
    IBOutlet NSTextField *stackLabel;

    IBOutlet NSButton *undo;
    IBOutlet NSButton *redo;
    IBOutlet NSButton *selectiveUndo;
    IBOutlet NSButton *selectiveRedo;

    IBOutlet EWGraphRenderer *graphRenderer;

    NSWindowController *wc;
    COUndoTrack *_track;
}

- (IBAction) selectiveUndo: (id)sender;
- (IBAction) selectiveRedo: (id)sender;

@end
