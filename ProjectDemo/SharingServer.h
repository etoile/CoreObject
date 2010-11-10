#import <Cocoa/Cocoa.h>
#import "Document.h"
#import "SharingServerPeer.h"

@class SharingServerPeer;

/**
 * Each instance of this class is the server sharing a document with one 
 * or more clients on the network. It is basically a container for
 * SharingServerPeerController objects, which we have one of for each peer.
 * 
 * It implements something similar to "Differential Synchronization"
 */
@interface SharingServer : NSObject
{
	/* The document being shared */
	Document *doc;
	
	/* Dictionary of SharingServerPeer objects indexed by name */
	NSMutableDictionary *peers;
	
	ETUUID *sessionID;
}

- (id) initWithDocument: (Document*)d;

- (ETUUID*) sessionID;
- (Document*) document;

- (BOOL)isSharedWithClientNamed: (NSString*)name;
- (void)addClientNamed: (NSString*)name;
- (void)removeClientNamed: (NSString*)name;

/* SharingServerPeer callbacks */

- (void)receiveMessage: (NSDictionary*)msg
            fromClient: (SharingServerPeer*)client;

@end
