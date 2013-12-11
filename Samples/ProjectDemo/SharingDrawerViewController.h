#import <Cocoa/Cocoa.h>

@interface SharingDrawerViewController : NSViewController
{
	IBOutlet NSTextField *xmppAccountLabel;
	IBOutlet NSTableView *table;
	
	NSArray *users;
}

@end
