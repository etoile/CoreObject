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
}

- (instancetype) initWithPersistentRoot: (COPersistentRoot *)aPersistentRoot;

- (IBAction) undo: (id)sender;
- (IBAction) redo: (id)sender;

- (IBAction) selectiveUndo: (id)sender;
- (IBAction) selectiveRedo: (id)sender;

@end
