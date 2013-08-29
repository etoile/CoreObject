#import <Cocoa/Cocoa.h>
#import "Document.h"

@interface TagWindowController : NSObject <NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet NSWindow *window;
	IBOutlet NSTableView *table;
	IBOutlet NSTextField *tagNameField;
	
	Document *document; // the document whose tags are displayed
}

- (IBAction) addTag: (id)sender;
- (IBAction) removeTag: (id)sender;

- (void) show: (id)sender;
- (void) setDocument: (Document*)doc;

@end
