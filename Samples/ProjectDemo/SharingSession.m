#import "SharingSession.h"
#import "ApplicationDelegate.h"
#import "OutlineController.h"

@implementation SharingSession

@synthesize  persistentRoot= _persistentRoot;

- (id)initWithPersistentRoot: (COPersistentRoot *)persistentRoot
					 peerJID: (XMPPJID *)peerJID
				  xmppStream: (XMPPStream *)xmppStream
					isServer: (BOOL)isServer
{
    SUPERINIT;
	
	_persistentRoot = persistentRoot;
	_peerJID = peerJID;
	_xmppStream = xmppStream;
	_isServer = isServer;
	_lastRevisionUUID = [[persistentRoot currentRevision] UUID];
	
	[self setBranches];

	
	OutlineController *docController = [(ApplicationDelegate *)[NSApp delegate]
										controllerForDocumentRootObject: [_persistentRoot rootObject]];
	[docController setSharingSession: self];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(persistentRootDidChange:)
												 name: COPersistentRootDidChangeNotification
											   object: _persistentRoot];
	
	[_xmppStream addDelegate: self delegateQueue: dispatch_get_main_queue()];
	
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) setBranches
{
	_masterBranch = [_persistentRoot currentBranch];
	
	for (COBranch *branch in [_persistentRoot branches])
	{
		if (branch.metadata[@"replcatedBranch"] != nil)
		{
			_originMasterBranch = branch;
			break;
		}
	}
}

- (void) persistentRootDidChange: (NSNotification *)notif
{
	if ([[[_persistentRoot currentRevision] UUID] isEqual: _lastRevisionUUID])
	{
		NSLog(@"Ignoring persistentRootDidChange:");
		return;
	}
	
	NSLog(@"Shared Persistent root did change. Server? %d", (int)_isServer);
	
	[self askPeerToPullFromUs];
}

- (void)askPeerToPullFromUs
{
	[self sendCoreobjectMessageType: @"pull-from-us" to: _peerJID withPayloadPropertyList: @{}];
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

	NSLog(@"< sending %@ to %@ size %d", aType, aJID, (int)[[body XMLString] length]);
	[_xmppStream sendElement:responseMessage];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if ([[message attributeStringValueForName: @"type"] isEqualToString: @"coreobject"])
	{
		NSXMLElement *body = (NSXMLElement *)[message childAtIndex: 0];
		
		NSString *coreObjectMessageName = [body name];
		
		NSLog(@"> recv'd %@, %d chars", coreObjectMessageName, (int)[[body XMLString] length]);
		
		if ([coreObjectMessageName isEqualToString: @"pull-from-us"])
		{
			COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
			id request = [client updateRequestForPersistentRoot: [_persistentRoot UUID]
													   serverID: [_peerJID full]
														  store: [_persistentRoot store]];
			
			[self sendCoreobjectMessageType: @"pull" to:[message from] withPayloadPropertyList:request];
		}
		else if ([coreObjectMessageName isEqualToString: @"pull"])
		{
			id request = [self deserializePropertyList: [body objectValue]];
			
			NSLog(@"Got pull: %@", request);
			
			COSynchronizationServer *server = [[COSynchronizationServer alloc] init];
			id response = [server handleUpdateRequest: request store: [_persistentRoot store]];
			
			[self sendCoreobjectMessageType:@"pull-reply" to:[message from] withPayloadPropertyList:response];
		}
		else if ([coreObjectMessageName isEqualToString: @"pull-reply"])
		{
			id response = [self deserializePropertyList: [body objectValue]];
			
			NSArray *revs = [response[@"revisions"] allKeys];
			NSLog(@"      Got pull reply with revs: %@", revs);
			
			COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
			[client handleUpdateResponse: response store: [_persistentRoot store]];
	
			dispatch_async(dispatch_get_main_queue(), ^() {
				[self pullDidFinish];
			});
			
			//[self pullDidFinish];
		}
	}
	else
	{
		NSLog(@"Ignoring non-Coreobject message %@", message);
	}
}

- (void) pullDidFinish
{
	NSLog(@"Pull did finish");
	
	[self setBranches];
	
	assert(_masterBranch != nil);
	assert(_originMasterBranch != nil);
	
	// Now merge "origin/master" into "master"

    // FF merge?
    
    if ([COLeastCommonAncestor isRevision: [[_masterBranch currentRevision] UUID]
                equalToOrParentOfRevision: [[_originMasterBranch currentRevision] UUID]
						   persistentRoot: [_persistentRoot UUID]
                                    store: [_persistentRoot store]])
    {
        [_masterBranch setCurrentRevision: [_originMasterBranch currentRevision]];
		_lastRevisionUUID = [[_originMasterBranch currentRevision] UUID];
        [_persistentRoot commit];
    }
    else
    {
        // Regular merge
        
        [_masterBranch setMergingBranch: _originMasterBranch];
        
        COMergeInfo *mergeInfo = [_masterBranch mergeInfoForMergingBranch: _originMasterBranch];
        if([mergeInfo.diff hasConflicts])
        {
            NSLog(@"Attempting to auto-resolve conflicts favouring the other user...");
            [mergeInfo.diff resolveConflictsFavoringSourceIdentifier: @"merged"]; // FIXME: Hardcoded
        }
        
		NSLog(@"Applying diff %@", mergeInfo.diff);
		
		
		id<COItemGraph> oldGraph = [_persistentRoot objectGraphContextForPreviewingRevision: mergeInfo.baseRevision];
		id<COItemGraph> mergeResult = [mergeInfo.diff itemTreeWithDiffAppliedToItemGraph: oldGraph];
		
		// FIXME: Works, but an ugly API mismatch when setting object graph context contents
		NSMutableArray *items = [NSMutableArray array];
		for (ETUUID *uuid in [mergeResult itemUUIDs])
		{
			[items addObject: [mergeResult itemForUUID: uuid]];
		}
		[[_masterBranch objectGraphContext] insertOrUpdateItems: items];

		_lastRevisionUUID = [[_masterBranch currentRevision] UUID];
        [[_persistentRoot editingContext] commit];
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

@end
