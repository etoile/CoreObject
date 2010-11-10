#import <Cocoa/Cocoa.h>
#import "COEditingContext.h"

@interface HistoryInspectorController : NSObject
{
	IBOutlet NSWindow *historyInspectorWindow;
	IBOutlet NSTableView *historyInspectorTable;
	IBOutlet NSTextView *textDisplay;
	COEditingContext *context;
}

- (void)setContext: (COEditingContext*)ctx;

- (IBAction)revertTo: (id)sender;
- (IBAction)selectiveUndo: (id)sender;

@end
