#import <Cocoa/Cocoa.h>
#import "Project.h"
#import "CheckpointAsSheetController.h"
#import "XMPPController.h"
#import "ProjectNavWindowController.h"
#import "OverlayShelf.h"
#import "TagWindowController.h"
#import "OutlineController.h"

@interface ApplicationDelegate : NSObject
{
	IBOutlet NSWindow *newDocumentTypeWindow;
	IBOutlet NSWindow *networkWindow;
	IBOutlet NSWindow *searchWindow;
	
	IBOutlet XMPPController *xmppController;
	IBOutlet CheckpointAsSheetController *checkpointAsSheetController;
	IBOutlet TagWindowController *tagWindowController;
	
	OverlayShelf *overlayShelf;
	
	COEditingContext *context;
	
	NSMutableDictionary *controllerForDocumentUUID;
}

- (COEditingContext*)editingContext;

- (IBAction) newTextDocument: (id)sender;
- (IBAction) newOutline: (id)sender;
- (IBAction) newDrawing: (id)sender;

- (void)checkpointWithName: (NSString*)name;

- (void) shareWithInspectorForDocument: (Document*)doc;

- (NSSet *)projects;
- (IBAction)newProject: (id)sender;
- (IBAction)deleteProject: (id)sender;

- (OutlineController*)controllerForDocumentRootObject: (COObject*)rootObject;

- (void)showSearchResults: (id)sender;

- (IBAction) orderFrontPreferencesPanel: (id)sender;

/* Convenience */

- (NSWindowController*) keyDocumentController;
- (Document *)keyDocument;

@end
