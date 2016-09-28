#import <Cocoa/Cocoa.h>

@class EWDocumentWindowController;

@interface SharingDrawerViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
{
    IBOutlet NSTextField *xmppAccountLabel;
    IBOutlet NSTableView *table;

    NSArray *users;
    EWDocumentWindowController *parent;
}

- (id)initWithParent: (EWDocumentWindowController *)aParent;

@end
