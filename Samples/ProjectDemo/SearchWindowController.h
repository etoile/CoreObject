#import <Cocoa/Cocoa.h>

@interface SearchWindowController : NSWindowController{
	IBOutlet NSTableView *table;
	IBOutlet NSSearchField *searchfield;
	
	NSArray *searchResults;
}

- (IBAction) search: (id)sender;

@end
