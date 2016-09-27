#import <Cocoa/Cocoa.h>
#import "OutlineItem.h"
#import "Document.h"
#import "SharingSession.h"
#import "EWDocumentWindowController.h"
#import "EWOutlineView.h"

@interface OutlineController : EWDocumentWindowController <NSOutlineViewDelegate, EWOutlineViewDelegate>
{
    IBOutlet EWOutlineView *outlineView;
    BOOL preventCommits;
}

- (instancetype) initAsPrimaryWindowForPersistentRoot: (COPersistentRoot *)aPersistentRoot
                                             windowID: (NSString*)windowID;

- (instancetype) initPinnedToBranch: (COBranch *)aBranch
                           windowID: (NSString*)windowID;

- (Document*)projectDocument;
- (OutlineItem*)rootObject;

- (IBAction) addItem: (id)sender;
- (IBAction) addChildItem: (id)sender;
- (IBAction) shiftLeft: (id)sender;
- (IBAction) shiftRight: (id)sender;

@end
