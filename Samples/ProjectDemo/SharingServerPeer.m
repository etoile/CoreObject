#import "SharingServerPeer.h"
#import <CoreObject/CoreObject.h>
#import "NetworkController.h"

@implementation SharingServerPeer

- (id) initWithSharingSession: (SharingServer*)session
                   clientName: (NSString*)name
{
	self = [super init];
	ASSIGN(clientName, name);
	owner = session;
	
	/* See -[SharingClient initWithInvitationMessage:] */
	
	// FIXME: ugly access
	COHistoryNode *shadow = [[[[owner document] objectContext] storeCoordinator] tip];
	
	ASSIGN(shadowHistoryGraphNodeUUID, [shadow uuid]);
	assert(shadowHistoryGraphNodeUUID != nil);
	
	// Snapshot the document state at shadowHistoryGraphNodeUUID so we can send it to the client
	
	NSMutableArray *startingHistoryGraphNodeData = [NSMutableArray array];
	
	NSArray *allObjectsUUIDsInDocument = 
    [[[[[owner document] allStronglyContainedObjects] mappedCollection] uuid]
	 arrayByAddingObject: [[owner document] uuid]];
	
	for (ETUUID *uuid in allObjectsUUIDsInDocument)
	{
		NSDictionary *data = [[[[owner document] objectContext] storeCoordinator]
							  dataForObjectWithUUID: uuid
							  atHistoryGraphNode: shadow];
		
		[startingHistoryGraphNodeData addObject: data];
	}
	
	NSDictionary *invitation =  [NSDictionary dictionaryWithObjectsAndKeys:
								 @"sharingInvitationFromServer", @"messagetype",
								 [[owner sessionID] stringValue], @"sessionID",
								 [[NetworkController sharedNetworkController] peerName], @"serverName", 
								 [[[owner document] uuid] stringValue], @"documentUUID",
								 [shadowHistoryGraphNodeUUID stringValue], @"startingHistoryGraphNodeUUID",
								 startingHistoryGraphNodeData, @"startingHistoryGraphNodeData",
								 nil];
	
	isServerWaitingForResponse = YES;
	
	[[NetworkController sharedNetworkController]
	 sendMessage: invitation
	 toPeerNamed: clientName];
	
	return self;
}

- (void)dealloc
{
	[[NetworkController sharedNetworkController]
	 sendMessage:  [NSDictionary dictionaryWithObjectsAndKeys:
					@"sharingDisconnectionFromServer", @"messagetype",
					[[owner sessionID] stringValue], @"sessionID",
					nil]
	 toPeerNamed: clientName];
	
	[clientName release];
	[shadowHistoryGraphNodeUUID release];
	[super dealloc];
}

- (void)synchronizeWithClientIfPossible
{
	NSLog(@"Server: synchronizeWithClientIfPossible");
	
}

- (void)handleMessage: (NSDictionary*)msg
{
	// FIXME: shouldn't be a hard failure
	//assert(isServerWaitingForResponse == YES);
	
	//isServerWaitingForResponse = NO;
	
	NSLog(@"Server handle message %@", msg);  
	
	/*
	 NSDictionary *msg = [NSDictionary dictionaryWithObjectsAndKeys:
	 @"sharingMessageFromClient", @"messagetype",
	 [sessionID stringValue], @"sessionID",
	 [[NetworkController sharedNetworkController] peerName], @"clientName", 
	 [[doc uuid] stringValue], @"documentUUID",
	 [shadowHistoryGraphNodeUUID stringValue], @"oldShadowHistoryGraphNodeUUID",
	 [[node uuid] stringValue], @"newShadowHistoryGraphNodeUUID",
	 datas, @"datas",
	 nil];*/
	
	assert([[shadowHistoryGraphNodeUUID stringValue] isEqual: [msg objectForKey: @"oldShadowHistoryGraphNodeUUID"]]);
	assert([[[owner sessionID] stringValue] isEqual: [msg objectForKey: @"sessionID"]]);
	assert(![[msg objectForKey: @"oldShadowHistoryGraphNodeUUID"] isEqual:
			 [msg objectForKey: @"newShadowHistoryGraphNodeUUID"]]); 
	
	ETUUID *newShadowUUID = [ETUUID UUIDWithString: [msg objectForKey: @"newShadowHistoryGraphNodeUUID"]];
	
	COStoreCoordinator *coordinator = [[[NSApp delegate] editingContext] storeCoordinator];
	COHistoryNode *currentHead = [[[NSApp delegate] editingContext] baseHistoryGraphNode];
	
	COHistoryNode *oldShadowNode = [coordinator historyGraphNodeForUUID: shadowHistoryGraphNodeUUID];
	
	COHistoryNode *tempNodeToMerge = [coordinator commitObjectDatas: [msg objectForKey: @"datas"]
															   afterNode: oldShadowNode
															withMetadata: nil
													 withHistoryNodeUUID: newShadowUUID];
	
	
	COObjectGraphDiff *oa = [COObjectGraphDiff diffHistoryNode:oldShadowNode  withHistoryNode: tempNodeToMerge];
	NSLog(@"*!!!OA %@", oa);
	
	COObjectGraphDiff *ob = [COObjectGraphDiff diffHistoryNode:oldShadowNode withHistoryNode: currentHead];
	NSLog(@"*!!!!OB %@", ob);
	
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
	NSLog(@"*!!!!merged %@", merged);
	
	COEditingContext *tempCtx = [[COEditingContext alloc] initWithHistoryGraphNode: oldShadowNode];
	[merged applyToContext: tempCtx];
	[tempCtx setBaseHistoryGraphNodeUnsafe: currentHead];
	[tempCtx commit];  
	
	ASSIGN(shadowHistoryGraphNodeUUID, newShadowUUID);
}

@end
