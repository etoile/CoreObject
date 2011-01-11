#import <Cocoa/Cocoa.h>


@interface TagWindowController : NSObject <NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet NSWindow *window;
	IBOutlet NSTableView *table;
	IBOutlet NSTextField *tagNameField;
	
	NSMutableArray *tags;
}

- (IBAction) addTag: (id)sender;
- (IBAction) removeTag: (id)sender;

@end
