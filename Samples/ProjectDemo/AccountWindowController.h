#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface AccountWindowController : NSWindowController
{
    IBOutlet NSTextField *jidBox;
    IBOutlet NSTextField *passwordBox;
    IBOutlet NSTextField *serverBox;
}

- (IBAction) yes: (id)sender;
- (IBAction) no: (id)sender;

@end
