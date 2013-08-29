#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "Document.h"
#import "OutlineController.h"

@interface SharingClient : NSObject
{
	ETUUID *sessionID;
	NSString *serverName;
	
	/**
	 * With each client, only one message can be in flight at a time 
	 * (either we are waiting for a message from them, or vice-versa)
	 */
	BOOL isClientWaitingForResponse;
	
	/**
	 * The "shadow" (terminology from the Differential Synchronization paper)
	 * history graph node. When we receive diffs from the server they will be
	 * relative to this.
	 */
	ETUUID *shadowHistoryGraphNodeUUID;
	
	/* The document being shared */
	Document *doc;
	
	OutlineController *documentWindowController;
}

- (id)initWithInvitationMessage: (NSDictionary*)msg;

- (NSString*)serverName;

/* Private */

- (void)synchronizeWithServerIfPossible;

@end
