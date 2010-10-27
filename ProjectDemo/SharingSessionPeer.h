#import <Cocoa/Cocoa.h>
#import "SharingSession.h"
#import "SharingMessage.h"

@class SharingSession;

/**
 * Server's representation of a single client
 */
@interface SharingSessionPeer : NSObject
{
  SharingSession *owner;

  NSString *clientName;

  /**
   * With each client, only one message can be in flight at a time 
   * (either we are waiting for a message from them, or vice-versa)
   */
  BOOL isServerWaitingForResponse;
  
  /**
   * The "shadow" (terminology from the Differential Synchronization paper)
   * history graph node. When we receive diffs from the client they will be
   * relative to this.
   */
  ETUUID *shadowHistoryGraphNodeUUID;
  
  /**
   * Messages waiting to be sent.
   * Nonempty only if isServerWaitingForResponse is YES
   */
  NSMutableArray *queuedMessages;
}

- (id) initWithSharingSession: (SharingSession*)session
                   clientName: (NSString*)name;

- (void) enqueueOrSendMessage: (SharingMessage*)msg;

@end