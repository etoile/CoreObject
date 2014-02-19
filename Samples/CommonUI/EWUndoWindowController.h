#import <Cocoa/Cocoa.h>

#import "EWUtilityWindowController.h"

@class COPersistentRoot;
@class COUndoTrack;
@class EWDocument;
@class EWGraphRenderer;

@interface EWUndoWindowController : EWUtilityWindowController <NSTableViewDelegate, NSTableViewDataSource>
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

- (IBAction) undo: (id)sender;
- (IBAction) redo: (id)sender;

- (IBAction) selectiveUndo: (id)sender;
- (IBAction) selectiveRedo: (id)sender;

@end
