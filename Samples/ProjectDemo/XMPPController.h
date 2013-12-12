#import <Foundation/Foundation.h>
#import "XMPPFramework.h"
#import "Document.h"

@class SharingSession;

@interface XMPPController : NSObject
{
	XMPPStream *xmppStream;
	XMPPRosterMemoryStorage *xmppRosterStorage;
	XMPPRoster *xmppRoster;
	
	NSMutableDictionary *sharingSessionsByPersistentRootUUID;
}

+ (XMPPController *) sharedInstance;

@property (readonly, strong) XMPPStream *xmppStream;

- (void) reconnect;
- (void) shareWithInspectorForDocument: (Document*)doc;

- (XMPPRoster *) roster;

- (SharingSession *) sharingSessionForPersistentRootUUID: (ETUUID *)aUUID fullJID: (NSString *)aJID;

- (void) shareBranch: (COBranch*)aBranch withJID: (XMPPJID *)jid;

@end
