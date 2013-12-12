#import <Foundation/Foundation.h>
#import "XMPPFramework.h"
#import "Document.h"

@class SharingSession;

@interface XMPPController : NSObject
{
	XMPPStream *xmppStream;
	XMPPRosterMemoryStorage *xmppRosterStorage;
	XMPPRoster *xmppRoster;
	
	NSMutableDictionary *sharingSessionsByBranchUUID;
}

+ (XMPPController *) sharedInstance;

@property (readonly, strong) XMPPStream *xmppStream;

- (void) reconnect;

- (XMPPRoster *) roster;

- (SharingSession *) sharingSessionForBranch: (COBranch *)aBranch;

- (void) shareBranch: (COBranch*)aBranch withJID: (XMPPJID *)jid;

@end
