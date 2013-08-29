#import <Cocoa/Cocoa.h>

@class NetworkController;

@interface ChatWindowController : NSWindowController
{
	IBOutlet NSTextView *chatTextView;
	NetworkController *networkController; // weak ref
	NSString *chatPeerName;
	NSString *chatPeerFullName;
}

- (id) initWithNetworkController: (NetworkController*)controller
                    chatPeerName: (NSString*)name
                chatPeerFullName: (NSString*)fullname;

- (IBAction) sendMessage: (id)sender;

- (void) receiveMessage: (NSString*)message;

- (NSString*)chatPeerName;

@end
