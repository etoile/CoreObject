#import <Cocoa/Cocoa.h>
#import "COEditingContext.h"

@interface HistoryInspectorController : NSObject
{
  IBOutlet NSWindow *historyInspectorWindow;
  IBOutlet NSTableView *historyInspectorTable;
  COEditingContext *context;
}

- (void)setContext: (COEditingContext*)ctx;

- (IBAction)revertTo: (id)sender;
- (IBAction)selectiveUndo: (id)sender;

@end
