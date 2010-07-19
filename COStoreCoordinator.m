#import "COStoreCoordinator.h"
#import "COSerializer.h"
#import "NSData+sha1.h"

@implementation COStoreCoordinator

- (id)initWithURL: (NSURL*)url
{
  SUPERINIT;
  _store = [[COStore alloc] initWithURL: url];
  _historyGraphNodes = [[NSMutableDictionary alloc] init];

  return self;
}

- (void) dealloc
{
  DESTROY(_store);
  DESTROY(_historyGraphNodes);
  [super dealloc];
}

- (NSArray*)rootHistoryGraphNodes
{
  return nil;
}

- (COHistoryGraphNode *)tip
{
  return [self historyGraphNodeForUUID:
    [ETUUID UUIDWithString: [COSerializer unserializeData: [_store dataForKey: @"tip"]]]];
}

- (COHistoryGraphNode *) createBranchOfNode: (COHistoryGraphNode*)node
{
  COHistoryGraphNode *newNode = [[[COHistoryGraphNode alloc] initWithUUID: [ETUUID UUID]
           storeCoordinator: self
            properties: nil
            parentNodeUUIDs: [NSArray arrayWithObject:node]
            childNodeUUIDs: nil
          uuidToObjectVersionMaping: nil] autorelease];
  [node addChildNodeUUID: [newNode uuid]];
  
  // FIXME: these should be atomic together
  [self commitHistoryGraphNode: node];
  [self commitHistoryGraphNode: newNode];
  return newNode;
}
- (COHistoryGraphNode *) createMergeOfNode: (COHistoryGraphNode*)node1 andNode: (COHistoryGraphNode*)node2
{
  COHistoryGraphNode *newNode = nil;
  
  return newNode;
}
- (COHistoryGraphNode *) commitChangesInObjectContext: (COObjectContext *)ctx  afterNode: (COHistoryGraphNode*)node
{
  return [self commitChangesInObjects: [ctx changedObjects] afterNode: node];
}

- (COHistoryGraphNode *) commitChangesInObjects: (NSArray *)objects  afterNode: (COHistoryGraphNode*)node
{
  NSMutableDictionary *mapping = [NSMutableDictionary dictionaryWithCapacity: [objects count]];
  
  for (COObject *obj in objects)
  {
    NSData *hash = [obj sha1Hash];
    
    [_store setData: [COSerializer serializeObject: [obj propertyList]]
           forKey: [hash hexString]];
           
    [mapping setObject: hash forKey: [obj uuid]];
  }

  COHistoryGraphNode *newNode = [[[COHistoryGraphNode alloc] initWithUUID: [ETUUID UUID]
           storeCoordinator: self
            properties: nil
            parentNodeUUIDs: node ? [NSArray arrayWithObject: node] : nil
             childNodeUUIDs: nil
          uuidToObjectVersionMaping: mapping] autorelease];
  
  if (node)
  {
    [node addChildNodeUUID: [newNode uuid]];
  
    // FIXME: these next two lines should be atomic together
    [self commitHistoryGraphNode: node];
  }
  [self commitHistoryGraphNode: newNode];
  return newNode;
}

@end

@implementation COStoreCoordinator (Private)

- (NSDictionary*) dataForObjectWithUUID: (ETUUID*)uuid atHistoryGraphNode: (COHistoryGraphNode *)node
{
  // Find the node in which the given object UUID was last modified
  NSData *hash = nil;
  while ((hash = [[node uuidToObjectVersionMaping] objectForKey: uuid]) == nil)
  {
    if ([[node parents] count] != 1)
    {
      NSLog(@"Warning: requested UUID %@ not found.", uuid);
      return nil;
    }
    node = [[node parents] objectAtIndex: 0];
  }
  
  NSDictionary *data = [COSerializer unserializeData: [_store dataForKey: [hash hexString]]];
  if (nil == data)
  {
    [NSException raise: NSInternalInconsistencyException format: @"Object %@ data missing", uuid];
  }
  
  return data;
}

- (COHistoryGraphNode *) historyGraphNodeForUUID: (ETUUID*)uuid
{
  COHistoryGraphNode *node = [_historyGraphNodes objectForKey: uuid];
  if (nil == node)
  {
    NSDictionary *nodePlist = [COSerializer unserializeData: [_store dataForKey: [uuid stringValue]]];
    node = [[[COHistoryGraphNode alloc] initWithPropertyList: nodePlist storeCoordinator: self] autorelease];
    NSLog(@"Read history node %@", [node uuid]);
    [_historyGraphNodes setObject: node forKey: [node uuid]];
  }

  return node;
}

- (void) commitHistoryGraphNode: (COHistoryGraphNode *)node
{
  //FIXME: ugly
  [_historyGraphNodes setObject: node forKey: [node uuid]];

  [_store setData: [COSerializer serializeObject: [node propertyList]]
           forKey: [[node uuid] stringValue]];

  if ([[node branches] isEmpty])
  {
    NSLog(@"Marking %@ as tip", node);
    [_store setData: [COSerializer serializeObject: [[node uuid] stringValue]]
             forKey: @"tip"];
  }

  NSLog(@"History graph node %@ committed.", [node uuid]);
}

@end
