#import "SharingSession.h"
#import "ApplicationDelegate.h"
#import "OutlineController.h"

@implementation SharingSession

- (id)initAsServerWithBranch: (COBranch *)aBranch
				  xmppStream: (XMPPStream *)xmppStream;
{
	NILARG_EXCEPTION_TEST(aBranch);
	NILARG_EXCEPTION_TEST(xmppStream);

	SUPERINIT;
	
	_isServer = YES;
	_xmppStream = xmppStream;
	[_xmppStream addDelegate: self delegateQueue: dispatch_get_main_queue()];
	
	_server = [[COSynchronizerServer alloc] initWithBranch: aBranch];
	
	_JSONServer = [COSynchronizerJSONServer new];
	_JSONServer.server = _server;
	_JSONServer.delegate = self;
	
	_server.delegate = _JSONServer;
	
//	OutlineController *docController = (OutlineController *)[(ApplicationDelegate *)[NSApp delegate]
//										controllerForDocumentRootObject: [aBranch rootObject]];
//	ETAssert(docController != nil);
//	[docController setSharingSession: self];
//	
	return self;
}

- (void) addClientJID: (XMPPJID *)peerJID
{
	ETAssert(_isServer);

	[_server addClientID: [peerJID full]];
}

/**
 * Returns YES if the given JID is one of this server's clients.
 *
 * Only looks at the bare portion of the JID, because the use case for this
 * is showing which users in a roster we are currently sharing with, and
 * a roster only gives you bare JIDs.
 */
- (BOOL) isJIDClient: (XMPPJID *)peerJID
{
	for (NSString *fullJIDString in [_server clientIDs])
	{
		XMPPJID *bareJID = [[XMPPJID jidWithString: fullJIDString] bareJID];
		if ([bareJID isEqual: [peerJID bareJID]])
		{
			return YES;
		}
	}
	
	return NO;
}

- (id)initAsClientWithEditingContext: (COEditingContext *)ctx
						   serverJID: (XMPPJID *)peerJID
						  xmppStream: (XMPPStream *)xmppStream
{
	SUPERINIT;
	
	_isServer = NO;
	_xmppStream = xmppStream;
	_serverJID = peerJID;

	[_xmppStream addDelegate: self delegateQueue: dispatch_get_main_queue()];
	
	_client = [[COSynchronizerClient alloc] initWithClientID: [[xmppStream myJID] full]
											  editingContext: ctx];
	
	_JSONClient = [COSynchronizerJSONClient new];
	_JSONClient.client = _client;
	_JSONClient.delegate = self;
	
	_client.delegate = _JSONClient;
	
	return self;
}

- (void) JSONClient: (COSynchronizerJSONClient *)client didStartSharingOnBranch: (COBranch *)aBranch
{
	ETAssert(aBranch !=  nil);
	
	Document *rootObject = [aBranch rootObject];
	
	OutlineController *docController = (OutlineController *) [(ApplicationDelegate *)[NSApp delegate] registerDocumentRootObject: rootObject];
	
	ETAssert(docController != nil);
	[docController setSharingSession: self];
}

- (void) JSONClient: (COSynchronizerJSONClient *)client sendTextToServer: (NSString *)text
{
	[self sendCoreObjectMessageWithPayload: text toFullJIDString: [_serverJID full]];
}

- (void) JSONServer: (COSynchronizerJSONServer *)server sendText: (NSString *)text toClient: (NSString *)client
{
	[self sendCoreObjectMessageWithPayload: text toFullJIDString: client];
}

- (void) sendCoreObjectMessageWithPayload: (NSString *)aString toFullJIDString: (NSString *)fullJID
{
	NSXMLElement *responseMessage = [NSXMLElement elementWithName:@"message"];
	[responseMessage addAttributeWithName:@"type" stringValue: @"coreobject-synchronizer"];
	[responseMessage addAttributeWithName:@"to" stringValue: fullJID];
	[responseMessage setObjectValue: aString];

	NSLog(@"<-- sending %d chars", (int)[[responseMessage XMLString] length]);
	[_xmppStream sendElement:responseMessage];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if ([[message attributeStringValueForName: @"type"] isEqualToString: @"coreobject-synchronizer"])
	{
		NSString *payload = [message stringValue];
		
		if (_isServer)
			[_JSONServer receiveText: payload fromClient: [[message from] full]];
		else
			[_JSONClient receiveTextFromServer: payload];
		
		NSLog(@"--> received %d chars", (int)[[message XMLString] length]);
	}
	else
	{
		NSLog(@"Ignoring non-Coreobject message %@", message);
	}
}

- (BOOL) isServer
{
	return _isServer;
}

- (NSString *) ourName
{
	return [[_xmppStream myJID] full];
}

- (COPersistentRoot *) persistentRoot
{
	if (_isServer)
	{
		return _server.persistentRoot;
	}
	else
	{
		return _client.persistentRoot;
	}
}

@end
