#import <Cocoa/Cocoa.h>
#import "SharingServer.h"

@class SharingServer;

/**
 * Server's representation of a single client
 */
@interface SharingServerPeer : NSObject
{
	SharingServer *owner;
	
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
}

- (id) initWithSharingSession: (SharingServer*)session
                   clientName: (NSString*)name;


- (void)synchronizeWithClientIfPossible;
- (void)handleMessage: (NSDictionary*)msg;

@end