#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "Document.h"

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

- (IBAction)showProjectHistory: (id)sender;

- (void)showHistoryForDocument: (Document*)aDocument;

@end
