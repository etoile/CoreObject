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

@synthesize xmppStream = xmppStream;

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
		sharingSessionsByBranchUUID = [[NSMutableDictionary alloc] init];
		
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
	
	[[[NSApplication sharedApplication] dockTile] setBadgeLabel: [jid stringByReplacingOccurrencesOfString: @"test" withString: @""]];
	
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
						branchUUID: (ETUUID *)aBranch
{
	NSXMLElement *responseMessage = [NSXMLElement elementWithName:@"message"];
	[responseMessage addAttributeWithName:@"type" stringValue:@"coreobject"];
	[responseMessage addAttributeWithName:@"subtype" stringValue: aType];
	[responseMessage addAttributeWithName:@"to" stringValue: [aJID full]];
	[responseMessage addAttributeWithName:@"persistentroot" stringValue: [aUUID stringValue]];
	[responseMessage addAttributeWithName:@"branch" stringValue: [aBranch stringValue]];
	[xmppStream sendElement:responseMessage];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if ([[message attributeStringValueForName: @"type"] isEqualToString: @"coreobject"])
	{
		NSString *subtype = [message attributeStringValueForName: @"subtype"];
		ETUUID *persistentRootUUID = [ETUUID UUIDWithString: [message attributeStringValueForName: @"persistentroot"]];
		ETUUID *branchUUID = [ETUUID UUIDWithString: [message attributeStringValueForName: @"branch"]];
		
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
				sharingSessionsByBranchUUID[branchUUID] = session;
				
				[self sendCoreobjectMessageType: @"accept-invitation"
											 to: [message from]
							 persistentRootUUID: persistentRootUUID
									 branchUUID: branchUUID];
			}
		}
		else if ([subtype isEqualToString: @"accept-invitation"])
		{
			SharingSession *session = sharingSessionsByBranchUUID[branchUUID];
			ETAssert(session != nil);
			[session addClientJID: [message from]];
		}
	}
	else
	{
		NSLog(@"Ignoring non-Coreobject message");
	}
}

- (void) shareBranch: (COBranch*)aBranch withJID: (XMPPJID *)jid
{
	NSLog(@"Share %@ with %@", aBranch, jid);
			
	SharingSession *session = sharingSessionsByBranchUUID[aBranch.UUID];
	if (session == nil)
	{
		session = [[SharingSession alloc] initAsServerWithBranch: aBranch
													  xmppStream: xmppStream];
		
		sharingSessionsByBranchUUID[aBranch.UUID] = session;
		
		NSLog(@"Created new sharing session for branch %@", aBranch.UUID);
	}
	else
	{
		NSLog(@"Reusing existing session for branch %@", aBranch.UUID);
	}
	
	[self sendCoreobjectMessageType: @"sharing-invitation" to: jid persistentRootUUID: aBranch.persistentRoot.UUID branchUUID: aBranch.UUID];
}

- (SharingSession *) sharingSessionForBranch: (COBranch *)aBranch
{
	SharingSession *session = sharingSessionsByBranchUUID[aBranch.UUID];
	return session;
}

@end
