#import <Cocoa/Cocoa.h>
#import "Project.h"
#import "NetworkController.h"
#import "HistoryInspectorController.h"
#import "CheckpointAsSheetController.h"
#import "SharingController.h"
#import "DesktopWindow.h"
#import "ProjectNavWindow.h"
#import "OverlayShelf.h"
#import "TagWindowController.h"

@interface ApplicationDelegate : NSObject
{
	IBOutlet NSWindow *newDocumentTypeWindow;
	IBOutlet NSWindow *networkWindow;
	IBOutlet NSWindow *searchWindow;
	
	IBOutlet SharingController *sharingController;
	IBOutlet NetworkController *networkController;
	IBOutlet HistoryInspectorController *historyController;
	IBOutlet CheckpointAsSheetController *checkpointAsSheetController;
	IBOutlet TagWindowController *tagWindowController;
	
	DesktopWindow *desktopWindow;
	ProjectNavWindow *projectNavWindow;
	OverlayShelf *overlayShelf;
	
	COEditingContext *context;
	Project *project;
	
	NSMutableDictionary *controllerForDocumentUUID;
}

- (COEditingContext*)editingContext;
- (HistoryInspectorController*)historyController;

- (IBAction) newTextDocument: (id)sender;
- (IBAction) newOutline: (id)sender;
- (IBAction) newDrawing: (id)sender;

- (void)checkpointWithName: (NSString*)name;

- (void) shareWithInspectorForDocument: (Document*)doc;

- (IBAction)newProject: (id)sender;
- (IBAction)deleteProject: (id)sender;

- (OutlineController*)controllerForDocumentRootObject: (COObject*)rootObject;

- (void)showSearchResults: (id)sender;

- (Project *)project;

- (IBAction) orderFrontPreferencesPanel: (id)sender;

/* Convenience */

- (NSWindowController*) keyDocumentController;
- (Document *)keyDocument;

@end
