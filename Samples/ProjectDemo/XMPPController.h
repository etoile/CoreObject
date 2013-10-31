#import <Foundation/Foundation.h>
#import "XMPPFramework.h"
#import "Document.h"

@interface XMPPController : NSObject
{
	XMPPStream *xmppStream;
	XMPPRosterMemoryStorage *xmppRosterStorage;
	XMPPRoster *xmppRoster;
	
	NSArray *currentRoster;
	Document *currentDocument;
}

+ (XMPPController *) sharedInstance;

- (void) reconnect;
- (void) shareWithInspectorForDocument: (Document*)doc;

@end
