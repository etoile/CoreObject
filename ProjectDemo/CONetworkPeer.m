#import "CONetworkPeer.h"
#include <sys/utsname.h>

@protocol CONetworkPeerDOProtocol
- (void) receiveData: (NSData*)data fromPeerNamed: (NSString*)name;
- (void) recieveConnectionProxy: (CONetworkPeer*)proxy fromPeerNamed: (NSString*)name;
- (void) recieveDisconnectionFromPeerNamed: (NSString*)name;
@end

@interface CONetworkPeer (DOMethods) <CONetworkPeerDOProtocol>
- (void) receiveData: (NSData*)data fromPeerNamed: (NSString*)name;
- (void) recieveConnectionProxy: (CONetworkPeer*)proxy fromPeerNamed: (NSString*)name;
- (void) recieveDisconnectionFromPeerNamed: (NSString*)name;
@end


@implementation CONetworkPeer

@synthesize delegate;

- (id) init
{
	self = [super init];
	
	connectedPeers = [[NSMutableDictionary alloc] init];
	vendingConnection = [[NSConnection alloc] initWithReceivePort: [[[NSSocketPort alloc] init] autorelease]
														 sendPort: nil];
	[vendingConnection setRootObject: self];
	[vendingConnection registerName: [self peerName]
					 withNameServer: [NSSocketPortNameServer sharedInstance]];
	
	netService = [[NSNetService alloc] initWithDomain: @"local."
	                                             type: @"_projectdemo._tcp."
	                                             name: [self peerName]
												 port: 50001];
	[netService setDelegate: self];
	[netService publish];
	
	serviceBrowser = [[NSNetServiceBrowser alloc] init];
	[serviceBrowser setDelegate: self];
	[serviceBrowser searchForServicesOfType: @"_projectdemo._tcp."
								   inDomain: @"local."];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(appWillTerminate:)
												 name: NSApplicationWillTerminateNotification
											   object: [NSApplication sharedApplication]];
	return self;
}

- (void)dealloc
{
	[netService release];
	[vendingConnection release];
	[serviceBrowser release];
	[peerName release];
	[connectedPeers release];
	[super dealloc];
}

- (NSString *)peerName
{
	if (peerName == nil)
	{
		srand(time(NULL));
		struct utsname n;
		uname(&n);
		peerName = [[NSString alloc] initWithFormat: @"projectdemo-%s-%d@%s",
					getenv("USER"), (int)rand(), n.nodename];
	}
	return peerName;
}

- (void)sendData: (NSData*)data toPeerNamed: (NSString*)name
{
	CONetworkPeer *proxy = [connectedPeers objectForKey: name];
	if (nil == proxy)
	{
		NSLog(@"ERROR: sending data to an invalid peer %@", name);
		NSLog(@"THe valid peers are: %@", [connectedPeers allKeys]);
	}
	@try
	{
		[proxy receiveData: data fromPeerNamed: peerName]; // DO call
	}
	@catch (NSException *e)
	{
		[connectedPeers removeObjectForKey: name];
		[[self delegate] networkPeer: self didReceiveDisconnectionFromPeerNamed: name];
	}
}

/* NSApplication notification */

/**
 * When we exit cleanly, we can be nice and tell all of our peers we have
 * disconnected. If we exit unclenaly, nothing bad happens, but it will look
 * like we're still online until one of our peers tries to send us something
 */
- (void)appWillTerminate: (NSNotification*)notif
{
	NSLog(@"Telling our peers we are leaving...");
	for (NSString *name in [connectedPeers allKeys])
	{
		CONetworkPeer *proxy = [connectedPeers objectForKey: name];
		@try
		{
			[proxy recieveDisconnectionFromPeerNamed: peerName]; // DO Call
		}
		@catch (NSException *e)
		{
			NSLog(@"Warning, sending disconnect notification to %@ failed", name);
		}
	}
}

/* NSNetServiceBrowser delegate */

- (void)netServiceBrowser: (NSNetServiceBrowser *)aNetServiceBrowser
		   didFindService: (NSNetService *)aNetService
               moreComing: (BOOL)moreComing
{
	if ([[self peerName] isEqualToString: [aNetService name]])
	{
		NSLog(@"Found ourself.");
	}
	else
	{
		NSLog(@"Found service %@", aNetService);
		[aNetService setDelegate: self];
		[aNetService retain];
		[aNetService resolveWithTimeout: 10];
	}
}

/* NSNetService delegate */

- (void)netServiceDidPublish: (NSNetService*)aService
{
	NSLog(@"Net service %@ pubilshed.", aService);
}
- (void)netService: (NSNetService*)aService didNotPublish: (NSDictionary*)error
{
	NSLog(@"ERROR! Net service %@ did not publish. %@", aService, error);
}

/**
 * Note: the docs say this may be called multiple times (e.g. for IPv4 and v6)
 */
- (void)netServiceDidResolveAddress: (NSNetService *)aNetService
{
	NSLog(@"Resolved service %@", aNetService);
	if (nil != [connectedPeers objectForKey: [aNetService name]])
	{
		NSLog(@"Already connected to %@, ignoring", [aNetService name]);
		[aNetService release];
		return;
	}
	
	NSConnection *conn = [NSConnection connectionWithRegisteredName: [aNetService name]
															   host: [aNetService hostName]
													usingNameServer: [NSSocketPortNameServer sharedInstance]];
	CONetworkPeer *proxy = [conn rootProxy];
	[conn setRequestTimeout: 2.0];
	[conn setReplyTimeout: 2.0];
	if (nil == proxy)
	{
		NSLog(@"Error connecting to DO vendor for %@", [aNetService name]);
	}
	else
	{
		[connectedPeers setObject: proxy 
						   forKey: [aNetService name]];
		
		[proxy setProtocolForProxy: @protocol(CONetworkPeerDOProtocol)];
		@try
		{
			[proxy recieveConnectionProxy: self fromPeerNamed: [self peerName]]; // DO Call - tell the remote peer about us
		}
		@catch (NSException *e)
		{
			NSLog(@"Warning, sending connection notification to %@ failed", [aNetService name]);
			[connectedPeers removeObjectForKey: [aNetService name]];
			[aNetService release];
			return;
		}
		
		[[self delegate] networkPeer: self didReceiveConnectionFromPeerNamed: [aNetService name]];
	}
	
	[aNetService release];
}

- (void)netService: (NSNetService *)aNetService didNotResolve: (NSDictionary *)error
{
	NSLog(@"Resolving failed: %@", error);
	[aNetService release];
}

@end

@implementation CONetworkPeer (DOMethods)

- (void) receiveData: (NSData*)data fromPeerNamed: (NSString*)name
{
	[[self delegate] networkPeer: self didReceiveData: data fromPeerNamed: name];
}

- (void) recieveConnectionProxy: (CONetworkPeer*)proxy fromPeerNamed: (NSString*)name
{
	[connectedPeers setObject: proxy 
					   forKey: name];
	[[self delegate] networkPeer: self didReceiveConnectionFromPeerNamed: name];
	NSLog(@"Received connection from %@", name);
}

- (void) recieveDisconnectionFromPeerNamed: (NSString*)name
{
	if ([connectedPeers objectForKey: name] != nil)
	{
		[connectedPeers removeObjectForKey: name];
		[[self delegate] networkPeer: self didReceiveDisconnectionFromPeerNamed: name];
		NSLog(@"Received disconnection from %@", name);
	}
}

@end