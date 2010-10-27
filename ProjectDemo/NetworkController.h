#import <Cocoa/Cocoa.h>
#import "CONetworkPeer.h"
#import "ChatWindowController.h"

/**
 * This is the master controller for networking in the ProjectDemo app.
 *
 * It recieves messages from the underlying library layer (CONetworkPeer),
 *  - directly controls the chat system
 *  - manages creating and destroying of SharingSessionController objects,
 *    and forwards relevant messages to them
 */
@interface NetworkController : NSObject <CONetworkPeerDelegate>
{
  CONetworkPeer *myPeer;
  NSMutableDictionary *connectedPeerInfo;
  IBOutlet NSTableView *networkTableView;
  NSMutableArray *openChatWindowControllers;
}

- (void) networkPeer:(CONetworkPeer*)peer didReceiveConnectionFromPeerNamed: (NSString*)name;
- (void) networkPeer:(CONetworkPeer*)peer didReceiveDisconnectionFromPeerNamed: (NSString*)name;
- (void) networkPeer:(CONetworkPeer*)peer didReceiveData: (NSData*)data fromPeerNamed: (NSString*)name;

- (IBAction) chat: (id)sender;

/* ChatWindowController callbacks */

- (void) chatDidClose: (ChatWindowController *)controller;
- (void) chatSendMessage: (NSString*)message toPeerNamed: (NSString*)name;


/**
 * Orders front a chat window with the sepecified peer, creating one if needed
 */
- (ChatWindowController *) beginChatWith: (NSString*)peerName;

@end
