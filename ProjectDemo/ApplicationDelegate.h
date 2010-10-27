#import <Cocoa/Cocoa.h>
#import "Project.h"
#import "NetworkController.h"
#import "HistoryInspectorController.h"
#import "CheckpointAsSheetController.h"

@interface ApplicationDelegate : NSObject
{
  IBOutlet NSWindow *newDocumentTypeWindow;
  IBOutlet NSWindow *networkWindow;
  IBOutlet NSWindow *sharingWindow;
  IBOutlet NetworkController *networkController;
  IBOutlet HistoryInspectorController *historyController;
  IBOutlet CheckpointAsSheetController *checkpointAsSheetController;
  
  COEditingContext *context;
  Project *project;
  
  NSMutableDictionary *controllerForDocumentUUID;
}

- (IBAction) newTextDocument: (id)sender;
- (IBAction) newOutline: (id)sender;
- (IBAction) newDrawing: (id)sender;

- (void)checkpointWithName: (NSString*)name;

- (void) shareWithInspectorForDocument: (Document*)doc;
@end
