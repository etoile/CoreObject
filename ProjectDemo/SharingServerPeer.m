#import "SharingServerPeer.h"
#import "COStoreCoordinator.h"
#import "COHistoryGraphNode.h"
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
  COHistoryGraphNode *shadow = [[[[owner document] objectContext] storeCoordinator] tip];
  
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

  NSLog(@"TODO: Server handle message %@", msg);  
  
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
  
  ASSIGN(shadowHistoryGraphNodeUUID, [ETUUID UUIDWithString: [msg objectForKey: @"newShadowHistoryGraphNodeUUID"]]);
  
  COEditingContext *ctx = [[NSApp delegate] editingContext];
  COHistoryGraphNode *newNode = [ctx commitObjectDatas: [msg objectForKey: @"datas"]
                                   withHistoryNodeUUID: shadowHistoryGraphNodeUUID];

}

@end
