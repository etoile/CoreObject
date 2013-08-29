#import <Cocoa/Cocoa.h>
#import "CONetworkPeer.h"
#import "ChatWindowController.h"

@class SharingController;

extern NSString *NetworkControllerDidReceiveMessageNotification;

/**
 * This is the master controller for networking in the ProjectDemo app.
 *
 * It recieves messages from the underlying library layer (CONetworkPeer),
 *  - directly controls the chat system
 *  - manages creating and destroying of SharingSessionController objects,
 *    and forwards relevant messages to them
 *
 * 
 */
@interface NetworkController : NSObject <CONetworkPeerDelegate>
{
	CONetworkPeer *myPeer;
	NSMutableDictionary *connectedPeerInfo;
	NSMutableArray *openChatWindowControllers;
	
	IBOutlet NSTableView *networkTableView;
	IBOutlet SharingController *sharingController;
}

+ (NetworkController*)sharedNetworkController;

- (NSString*) peerName;

/* Connected peers */

- (NSArray*)sortedConnectedPeerNames;
- (NSString*)fullNameForPeerName: (NSString*)peerName;
- (NSString*)emailForPeerName: (NSString*)peerName;

- (IBAction) chat: (id)sender;

/* ChatWindowController callbacks */

- (void) chatDidClose: (ChatWindowController *)controller;
- (void) chatSendMessage: (NSString*)message toPeerNamed: (NSString*)name;

/* CONetworkPeerDelegate protocol */

- (void) networkPeer:(CONetworkPeer*)peer didReceiveConnectionFromPeerNamed: (NSString*)name;
- (void) networkPeer:(CONetworkPeer*)peer didReceiveDisconnectionFromPeerNamed: (NSString*)name;
- (void) networkPeer:(CONetworkPeer*)peer didReceiveData: (NSData*)data fromPeerNamed: (NSString*)name;

/**
 * Orders front a chat window with the sepecified peer, creating one if needed
 */
- (ChatWindowController *) beginChatWith: (NSString*)peerName;

- (void) sendMessage: (id)msg toPeerNamed: (NSString*)name;

@end
