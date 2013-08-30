#import "SharingClient.h"
#import "Document.h"
#import "NetworkController.h"
#import "ApplicationDelegate.h"

@implementation SharingClient
#if 0
- (id)initWithInvitationMessage: (NSDictionary*)msg
{
	self = [super init];
	
	/* invitation message format:
	 
	 {
	 sessionID : "uuid",
	 serverName : "server peer name",
	 documentUUID : "uuid",
	 startingHistoryGraphNodeUUID : "node uuid",
	 startingHistoryGraphNodeData : (
	 { uuid : "uuid",
	 data : "data" },
	 ...
	 )
	 }
	 
	 See -[SharingServerPeer initWithSharingSession:clientName:]
	 
	 */
	
	ASSIGN(sessionID, [ETUUID UUIDWithString: [msg objectForKey: @"sessionID"]]);
	assert(sessionID != nil);
	
	ASSIGN(serverName, [msg objectForKey: @"serverName"]);
	assert(serverName != nil);
	
	ASSIGN(shadowHistoryGraphNodeUUID, [ETUUID UUIDWithString: [msg objectForKey: @"startingHistoryGraphNodeUUID"]]);
	assert(shadowHistoryGraphNodeUUID != nil);
	
	isClientWaitingForResponse = NO;
	
	// We need to commit the starting history graph node to our store
	
	COEditingContext *ctx = [[NSApp delegate] editingContext];
	COStoreCoordinator *coordinator = [[[NSApp delegate] editingContext] storeCoordinator];
	COHistoryNode *currentHead = [[[NSApp delegate] editingContext] baseHistoryGraphNode];
	
	COHistoryNode *newNode = [coordinator commitObjectDatas: [msg objectForKey: @"startingHistoryGraphNodeData"]
													   afterNode: currentHead
													withMetadata: nil
											 withHistoryNodeUUID: shadowHistoryGraphNodeUUID];
	[ctx setBaseHistoryGraphNode: newNode];
	
	ETUUID *docUUID = [ETUUID UUIDWithString: [msg objectForKey: @"documentUUID"]];
	assert(docUUID != nil);
	ASSIGN(doc, [ctx objectForUUID: docUUID]);
	assert(doc != nil);
	
	documentWindowController = [[OutlineController alloc] initWithDocument: doc isSharing: YES];
	[documentWindowController showWindow: nil];
	
	// add doc to our project?
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector: @selector(didCommit:)
												 name: COEditingContextBaseHistoryGraphNodeDidChangeNotification 
											   object: [[NSApp delegate] editingContext]];
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[doc release];
	[documentWindowController release]; 
	[serverName release];
	[sessionID release];
	[shadowHistoryGraphNodeUUID release];
	
	[super dealloc];
}

- (NSString*)serverName
{
	return serverName;
}

- (ETUUID*) sessionID
{
	return sessionID;
}
- (Document*) document
{
	return doc;
}
/* COStoreCoordinator notification */

- (void)didCommit: (NSNotification*)notif
{
	[self synchronizeWithServerIfPossible];
}

/**
 * Handle a message from the server
 */
- (void)handleMessage: (NSDictionary*)msg
{
	/*
	 
	 { 
	 messagetype : sharingMessageFromServer,
	 shadowHistoryGraphNodeUUID : uuid,
	 historyGraphNodeData : data // one commit
	 }
	 
	 */
	
	
	// FIXME: shouldn't really be a hard fail
	assert(isClientWaitingForResponse);
	
	isClientWaitingForResponse = NO;
	
	NSLog(@"TODO: Client handle message %@", msg); 
	
#if 0
	ASSIGN(shadowHistoryGraphNodeUUID, [ETUUID UUIDWithString: [msg objectForKey: @"shadowHistoryGraphNodeUUID"]]);
	assert(shadowHistoryGraphNodeUUID != nil);
	
	COHistoryGraphNode *newNode = [[doc objectContext] commitObjectDatas: [msg objectForKey: @"historyGraphNodeData"]
													 withHistoryNodeUUID: shadowHistoryGraphNodeUUID];
	
	// FIXME: merge newNode with base.
	
	[self synchronizeWithServerIfPossible];
#endif
}

- (void)synchronizeWithServerIfPossible
{
	NSLog(@"Client: synchronizeWithServerIfPossible");
	if (isClientWaitingForResponse)
	{
		//NSLog(@"Bailing because we're supposed to be waiting");
		//return;
	}
	
	COStoreCoordinator *coordinator = [[[NSApp delegate] editingContext] storeCoordinator];
	COHistoryNode *currentHead = [[[NSApp delegate] editingContext] baseHistoryGraphNode];
	
	COHistoryNode *shadowNode = [coordinator historyGraphNodeForUUID: shadowHistoryGraphNodeUUID];
	
	if ([shadowNode isEqual: currentHead])
	{
		NSLog(@"Bailing because there are no new commits");
		return;
	}
	
	// Verify that we can reach the shadow node by searching backwards from the base history graph node
	BOOL found = NO;
	for (COHistoryNode *ptr = currentHead; ptr != nil; ptr = [ptr parent])
	{
		if ([ptr isEqual: shadowNode])
		{
			found = YES;
		}
	}
	assert(found); 
	
	NSArray *allObjectsUUIDsInDocument = 
    [[[[doc allStronglyContainedObjects] mappedCollection] uuid]
	 arrayByAddingObject: [doc uuid]];
	
	// Collect UUIDS of all objects changed AFTER the shadow node and before or on the baseHistoryGraphNode
	NSMutableSet *objectsToShare = [NSMutableSet set];
	for (COHistoryNode *ptr = currentHead; ![ptr isEqual: shadowNode]; ptr = [ptr parent])
	{
		[objectsToShare unionSet: [NSSet setWithArray: [[ptr uuidToObjectVersionMaping] allKeys]]];
	}
	
	[objectsToShare intersectSet: [NSSet setWithArray: allObjectsUUIDsInDocument]];
	
	if ([objectsToShare count] == 0)
	{
		NSLog(@"Bailing because there are no changes to the shared document in those commits");
		return;
	}
	
	NSMutableArray *datas = [NSMutableArray array];
	for (ETUUID *uuid in objectsToShare)
	{
		[datas addObject: [coordinator dataForObjectWithUUID:uuid atHistoryGraphNode:currentHead]];
	}
	
	NSDictionary *msg = [NSDictionary dictionaryWithObjectsAndKeys:
						 @"sharingMessageFromClient", @"messagetype",
						 [sessionID stringValue], @"sessionID",
						 [[NetworkController sharedNetworkController] peerName], @"clientName", 
						 [[doc uuid] stringValue], @"documentUUID",
						 [shadowHistoryGraphNodeUUID stringValue], @"oldShadowHistoryGraphNodeUUID",
						 [[currentHead uuid] stringValue], @"newShadowHistoryGraphNodeUUID",
						 datas, @"datas",
						 nil];
	
	// Set the new shadow node
	ASSIGN(shadowHistoryGraphNodeUUID, [currentHead uuid]);
	
	isClientWaitingForResponse = YES;
	[[NetworkController sharedNetworkController]
	 sendMessage: msg
	 toPeerNamed: serverName]; 
	NSLog(@"Sent to %@: %@", serverName, msg);    
}
#endif

@end
