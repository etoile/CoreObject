#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import "XMPPFramework.h"

#import <CoreObject/COSynchronizerJSONClient.h>
#import <CoreObject/COSynchronizerJSONServer.h>
#import <CoreObject/COSynchronizerClient.h>
#import <CoreObject/COSynchronizerServer.h>


/*
 
 
 
 Limitations / future plans:
 - We can support sharing branch switches, and the COSharing* code supports it
   but it complicates things a bit.
 
 */
@interface SharingSession : NSObject <COSynchronizerJSONClientDelegate, COSynchronizerJSONServerDelegate>
{
	XMPPJID *_peerJID;
	XMPPStream *_xmppStream;
	BOOL _isServer;
	
	COSynchronizerJSONClient *_JSONClient;
	COSynchronizerJSONServer *_JSONServer;
	COSynchronizerClient *_client;
	COSynchronizerServer *_server;
}

- (id)initAsClientWithEditingContext: (COEditingContext *)ctx
						   serverJID: (XMPPJID *)peerJID
						  xmppStream: (XMPPStream *)xmppStream;

- (id)initAsServerWithBranch: (COBranch *)aBranch
				   clientJID: (XMPPJID *)peerJID
				  xmppStream: (XMPPStream *)xmppStream;

@property (nonatomic, readonly, strong) COPersistentRoot *persistentRoot;

@property (nonatomic, readonly, assign) BOOL isServer;

@property (nonatomic, readonly, strong) NSString *peerName;
@property (nonatomic, readonly, strong) NSString *ourName;

@property (nonatomic, readonly, strong) XMPPJID *peerJID;

@end
