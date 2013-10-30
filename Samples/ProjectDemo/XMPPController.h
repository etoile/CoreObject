#import <Foundation/Foundation.h>
#import "XMPPFramework.h"

@interface XMPPController : NSObject
{
	XMPPStream *xmppStream;
	XMPPRosterMemoryStorage *xmppRosterStorage;
	XMPPRoster *xmppRoster;
}

+ (XMPPController *) sharedInstance;

- (void) reconnect;

@end
