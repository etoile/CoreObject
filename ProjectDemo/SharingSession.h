#import <Cocoa/Cocoa.h>
#import "Document.h"
#import "SharingSessionPeer.h"
#import "SharingMessage.h"

@class SharingSessionPeer;

/**
 * Each instance of this class is the server sharing a document with one 
 * or more clients on the network. It is basically a container for
 * SharingSessionPeerController objects, which we have one of for each peer.
 * 
 * It implements something similar to "Differential Synchronization"
 */
@interface SharingSession : NSObject
{
  /* The document being shared */
  Document *doc;
  
  /* Dictionary of SharingSessionPeer objects indexed by name */
  NSMutableDictionary *peers;
  
  ETUUID *sessionID;
}

- (id) initWithDocument: (Document*)d;

- (void)addClientNamed: (NSString*)name;
- (void)removeClientNamed: (NSString*)name;

/* SharingSessionPeer callbacks */

- (void)receiveMessage: (SharingMessage*)msg
            fromClient: (SharingSessionPeer*)client;

@end
