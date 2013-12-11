#import "SharingSession.h"
#import "ApplicationDelegate.h"
#import "OutlineController.h"

@implementation SharingSession

@synthesize peerJID = _peerJID;

- (id)initWithPeerJID: (XMPPJID *)peerJID
		   xmppStream: (XMPPStream *)xmppStream
			 isServer: (BOOL)isServer
{
    SUPERINIT;
	
	_peerJID = peerJID;
	_xmppStream = xmppStream;
	_isServer = isServer;

	[_xmppStream addDelegate: self delegateQueue: dispatch_get_main_queue()];
	
    return self;
}

- (id)initAsServerWithBranch: (COBranch *)aBranch
				   clientJID: (XMPPJID *)peerJID
				  xmppStream: (XMPPStream *)xmppStream;
{
	self = [self initWithPeerJID: peerJID xmppStream: xmppStream isServer: YES];
	
	_server = [[COSynchronizerServer alloc] initWithBranch: aBranch];
	
	_JSONServer = [COSynchronizerJSONServer new];
	_JSONServer.server = _server;
	_JSONServer.delegate = self;
	
	_server.delegate = _JSONServer;
	
	[_server addClientID: [_peerJID bare]];
	
	
	OutlineController *docController = (OutlineController *)[(ApplicationDelegate *)[NSApp delegate]
										controllerForDocumentRootObject: [aBranch rootObject]];
	ETAssert(docController != nil);
	[docController setSharingSession: self];
	
	return self;
}

- (id)initAsClientWithEditingContext: (COEditingContext *)ctx
						   serverJID: (XMPPJID *)peerJID
						  xmppStream: (XMPPStream *)xmppStream
{
	self = [self initWithPeerJID: peerJID xmppStream: xmppStream isServer: NO];
	
	_client = [[COSynchronizerClient alloc] initWithClientID: [[xmppStream myJID] bare]
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
	
	[(ApplicationDelegate *)[NSApp delegate] registerDocumentRootObject: rootObject];
	
	OutlineController *docController = (OutlineController *)[(ApplicationDelegate *)[NSApp delegate]
										controllerForDocumentRootObject: rootObject];
	ETAssert(docController != nil);
	[docController setSharingSession: self];
}

- (void) JSONClient: (COSynchronizerJSONClient *)client sendTextToServer: (NSString *)text
{
	[self sendCoreObjectMessageWithPayload: text];
}

- (void) JSONServer: (COSynchronizerJSONServer *)server sendText: (NSString *)text toClient: (NSString *)client
{
	[self sendCoreObjectMessageWithPayload: text];
}

- (void) sendCoreObjectMessageWithPayload: (NSString *)aString
{
	NSXMLElement *responseMessage = [NSXMLElement elementWithName:@"message"];
	[responseMessage addAttributeWithName:@"type" stringValue:@"coreobject-synchronizer"];
	[responseMessage addAttributeWithName:@"to" stringValue:[_peerJID full]];
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
			[_JSONServer receiveText: payload fromClient: [[message from] bare]];
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

- (NSString *) peerName
{
	return [_peerJID bare];
}

- (NSString *) ourName
{
	return [[_xmppStream myJID] bare];
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
