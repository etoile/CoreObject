#import "AccountWindowController.h"
#import "XMPPController.h"

@implementation AccountWindowController

- (id)init
{
    self = [super initWithWindowNibName: @"AccountBox"];
    return self;
}

- (IBAction) yes: (id)sender
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[defs setObject: [jidBox stringValue] forKey: @"XMPPJID"];
	[defs setObject: [passwordBox stringValue] forKey: @"XMPPPassword"];
	[defs setObject: [serverBox stringValue] forKey: @"XMPPServer"];
	
	[[XMPPController sharedInstance] reconnect];
	
	[self close];
}

- (IBAction) no: (id)sender
{
	[self close];
}

@end
