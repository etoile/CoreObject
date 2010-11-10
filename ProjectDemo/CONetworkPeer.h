#import <Cocoa/Cocoa.h>

@class CONetworkPeer;

@protocol CONetworkPeerDelegate

- (void) networkPeer:(CONetworkPeer*)peer didReceiveConnectionFromPeerNamed: (NSString*)name;
- (void) networkPeer:(CONetworkPeer*)peer didReceiveDisconnectionFromPeerNamed: (NSString*)name;
- (void) networkPeer:(CONetworkPeer*)peer didReceiveData: (NSData*)data fromPeerNamed: (NSString*)name;

@end

/**
 * Simple interface to local network.
 *
 * Instances of this class running on different machines automatically find
 * each other, and cause the approriate delegate messages to be delivered when
 * data is sent between peers.
 *
 * Currently implemented using Distibuted Objects, but want to switch to XMPP.
 */
@interface CONetworkPeer : NSObject
{
	NSConnection *vendingConnection;
	NSNetService *netService;
	NSString *peerName;
	NSNetServiceBrowser *serviceBrowser;
	NSMutableDictionary *connectedPeers;
	id<CONetworkPeerDelegate> delegate;
}

@property (readwrite, nonatomic, assign) id<CONetworkPeerDelegate> delegate;

/** 
 * The peer name will be of the form
 * @"projectdemo-[username]-[random number]@hostname"
 */
- (NSString*) peerName;

- (void)sendData: (NSData*)data toPeerNamed: (NSString*)name;

@end
