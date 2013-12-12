#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import "XMPPFramework.h"

#import <CoreObject/COSynchronizerJSONClient.h>
#import <CoreObject/COSynchronizerJSONServer.h>
#import <CoreObject/COSynchronizerClient.h>
#import <CoreObject/COSynchronizerServer.h>

/**
 * Object that encapsulates the sharing session, for either the client or server.
 */
@interface SharingSession : NSObject <COSynchronizerJSONClientDelegate, COSynchronizerJSONServerDelegate>
{
	XMPPStream *_xmppStream;
	BOOL _isServer;
	
	// Only for server object
	
	COSynchronizerJSONServer *_JSONServer;
	COSynchronizerServer *_server;
	
	// Only for client object
	
	COSynchronizerClient *_client;
	COSynchronizerJSONClient *_JSONClient;
	XMPPJID *_serverJID;
}

- (id)initAsClientWithEditingContext: (COEditingContext *)ctx
						   serverJID: (XMPPJID *)peerJID
						  xmppStream: (XMPPStream *)xmppStream;

- (id)initAsServerWithBranch: (COBranch *)aBranch
				  xmppStream: (XMPPStream *)xmppStream;

@property (nonatomic, readonly, strong) COPersistentRoot *persistentRoot;

@property (nonatomic, readonly, assign) BOOL isServer;

@property (nonatomic, readonly, strong) NSString *ourName;

- (BOOL) isJIDClient: (XMPPJID *)peerJID;

- (void) addClientJID: (XMPPJID *)peerJID;

@end
