#import "ChatWindowController.h"

@implementation ChatWindowController

- (id) initWithNetworkController: (NetworkController*)controller
                    chatPeerName: (NSString*)name
                chatPeerFullName: (NSString*)fullname 
{
	self = [super initWithWindowNibName: @"ChatWindow"];
	
	chatPeerName = [name retain];
	chatPeerFullName = [fullname retain];
	networkController = controller;
	
	return self;
}

- (void)dealloc
{
	[chatPeerName release];
	[chatPeerFullName release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[[self window] setTitle: [NSString stringWithFormat: @"Chat with %@", chatPeerFullName]];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[networkController chatDidClose: self];
}

- (void) showString: (NSString*)string
{
	[[[chatTextView textStorage] mutableString] appendString: string];
	[chatTextView scrollRangeToVisible: NSMakeRange([[chatTextView string] length], 0)];
}

- (IBAction) sendMessage: (id)sender
{
	NSTextField *field = sender;
	NSString *msg = [field stringValue];
	if ([msg length] > 0)
	{    
		[self showString: [NSString stringWithFormat: @"You say: %@\n", [field stringValue]]];
		[field setStringValue: @""];
		[networkController chatSendMessage: msg toPeerNamed: chatPeerName];
	}
}

- (void) receiveMessage: (NSString*)message
{
	[self showString: [NSString stringWithFormat: @"%@ Says: %@\n", chatPeerFullName, message]];
}

- (NSString*)chatPeerName
{
	return chatPeerName;
}

@end
