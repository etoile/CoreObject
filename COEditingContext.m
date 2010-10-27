#import "COEditingContext.h"

@implementation COEditingContext


- (id) initWithHistoryGraphNode: (COHistoryGraphNode*)node
{
  self = [self initWithStoreCoordinator: [node storeCoordinator]];
  ASSIGN(_baseHistoryGraphNode, node);
  return self;
}

- (id) initWithStoreCoordinator: (COStoreCoordinator*)store
{
  SUPERINIT;
  ASSIGN(_storeCoordinator, store);
  assert(store != nil);
  
  _changedObjectUUIDs = [[NSMutableSet alloc] init];
  _instantiatedObjects = [[NSMutableDictionary alloc] init];
  
  [self setBaseHistoryGraphNode: [[self storeCoordinator] tip]];
  if ([self baseHistoryGraphNode] != nil)
  {
    NSLog(@"COEditingContext init: loaded previous history graph node");
  }
  else
  {
    NSLog(@"COEditingContext init: no previous history graph node, need to make a commit first");
  }

  return self;
}

- (void) dealloc
{
  DESTROY(_baseHistoryGraphNode);
  DESTROY(_storeCoordinator);
  DESTROY(_changedObjectUUIDs);
  DESTROY(_instantiatedObjects);
  [super dealloc];
}

- (id) init
{
  return [self initWithHistoryGraphNode: nil];
}

- (void) commitWithMetadata: (NSDictionary*)metadata
{
  COHistoryGraphNode *newNode = [[self storeCoordinator]
                    commitChangesInObjectContext: self
                                       afterNode: [self baseHistoryGraphNode]
                                    withMetadata: metadata];
  [self setBaseHistoryGraphNode: newNode];
  [_changedObjectUUIDs removeAllObjects];
}

- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription
{
  NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
  [metadata setObject: type forKey: kCOTypeHistoryGraphNodeProperty];
  [metadata setObject: shortDescription forKey: kCOShortDescriptionHistoryGraphNodeProperty];
  [metadata setObject: longDescription forKey: kCODescriptionHistoryGraphNodeProperty];
  [self commitWithMetadata: metadata];
}

- (void) commit
{
  [self commitWithMetadata: nil];
}

- (COStoreCoordinator *) storeCoordinator
{
  return _storeCoordinator;
}

- (COHistoryGraphNode *) baseHistoryGraphNode
{
  return _baseHistoryGraphNode;
}

- (void) setBaseHistoryGraphNode: (COHistoryGraphNode*)node
{
  ASSIGN(_baseHistoryGraphNode, node);
}

- (BOOL) hasChanges
{
  return ![_changedObjectUUIDs isEmpty];
}

- (COObjectGraphDiff *) changes
{
  COEditingContext *temp = [[COEditingContext alloc] initWithHistoryGraphNode: [self baseHistoryGraphNode]];
  COObjectGraphDiff *diff = [COObjectGraphDiff diffObjectContext: self with: temp];
  [temp release];
  return diff;
}

- (BOOL) objectHasChanges: (ETUUID*)uuid
{
  return [_changedObjectUUIDs containsObject: uuid];
}

- (COObject*) objectForUUID: (ETUUID*)uuid
{
  COObject *result = [_instantiatedObjects objectForKey: uuid];
  
  if (result == nil)
  {
    result = [[COObject alloc] initFaultedObjectWithContext: self uuid: uuid];
    if (result != nil)
    {
      // Save the COObject instance in our map
      [_instantiatedObjects setObject: result forKey: uuid];
      
      [result release];
    }
  }
  
  return result;
}

@end


@implementation COEditingContext (Private)

- (void) markObjectUUIDChanged: (ETUUID*)uuid
{
  [_changedObjectUUIDs addObject: uuid];
}
- (void) markObjectUUIDUnhanged: (ETUUID*)uuid
{
  [_changedObjectUUIDs removeObject: uuid];
}
- (NSArray *) changedObjects
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [_changedObjectUUIDs count]];
  for (ETUUID *uuid in _changedObjectUUIDs)
  {
    [result addObject: [self objectForUUID: uuid]];
  }
  return result;
}
- (void) recordObject: (COObject*)object forUUID: (ETUUID*)uuid
{
  [_instantiatedObjects setObject: object forKey: uuid];
}
@end


@implementation COEditingContext (Rollback)


- (void) revert
{
  [self revertObjects: [self changedObjects]];
}

- (void) rollbackToRevision: (COHistoryGraphNode *)node
{
  // FIXME: this is broken, it only reverts loaded objects
  
  [_changedObjectUUIDs removeAllObjects];
  ASSIGN(_baseHistoryGraphNode, node);
  for (COObject *obj in [_instantiatedObjects allValues])
  {
    [obj unfaultWithData: [[self storeCoordinator] dataForObjectWithUUID: [obj uuid]
                                                      atHistoryGraphNode: node]];
  }
  [_changedObjectUUIDs addObjectsFromArray: [_instantiatedObjects allKeys]];
}

- (void)selectiveUndoChangesMadeInRevision: (COHistoryGraphNode *)ver
{
  NSLog(@"-[COEditingContext selectiveUndoChangesMadeInRevision: %@]", ver);
  
  COHistoryGraphNode *priorToVer = [[ver parents] objectAtIndex: 0]; // FIXME:..
  NSLog(@"Using %@ as parent", priorToVer);
    
  COObjectGraphDiff *oa = [COObjectGraphDiff diffHistoryNode:ver  withHistoryNode: priorToVer];
  NSLog(@"!!!!OA %@", oa);
  COObjectGraphDiff *ob = [COObjectGraphDiff diffHistoryNode:ver withHistoryNode: [self baseHistoryGraphNode]];
  NSLog(@"!!!!OB %@", ob);
  COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
  NSLog(@"!!!!merged %@", merged);
  
  [merged applyToContext: self];
}

- (void) revertObjects: (NSArray*)objects
{
  for (COObject *object in objects)
  {
    [object revert];
  }
}

- (void) commitObjects: (NSArray*)objects
{
  // FIXME: commit owned children of objects
  COHistoryGraphNode *newNode = [[self storeCoordinator] commitChangesInObjects: objects
                                                           afterNode: [self baseHistoryGraphNode]];
  [self setBaseHistoryGraphNode: newNode];
}
- (void) rollbackObjects: (NSArray*)objects toRevision: (COHistoryGraphNode *)ver
{
}
- (void) threeWayMergeObjects: (NSArray*)objects withObjects: (NSArray*)otherObjects bases: (NSArray*)bases
{
}
- (void) twoWayMergeObjects: (NSArray*)objects withObjects: (NSArray*)otherObjects
{
}
- (void) selectiveUndoChangesInObjects: (NSArray*)objects madeInRevision: (COHistoryGraphNode *)ver
{
}



@end