#import <Cocoa/Cocoa.h>

@interface CheckpointAsSheetController : NSObject
{
	IBOutlet NSWindow *sheet;
	IBOutlet NSCell *formCell;
	BOOL didSave;
}

/** Shows the sheet, returns the entered name, or nil if the user pressed cancel */
- (NSString*) showSheet;

- (IBAction)save: (id)sender;
- (IBAction)cancel: (id)sender;

@end
