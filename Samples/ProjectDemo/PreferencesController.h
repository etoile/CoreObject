#import <AppKit/AppKit.h>

@interface PreferencesController : NSWindowController
{
	IBOutlet NSMatrix *undoMode;
}

- (IBAction) undoModeChanged: (id)sender;

@end
