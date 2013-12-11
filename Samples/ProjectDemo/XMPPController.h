#import <Foundation/Foundation.h>
#import "XMPPFramework.h"
#import "Document.h"

@class SharingSession;

@interface XMPPController : NSObject
{
	XMPPStream *xmppStream;
	XMPPRosterMemoryStorage *xmppRosterStorage;
	XMPPRoster *xmppRoster;
	
	Document *currentDocument;
	
	NSMutableDictionary *sharingSessionsByPersistentRootUUID;
}

+ (XMPPController *) sharedInstance;

- (void) reconnect;
- (void) shareWithInspectorForDocument: (Document*)doc;

- (NSArray *) sortedUsersByAvailabilityName;

- (XMPPRoster *) roster;

- (SharingSession *) sharingSessionForPersistentRootUUID: (ETUUID *)aUUID fullJID: (NSString *)aJID;

@end
