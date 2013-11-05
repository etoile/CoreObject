#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import "XMPPFramework.h"

/*
 
 
 
 Limitations / future plans:
 - We can support sharing branch switches, and the COSharing* code supports it
   but it complicates things a bit.
 
 */
@interface SharingSession : NSObject
{
	COPersistentRoot *_persistentRoot;
	
	COBranch *_masterBranch;
	/**
	 * Only non-nil for the client
	 */
	COBranch *_originMasterBranch;

	XMPPJID *_peerJID;
	XMPPStream *_xmppStream;
	BOOL _isServer;
	
	ETUUID *_lastRevisionUUID;
}

- (id)initWithPersistentRoot: (COPersistentRoot *)persistentRoot
					 peerJID: (XMPPJID *)peerJID
				  xmppStream: (XMPPStream *)xmppStream
					isServer: (BOOL)isServer;

@property (nonatomic, readonly, strong) COPersistentRoot *persistentRoot;

@property (nonatomic, readonly, assign) BOOL isServer;

@property (nonatomic, readonly, strong) NSString *peerName;
@property (nonatomic, readonly, strong) NSString *ourName;

@end
