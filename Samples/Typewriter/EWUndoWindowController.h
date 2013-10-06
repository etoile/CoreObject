#import <Cocoa/Cocoa.h>

#import "EWUtilityWindowController.h"

@class COPersistentRoot;
@class COUndoTrack;
@class EWDocument;

@interface EWUndoWindowController : EWUtilityWindowController <NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet NSTableView *table;
	IBOutlet NSTextField *stackLabel;
    
    EWDocument *_inspectedDocument;
}

- (IBAction) undo: (id)sender;
- (IBAction) redo: (id)sender;

+ (EWUndoWindowController *) sharedController;

- (void) show;

@end
