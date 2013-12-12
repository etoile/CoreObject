#import <Cocoa/Cocoa.h>

@class EWDocumentWindowController;

@interface SharingDrawerViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
{
	IBOutlet NSTextField *xmppAccountLabel;
	IBOutlet NSTableView *table;
	
	NSArray *users;
	EWDocumentWindowController __weak *parent;
}

- (id)initWithParent: (EWDocumentWindowController *)aParent;

@end
