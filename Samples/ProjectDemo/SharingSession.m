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

- (void) persistentRootDidChange: (NSNotification *)notif
{
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
	
	[_xmppStream sendElement:responseMessage];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if ([[message attributeStringValueForName: @"type"] isEqualToString: @"coreobject"])
	{
		NSXMLElement *body = (NSXMLElement *)[message childAtIndex: 0];
		
		NSString *coreObjectMessageName = [body name];
		
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
			
			NSLog(@"Got pull reply %@", response);
			
			COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
			[client handleUpdateResponse: response store: [_persistentRoot store]];
		
			[self pullDidFinish];
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
	
	for (COBranch *branch in [_persistentRoot branches])
	{
		NSLog(@"Branch: %@", branch);
	}
	
	/*
	// Now merge "origin/master" into "master"
    
    COPersistentRootInfo *info = [[_persistentRoot store] persistentRootInfoForUUID: [_persistentRoot UUID]];
    
    ETUUID *uuid = [[[info branchInfosWithMetadataValue: [[[source currentBranch] UUID] stringValue]
                                                 forKey: @"replcatedBranch"] firstObject] UUID];
    
    COBranch *master = [dest currentBranch];
    COBranch *originMaster = [dest branchForUUID: uuid];
    assert(master != nil);
    assert([info branchInfoForUUID: uuid] != nil);
    assert(originMaster != nil);
    assert(![master isEqual: originMaster]);
    
    // FF merge?
    
    if ([COLeastCommonAncestor isRevision: [[master currentRevision] UUID]
                equalToOrParentOfRevision: [[originMaster currentRevision] UUID]
						   persistentRoot: [dest UUID]
                                    store: [dest store]])
    {
        [master setCurrentRevision: [originMaster currentRevision]];
        [dest commit];
    }
    else
    {
        // Regular merge
        
        [master setMergingBranch: originMaster];
        
        COMergeInfo *mergeInfo = [master mergeInfoForMergingBranch: originMaster];
        if([mergeInfo.diff hasConflicts])
        {
            NSLog(@"Attempting to auto-resolve conflicts favouring the other user...");
            [mergeInfo.diff resolveConflictsFavoringSourceIdentifier: @"merged"]; // FIXME: Hardcoded
        }
        
        [mergeInfo.diff applyTo: [master objectGraphContext]];
        
        // HACK: should be a regular -commit, I guess, but there's a bug where
        // -commit uses the last used undo track, instead of none. So explicitly pass nil,
        // so this commit doesn't record an undo command.
        [[dest editingContext] commitWithUndoTrack: nil];
    }
	 */
}

@end
