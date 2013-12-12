#import <Cocoa/Cocoa.h>
#import "Project.h"
#import "CheckpointAsSheetController.h"
#import "XMPPController.h"
#import "ProjectNavWindowController.h"
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
	
	COEditingContext *context;
	
	NSMutableDictionary *controllerForWindowID;
}

- (COEditingContext*)editingContext;
- (COSQLiteStore *) store;

- (IBAction) newTextDocument: (id)sender;
- (IBAction) newOutline: (id)sender;
- (IBAction) newDrawing: (id)sender;

- (IBAction) newWindow: (id)sender;

- (void)checkpointWithName: (NSString*)name;

- (void) shareWithInspectorForDocument: (Document*)doc;

- (NSSet *)projects;
- (IBAction)newProject: (id)sender;
- (IBAction)deleteProject: (id)sender;

// These return the 'first' controller for a given branch or persistent root,
// however, there could be several.

- (EWDocumentWindowController *)controllerForDocumentRootObject: (COObject*)rootObject;
- (EWDocumentWindowController *)controllerForPersistentRoot: (COPersistentRoot *)persistentRoot;

- (void)showSearchResults: (id)sender;

/* Convenience */

- (NSWindowController*) keyDocumentController;
- (Document *)keyDocument;

- (EWDocumentWindowController *) registerDocumentRootObject: (Document *)aDoc;

@end
