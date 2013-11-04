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

- (NSString *) serializePropertyList: (id)plist
{
	NSData *data = [NSJSONSerialization dataWithJSONObject: plist options: 0 error: NULL];
	return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
}

- (id) deserializePropertyList: (NSString *)base64String
{
	NSData *data = [base64String dataUsingEncoding: NSUTF8StringEncoding];
	return [NSJSONSerialization JSONObjectWithData: data options:0 error: NULL];
}

- (void) sendCoreobjectMessageType: (NSString *)aType
								to: (XMPPJID *)aJID
		   withPayloadPropertyList: (id)aPlist
{
	NSXMLElement *body = [NSXMLElement elementWithName: aType];
	[body setObjectValue: [self serializePropertyList: aPlist]];
	
	NSXMLElement *responseMessage = [NSXMLElement elementWithName:@"message"];
	[responseMessage addAttributeWithName:@"type" stringValue:@"coreobject"];
	[responseMessage addAttributeWithName:@"to" stringValue:[aJID full]];
	[responseMessage addChild:body];
	
	[xmppStream sendElement:responseMessage];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if ([[message attributeStringValueForName: @"type"] isEqualToString: @"coreobject"])
	{
		NSXMLElement *body = (NSXMLElement *)[message childAtIndex: 0];
		
		NSString *coreObjectMessageName = [body name];
		
		if ([coreObjectMessageName isEqualToString: @"sharing-invitation"])
		{
			ETUUID *persistentRootUUID = [ETUUID UUIDWithString: [body attributeStringValueForName: @"uuid"]];
			
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText: [NSString stringWithFormat: @"%@ is offering to share a document %@ with you", [[message from] bare], persistentRootUUID]];
			[alert addButtonWithTitle:@"Accept"];
			[alert addButtonWithTitle:@"Cancel"];
			
			if (NSAlertFirstButtonReturn == [alert runModal])
			{
				COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
				id request = [client updateRequestForPersistentRoot: persistentRootUUID
														   serverID: [[message from] full]
															  store: [(ApplicationDelegate *)[NSApp delegate] store]];
			
				[self sendCoreobjectMessageType: @"pull-request" to:[message from] withPayloadPropertyList:request];
			}
		}
		else if ([coreObjectMessageName isEqualToString: @"pull-request"])
		{
			id request = [self deserializePropertyList: [body objectValue]];
			
			NSLog(@"Got staring invitation response: %@", request);
			
			COSynchronizationServer *server = [[COSynchronizationServer alloc] init];
			id response = [server handleUpdateRequest: request store: [(ApplicationDelegate *)[NSApp delegate] store]];
			
			[self sendCoreobjectMessageType:@"pull-request-response" to:[message from] withPayloadPropertyList:response];
		}
		else if ([coreObjectMessageName isEqualToString: @"pull-request-response"])
		{
			id response = [self deserializePropertyList: [body objectValue]];
			
			NSLog(@"Got pull-request-response %@", response);
			
			COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
			[client handleUpdateResponse: response store: [(ApplicationDelegate *)[NSApp delegate] store]];
			
			ETUUID *persistentRootUUID = [ETUUID UUIDWithString: response[@"persistentRoot"]];
			
			COEditingContext *ctx = [(ApplicationDelegate *)[NSApp delegate] editingContext];
			COPersistentRoot *newPersistentRoot = [ctx persistentRootForUUID: persistentRootUUID];
			Document *rootObject = [newPersistentRoot rootObject];
			
			[(ApplicationDelegate *)[NSApp delegate] registerDocumentRootObject: rootObject];
			
			SharingSession *session = [[SharingSession alloc] initWithPersistentRoot: newPersistentRoot
																			 peerJID: [message from]
																		  xmppStream: xmppStream
																			isServer: NO];
			[sharingSessionsByPersistentRootUUID setObject: session forKey: persistentRootUUID];
		}
	}
	else
	{
		NSLog(@"Ignoring non-Coreobject message %@", message);
	}
}

- (void) shareWith: (id)sender
{
	id<XMPPUser> user = [sender representedObject];
	
	ETUUID *persistentRootUUID = [[currentDocument persistentRoot] UUID];

	NSLog(@"Share %@ with %@", persistentRootUUID, user);
		
	XMPPJID *jid = [user jid];
	
	NSXMLElement *body = [NSXMLElement elementWithName:@"sharing-invitation"];
	[body addAttributeWithName:@"uuid" stringValue: [persistentRootUUID stringValue]];
	
	NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
	[message addAttributeWithName:@"type" stringValue:@"coreobject"];
	[message addAttributeWithName:@"to" stringValue:[jid full]];
	[message addChild:body];
	
	[xmppStream sendElement:message];
	
	// Set up session object
	
	SharingSession *session = [[SharingSession alloc] initWithPersistentRoot: [currentDocument persistentRoot]
																	 peerJID: jid
																  xmppStream: xmppStream
																	isServer: YES];
	[sharingSessionsByPersistentRootUUID setObject: session forKey: persistentRootUUID];
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

@end
