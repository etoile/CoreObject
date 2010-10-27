#import "SharingSessionPeer.h"
#import "COStoreCoordinator.h"
#import "COHistoryGraphNode.h"

@implementation SharingSessionPeer

- (id) initWithSharingSession: (SharingSession*)session
                   clientName: (NSString*)name
{
  self = [super init];
  ASSIGN(clientName, name);
  owner = session;
  return self;
}

- (void)dealloc
{
  [clientName release];
  [shadowHistoryGraphNodeUUID release];
  [super dealloc];
}

#if 0
- (void)recieveResponse: (NSDictionary*)plist
{
  COHistoryGraphNode *shadowNode = [[doc objectContext] storeCoordinator] historyGraphNodeForUUID: shadowHistoryGraphNodeUUID];

  COEditingContext *shadowContext = [[COEditingContext alloc] initWithHistoryGraphNode: shadowNode];
    

  [shadowContext release];
}

- (void)sendMessage
{
  NSDictionary *plist;

  ASSIGN(shadowHistoryGraphNodeUUID, [[[[doc objectContext] storeCoordinator] tip] uuid]);


  [netPeer sendObject: plist toPeer: peerName];

  isWaitingForResponse = YES;  
}

#endif

@end
