#import <Cocoa/Cocoa.h>
#import "SharingClient.h"
#import "SharingServer.h"
#import "NetworkController.h"

/**
 * Manages client/server objects for the applications various sharing roles.
 *
 * For each document, we can either be a client or a server, or have no sharing
 * role if that document isn't being shared.
 *
 * The client and server objects are identified by their session UUID, which
 * the server picks.
 */
@interface SharingController : NSObject
{
	NSMutableDictionary *serverForSessionUUID;
	NSMutableDictionary *clientForSessionUUID;
	
	IBOutlet NSWindow *sharingWindow;
	IBOutlet NSTableView *sharingTable;
	
	ETUUID *inspectingDocumentUUID;
}

+ (SharingController*)sharedSharingController;

- (Document*)inspectingDocument;

- (NSString*)fullNameOfUserSharingDocument: (Document*)doc;

/* High-level control of sharing functionality. */

- (BOOL) isDocumentShared;
- (BOOL) isDocument: (Document*)doc sharedWithPeerNamed: (NSString*)peer;
- (void) shareDocument: (Document*)doc withPeerNamed: (NSString*)peer;
- (void) stopSharingDocument: (Document*)doc withPeerNamed: (NSString*)peer;

/**
 * Show the sharing inspector
 */
- (void) shareWithInspectorForDocument: (Document*)doc;

@end
