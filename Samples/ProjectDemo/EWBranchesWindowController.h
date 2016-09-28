#import <Cocoa/Cocoa.h>

#import "EWUtilityWindowController.h"

@class EWDocumentWindowController;

@interface EWBranchesWindowController : EWUtilityWindowController <NSTableViewDelegate, NSTableViewDataSource>
{
    IBOutlet NSTableView *table;
    EWDocumentWindowController *inspectedWindowController;
}

+ (EWBranchesWindowController *)sharedController;

- (IBAction)addBranch: (id)sender;
- (IBAction)deleteBranch: (id)sender;

@end
