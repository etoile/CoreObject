#import "XMPPController.h"

#import "XMPPFramework.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "Document.h"

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
	NSArray *array = [sender sortedUsersByAvailabilityName];
	
	NSLog(@"Roster: %@", array);
	
	// Send a message to the first user
	
	if ([array count] == 0)
		return;
	
	XMPPJID *jid = [(id<XMPPUser>)[array firstObject] jid];
	
	NSXMLElement *body = [NSXMLElement elementWithName:@"object"];
	[body setStringValue: [NSString stringWithFormat:@"hello world %@!", [jid full]]];
	
	NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
	[message addAttributeWithName:@"type" stringValue:@"coreobject"];
	[message addAttributeWithName:@"to" stringValue:[jid full]];
	[message addChild:body];
	
	[xmppStream sendElement:message];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	NSLog(@"Got message: %@", message);
	
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText: [NSString stringWithFormat: @"%@ is offering to share a document with you", [[message from] bare]]];
	[alert addButtonWithTitle:@"Accept"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert runModal];
}

- (void) shareWithInspectorForDocument: (Document*)doc
{
}

@end
