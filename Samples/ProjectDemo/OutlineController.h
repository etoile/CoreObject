#import <Cocoa/Cocoa.h>
#import "OutlineItem.h"
#import "Document.h"
#import "SharingSession.h"
#import "EWDocumentWindowController.h"

@interface OutlineController : EWDocumentWindowController <NSOutlineViewDelegate>
{
	IBOutlet NSOutlineView *outlineView;

	SharingSession * __weak _sharingSession;
}



@property (nonatomic, readwrite, weak) SharingSession *sharingSession;

- (instancetype) initWithBranch: (COBranch *)aBranch
					   windowID: (NSString*)windowID;

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

- (IBAction) showGraphvizHistoryGraph: (id)sender;

- (void) switchToRevision: (CORevision *)aRevision;

@end
