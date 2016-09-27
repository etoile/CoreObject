#import "PreferencesController.h"
#import <CoreObject/CoreObject.h>
#import "EWAppDelegate.h"

@implementation PreferencesController

- (id)init
{
    self = [super initWithWindowNibName: @"Preferences"];
    
    if (self) {
    }
    return self;
}

- (IBAction) clearUndoHistory: (id)sender
{
    [(EWAppDelegate *)[NSApp delegate] clearUndo];
}

@end
