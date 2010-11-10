#import "NetworkController.h"
#import "ChatWindowController.h"
#include <sys/utsname.h>

/**
 * Delay incoming messages for 2.0 seconds to make it easier to see what the
 * live collaboration code is doing
 */
#define MESSAGE_DELAY 0.0

NSString *NetworkControllerDidReceiveMessageNotification = @"NetworkControllerDidReceiveMessageNotification";

@implementation NetworkController

static NSString *FakeEmail()
{
	struct utsname n;
	uname(&n);
	return [NSString stringWithFormat: @"%s@%s", getenv("USER"), n.nodename];
}

static NetworkController *sharedNetworkController = nil;

+ (NetworkController*)sharedNetworkController
{
	return sharedNetworkController;
}

- (id) init
{
	self = [super init];
	
	connectedPeerInfo = [[NSMutableDictionary alloc] init];
	openChatWindowControllers = [[NSMutableArray alloc] init];
	myPeer = [[CONetworkPeer alloc] init];
	[myPeer setDelegate: self];
	
	assert(sharedNetworkController == nil);
	sharedNetworkController = self;
	
	return self;
}

- (void) dealloc
{
	[connectedPeerInfo release];
	[openChatWindowControllers release];
	[myPeer release];
	[super dealloc];
}

- (NSString*) peerName
{
	return [myPeer peerName];
}

- (void)awakeFromNib
{
	[networkTableView setDoubleAction: @selector(chat:)];
	[networkTableView setTarget: self];
}

- (NSArray*)sortedConnectedPeerNames
{
	return [[connectedPeerInfo allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
}

- (NSString*)fullNameForPeerName: (NSString*)peerName
{
	return [[connectedPeerInfo objectForKey: peerName] objectForKey: @"fullname"];
}
- (NSString*)emailForPeerName: (NSString*)peerName
{
	return [[connectedPeerInfo objectForKey: peerName] objectForKey: @"email"];
}


/**
 * Convenince method to send a property list to another peer
 */
- (void) sendMessage: (id)msg toPeerNamed: (NSString*)name
{
	NSData *data = [NSPropertyListSerialization dataWithPropertyList: msg
															  format: NSPropertyListXMLFormat_v1_0 
															 options: 0
															   error: NULL];
	[myPeer sendData: data toPeerNamed: name];
}

/* NSTableView Data Source */

- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [connectedPeerInfo count];
}
- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSDictionary *infoDict = [connectedPeerInfo objectForKey:
							  [[self sortedConnectedPeerNames] objectAtIndex: rowIndex]];
	
	if ([[aTableColumn identifier] isEqualToString: @"name"])
	{
		return [infoDict objectForKey: @"fullname"];
	}
	else if ([[aTableColumn identifier] isEqualToString: @"email"])
	{
		return [infoDict objectForKey: @"email"];  
	}
	else
	{
		return nil;
	}
}

/* NSTableView delegate */

- (BOOL) tableView:(NSTableView *)aTableView shouldEditTableColumn: (NSTableColumn*)col row: (NSInteger)row
{
	return NO;
}

- (void)usersListDidChange
{
	[networkTableView reloadData];
	// Hack to notify the sharing window of the update as well.
	[sharingController usersListDidChange];
}


/* CONetworkPeerDelegate methods */

- (void) networkPeer:(CONetworkPeer*)peer didReceiveConnectionFromPeerNamed: (NSString*)name
{
	// Ask for user info before we record this peer
	NSLog(@"Only should recieve one connection from %@!!!!!!!!!", name);
	[self sendMessage:
	 [NSDictionary dictionaryWithObjectsAndKeys:
      @"userinfoquery", @"messagetype",
      nil]
		  toPeerNamed: name];
}
- (void) networkPeer:(CONetworkPeer*)peer didReceiveDisconnectionFromPeerNamed: (NSString*)name
{
	[connectedPeerInfo removeObjectForKey: name];
	[self usersListDidChange];
	NSLog(@"<disconnect> Peers: %@", connectedPeerInfo);
}
- (void) networkPeer:(CONetworkPeer*)peer didReceiveData: (NSData*)data fromPeerNamed: (NSString*)name
{
	id plist = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
	NSLog(@"Got message %@", plist);
	NSString *type = [plist valueForKey: @"messagetype"];
	
	if ([type isEqualToString: @"userinfoquery"])
	{
		[self sendMessage:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  @"userinforesponse", @"messagetype",
		  NSFullUserName(), @"fullname",
		  FakeEmail(), @"email",
		  nil]
			  toPeerNamed: name];
		NSLog(@"Responding to info query to %@", name);
	}
	else if ([type isEqualToString: @"userinforesponse"])
	{
		NSLog(@"Only should recieve one response from %@!!!!!!!!!", name);
		// The peer sent us their user info; record them as connected.
		[connectedPeerInfo setObject: [NSDictionary dictionaryWithObjectsAndKeys:
									   name, @"name",
									   [plist objectForKey:@"fullname"], @"fullname",
									   [plist objectForKey:@"email"], @"email",
									   nil]
							  forKey: name];
		
		[self usersListDidChange];
		NSLog(@"<connect> Peers: %@", connectedPeerInfo);
	}
	else if ([type isEqualToString: @"chat"])
	{
		ChatWindowController *chatController = [self beginChatWith: name];
		[chatController receiveMessage: [plist objectForKey: @"message"]];
	}
	else
	{
		[NSTimer scheduledTimerWithTimeInterval: MESSAGE_DELAY
										 target:self
									   selector:@selector(delayMessage:)
									   userInfo:plist 
										repeats:NO];
	}
}

- (void)delayMessage:(NSTimer*)timer
{
	[[NSNotificationCenter defaultCenter] postNotificationName: NetworkControllerDidReceiveMessageNotification
														object: self
													  userInfo: [timer userInfo]];
}

/* IB Actions */

- (IBAction) chat: (id)sender
{
	NSInteger row = [networkTableView selectedRow];
	if (row >= 0 && row < [connectedPeerInfo count])
	{
		NSString *selectedPeerName = [[self sortedConnectedPeerNames] objectAtIndex: row];
		[self beginChatWith: selectedPeerName];
	}  
}

- (ChatWindowController *) beginChatWith: (NSString*)peerName
{
	ChatWindowController *result = nil;
	for (ChatWindowController *chatController in openChatWindowControllers)
	{
		if ([[chatController chatPeerName] isEqualToString: peerName])
		{
			result = chatController;
			break;
		}
	}
	if (result == nil)
	{
		NSString *fullName = [[connectedPeerInfo objectForKey: peerName] objectForKey: @"fullname"];
		result = [[[ChatWindowController alloc] initWithNetworkController: self 
															 chatPeerName: peerName
														 chatPeerFullName: fullName] autorelease];
		[result showWindow: nil];    
		[openChatWindowControllers addObject: result];
	}
	
	[[result window] makeKeyAndOrderFront: nil];
	return result;
}

/* ChatWindowController callbacks */

- (void) chatDidClose: (ChatWindowController *)controller
{
	NSLog(@"Logged %@ as closing", controller);
	[openChatWindowControllers removeObject: controller]; // controller will be released
}
- (void) chatSendMessage: (NSString*)message toPeerNamed: (NSString*)name
{
	[self sendMessage:
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  @"chat", @"messagetype",
	  [myPeer peerName], @"from",
	  name, @"to",
	  message, @"message",
	  nil]
          toPeerNamed: name];
}


@end
