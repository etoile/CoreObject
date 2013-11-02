#import <Cocoa/Cocoa.h>

#import "EWUtilityWindowController.h"
@class COPersistentRoot;

@interface EWBranchesWindowController : EWUtilityWindowController <NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet NSTableView *table;
    COPersistentRoot *_persistentRoot;
}

+ (EWBranchesWindowController *) sharedController;

- (void) show;

@end
