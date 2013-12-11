#import "XMPPController.h"

#import "XMPPFramework.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "Document.h"
#import "ApplicationDelegate.h"
#import "SharingSession.h"

#import <CoreObject/CoreObject.h>

@implementation XMPPController

+ (XMPPController *) sharedInstance
{
    return [[XMPPController alloc] init];
}

- (id)init
{
	static XMPPController *sharedInstance;
	if (sharedInstance != nil)
	{
		return sharedInstance;
	}
	
    self = [super init];
	sharedInstance = self;
	
    if (self) {
		sharingSessionsByPersistentRootUUID = [[NSMutableDictionary alloc] init];
		
		[DDLog addLogger:[DDTTYLogger sharedInstance]];
		
		xmppStream = [[XMPPStream alloc] init];
		[xmppStream addDelegate: self delegateQueue: dispatch_get_main_queue()];
		
		// Setup roster
		
		xmppRosterStorage = [[XMPPRosterMemoryStorage alloc] init];
		xmppRoster = [[XMPPRoster alloc] initWithRosterStorage: xmppRosterStorage];
		
		[xmppRoster activate: xmppStream];
		
		[xmppRoster setAutoFetchRoster: YES];
		[xmppRoster setAutoAcceptKnownPresenceSubscriptionRequests: YES];
		
		[xmppRoster addDelegate: self delegateQueue: dispatch_get_main_queue()];
		
        [self reconnect];
    }
    return self;
}

- (void) reconnect
{
	[xmppStream disconnect];
	
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *jid = [defs stringForKey: @"XMPPJID"];
	NSString *password	= [defs stringForKey: @"XMPPPassword"];
	NSString *server = [defs stringForKey: @"XMPPServer"];
	
	if (jid== nil)
	{
		NSLog(@"No JID specified, postponing connection.");
		return;
	}
	
	[[[NSApplication sharedApplication] dockTile] setBadgeLabel: jid];
	
	NSLog(@"Connect to %@ %@ %@", jid, password, server);
	
	xmppStream.myJID = [XMPPJID jidWithString: jid];
	xmppStream.hostName = server;
	[xmppStream connectWithTimeout: XMPPStreamTimeoutNone error: NULL];
}

- (XMPPRoster *) roster
{
	return xmppRoster;
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *password	= [defs stringForKey: @"XMPPPassword"];
	
    [xmppStream authenticateWithPassword:password error:NULL];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	NSLog(@"Authenticated!");
	[self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	NSLog(@"Did not authenticate!");
}

- (void)goOnline
{
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[xmppStream sendElement:presence];
}

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender
{
}

- (void) sendCoreobjectMessageType: (NSString *)aType
								to: (XMPPJID *)aJID
				persistentRootUUID: (ETUUID *)aUUID
{
	NSXMLElement *responseMessage = [NSXMLElement elementWithName:@"message"];
	[responseMessage addAttributeWithName:@"type" stringValue:@"coreobject"];
	[responseMessage addAttributeWithName:@"subtype" stringValue: aType];
	[responseMessage addAttributeWithName:@"to" stringValue:[aJID full]];
	[responseMessage addAttributeWithName:@"uuid" stringValue: [aUUID stringValue]];
	
	[xmppStream sendElement:responseMessage];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if ([[message attributeStringValueForName: @"type"] isEqualToString: @"coreobject"])
	{
		NSString *subtype = [message attributeStringValueForName: @"subtype"];
		ETUUID *persistentRootUUID = [ETUUID UUIDWithString: [message attributeStringValueForName: @"uuid"]];
		
		if ([subtype isEqualToString: @"sharing-invitation"])
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText: [NSString stringWithFormat: @"%@ is offering to share a document %@ with you", [[message from] bare], persistentRootUUID]];
			[alert addButtonWithTitle:@"Accept"];
			[alert addButtonWithTitle:@"Cancel"];
			
			if (NSAlertFirstButtonReturn == [alert runModal])
			{
				COEditingContext *ctx = [(ApplicationDelegate *)[NSApp delegate] editingContext];
				SharingSession *session = [[SharingSession alloc] initAsClientWithEditingContext: ctx
																					   serverJID: [message from]
																					  xmppStream: xmppStream];
				[sharingSessionsByPersistentRootUUID setObject: session forKey: persistentRootUUID];
				
				[self sendCoreobjectMessageType: @"accept-invitation" to:[message from] persistentRootUUID: persistentRootUUID];
			}
		}
		else if ([subtype isEqualToString: @"accept-invitation"])
		{
			// Set up session object
			
			SharingSession *session = [[SharingSession alloc] initAsServerWithBranch: [[currentDocument persistentRoot] currentBranch]
																		   clientJID: [message from]
																		  xmppStream: xmppStream];
			
			[sharingSessionsByPersistentRootUUID setObject: session forKey: persistentRootUUID];			
		}
	}
	else
	{
		NSLog(@"Ignoring non-Coreobject message");
	}
}

- (void) shareWith: (id)sender
{
	id<XMPPUser> user = [sender representedObject];
	
	ETUUID *persistentRootUUID = [[currentDocument persistentRoot] UUID];
	XMPPJID *jid = [user jid];
	
	NSLog(@"Share %@ with %@", persistentRootUUID, user);
			
	[self sendCoreobjectMessageType: @"sharing-invitation" to: jid persistentRootUUID: persistentRootUUID];
}

- (NSArray *) sortedUsersByAvailabilityName
{
	return [xmppRosterStorage sortedUsersByAvailabilityName];
}

- (void) shareWithInspectorForDocument: (Document*)doc
{
	currentDocument = doc;
	
	NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"People"];
	for (id<XMPPUser> user in [xmppRosterStorage sortedUsersByAvailabilityName])
	{
		NSMenuItem *item = [theMenu addItemWithTitle: [[user jid] bare] action: @selector(shareWith:) keyEquivalent:@""];
		[item setRepresentedObject: user];
		[item setTarget: self];
	}

    [NSMenu popUpContextMenu:theMenu withEvent:[[NSApp mainWindow] currentEvent] forView:nil];
}

- (SharingSession *) sharingSessionForPersistentRootUUID: (ETUUID *)aUUID fullJID: (NSString *)aJID
{
	SharingSession *session = [sharingSessionsByPersistentRootUUID objectForKey: aUUID];
	if ([[session.peerJID full] isEqual: aJID])
	{
		return session;
	}
	return nil;
}

@end
