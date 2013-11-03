#import <Cocoa/Cocoa.h>
#import "OutlineItem.h"
#import "Document.h"
#import "SharingSession.h"

@interface OutlineController : NSWindowController
{
	IBOutlet NSOutlineView *outlineView;
	Document *doc; // weak ref

	SharingSession * __weak _sharingSession;
}

@property (nonatomic, readwrite, weak) SharingSession *sharingSession;

- (id)initWithDocument: (id)document;

- (Document*)projectDocument;
- (OutlineItem*)rootObject;

- (IBAction) addItem: (id)sender;
- (IBAction) addChildItem: (id)sender;
- (IBAction) shiftLeft: (id)sender;
- (IBAction) shiftRight: (id)sender;
- (IBAction) projectDemoUndo: (id)sender;
- (IBAction) projectDemoRedo: (id)sender;
- (IBAction) history: (id)sender;

- (IBAction) shareWith: (id)sender;

- (IBAction)moveToTrash:(id)sender;

- (IBAction) branch: (id)sender;
- (IBAction) stepBackward: (id)sender;
- (IBAction) stepForward: (id)sender;

- (void) switchToRevision: (CORevision *)aRevision;

@end
