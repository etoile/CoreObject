#import <Cocoa/Cocoa.h>

#import "EWGraphRenderer.h"
#import "EWUtilityWindowController.h"

@interface EWHistoryWindowController : EWUtilityWindowController <NSTableViewDataSource, NSTableViewDelegate>
{
    IBOutlet NSTableView *tableView;
	IBOutlet NSTextView *textView;
	IBOutlet EWGraphRenderer *graphRenderer;
	
    COPersistentRoot *persistentRoot;
}

+ (EWHistoryWindowController *) sharedController;

@end
