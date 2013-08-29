#import "SharingController.h"

@implementation SharingController

static SharingController *sharedSharingController = nil;

+ (SharingController*)sharedSharingController
{
	return sharedSharingController;
}

- (id)init
{
	self = [super init];
	clientForSessionUUID = [[NSMutableDictionary alloc] init];
	serverForSessionUUID = [[NSMutableDictionary alloc] init];
	
	assert(sharedSharingController == nil);
	sharedSharingController = self;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector: @selector(handleMessage:)
												 name: NetworkControllerDidReceiveMessageNotification 
											   object: [NetworkController sharedNetworkController]];
	
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[clientForSessionUUID release];
	[serverForSessionUUID release];
	[super dealloc];
}

- (void)handleMessage: (NSNotification*)notif
{
	NSDictionary *msg = [notif userInfo];
	
	NSString *type = [msg objectForKey: @"messagetype"];
	ETUUID *session = [ETUUID UUIDWithString: [msg objectForKey: @"sessionID"]];
	
	if ([type isEqualToString: @"sharingInvitationFromServer"])
	{
		NSLog(@"Sharing controller hanling %@", type);
		SharingClient *client = [[[SharingClient alloc] initWithInvitationMessage: msg] autorelease];
		[clientForSessionUUID setObject: client
								 forKey: session];
	}
	else if ([type isEqualToString: @"sharingMessageFromServer"])
	{
		NSLog(@"Sharing controller hanling %@", type);
		SharingClient *client = [clientForSessionUUID objectForKey: session];
		assert(client != nil);
		[client handleMessage: msg];
	}
	else if ([type isEqualToString: @"sharingMessageFromClient"])
	{
		NSLog(@"Sharing controller hanling %@", type);
		SharingServer *server = [serverForSessionUUID objectForKey: session];
		assert(server != nil);
		[server handleMessage: msg];
	}
}

- (SharingClient*)clientForDocument:(Document*)doc
{
	for (SharingClient *client in [clientForSessionUUID allValues])
	{
		if ([[client document] isEqual: doc])
		{
			return client;
		}
	}
	return nil;
}

- (SharingServer*)serverForDocument:(Document*)doc
{
	for (SharingServer *server in [serverForSessionUUID allValues])
	{
		if ([[server document] isEqual: doc])
		{
			return server;
		}
	}
	return nil;
}

- (NSString*)fullNameOfUserSharingDocument: (Document*)doc
{
	return [[NetworkController sharedNetworkController]
			fullNameForPeerName: [[self clientForDocument: doc] severName]];
}

/* High-level control of sharing functionality. */

- (BOOL) isDocumentShared: (Document*)doc
{
	return (nil == [self serverForDocument: doc]);
}
- (BOOL) isDocument: (Document*)doc sharedWithPeerNamed: (NSString*)peer
{
	return [[self serverForDocument: doc] isSharedWithClientNamed: peer];
}
- (void) shareDocument: (Document*)doc withPeerNamed: (NSString*)peer
{
	SharingServer *server = [self serverForDocument: doc];
	if (nil == server)
	{
		server = [[[SharingServer alloc] initWithDocument: doc] autorelease];
		[serverForSessionUUID addObject: server
								 forKey: [server sessionID]];
	}
	[server addClientNamed: peer];
}

- (void) stopSharingDocument: (Document*)doc withPeerNamed: (NSString*)peer
{
	[[self serverForDocument: doc] removeClientNamed: peer];
	// FIXME: remove it from our dictionary if it's not sharing with anyone
}

/* UI */

- (Document*) inspectingDocument
{
	// FIXME: ugly encapsulation breakage
	return [[[NSApp delegate] editingContext] objectForUUID: inspectingDocumentUUID];
}

- (void) shareWithInspectorForDocument: (Document*)doc
{
	ASSIGN(inspectingDocumentUUID, [doc uuid]);
	[sharingTable reloadData];
	[sharingWindow orderFront: nil];
	[sharingWindow setTitle: [NSString stringWithFormat: @"Sharing of %@", [doc documentName]]];
}

/* NSTableView Data Source */

- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[[NetworkController sharedNetworkController] sortedConnectedPeerNames] count];
}
- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *peerName = [[[NetworkController sharedNetworkController] sortedConnectedPeerNames] objectAtIndex: rowIndex];
	
	if ([[aTableColumn identifier] isEqualToString: @"shared"])
	{
		return [NSNumber numberWithBool: 
				[self isDocument: [self inspectingDocument] sharedWithPeerNamed: peerName]];
	}
	else if ([[aTableColumn identifier] isEqualToString: @"name"])
	{
		return [[NetworkController sharedNetworkController] fullNameForPeerName: peerName];
	}
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *peerName = [[[NetworkController sharedNetworkController] sortedConnectedPeerNames] objectAtIndex: rowIndex];
	
	if ([[aTableColumn identifier] isEqualToString: @"shared"])
	{
		if ([anObject boolValue] == YES)
		{
			[self shareDocument: [self inspectingDocument] withPeerNamed: peerName];
		}
		else
		{
			[self stopSharingDocument: [self inspectingDocument] withPeerNamed: peerName];    
		}
	}
}

/* NSTableView delegate */

- (BOOL) tableView:(NSTableView *)aTableView shouldEditTableColumn: (NSTableColumn*)col row: (NSInteger)row
{
	if ([[col identifier] isEqualToString: @"shared"])
	{
		return YES;
	}
	return NO;
}

- (void)usersListDidChange
{
	// Hack so our table updates when the list of users changes.
	[sharingTable reloadData];
}

@end
