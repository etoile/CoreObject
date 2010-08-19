#import "COHistoryGraphNode.h"


@implementation COHistoryGraphNode

- (NSString*) description
{
  return [NSString stringWithFormat: @"History graph node %@, %d parents %d branches %d objects", 
    [[self uuid] stringValue], [_parentNodeUUIDs count], [_childNodeUUIDs count], [[self uuidToObjectVersionMaping] count]];
}

- (COStoreCoordinator *) storeCoordinator
{
  return _store;
}

- (NSArray *)parents
{
  // Somewhat inefficient but avoids the problem of ciruclar references between
  // nodes of the graph, and makes serialization/deserialization to property
  // list more straightforward.
  // (It would be clearer if COHistoryGraphNode held pointers to real parent/child objects)
  
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [_parentNodeUUIDs count]];
  for (ETUUID *uuid in _parentNodeUUIDs)
  {
    COHistoryGraphNode *node = [_store historyGraphNodeForUUID: uuid];
    if (node)
    {
      [result addObject: node];
    }
  }
  return result;
}

- (NSArray *)branches
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [_childNodeUUIDs count]];
  for (ETUUID *uuid in _childNodeUUIDs)
  {
    COHistoryGraphNode *node = [_store historyGraphNodeForUUID: uuid];
    if (node)
    {
      [result addObject: node];
    }
  }
  return result;
}

- (NSDictionary *)uuidToObjectVersionMaping;
{
  return _uuidToObjectVersionMaping;
}

- (NSDictionary *)properties
{
  return _properties;
}
- (void)setValue: (NSObject*)value forProperty: (NSString*)property
{
  [_properties setValue: value forKey: property];
}

@end

// FIXME: this code is a bit of a mess

static NSArray *ArrayWithUUIDsForUUIDStrings(NSArray *arr)
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
  for (NSString *str in arr)
  {
    [result addObject: [ETUUID UUIDWithString: str]];
  }
  return result;
}

static NSArray *ArrayWithUUIDStringsForUUIDs(NSArray *arr)
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
  for (ETUUID *uuid in arr)
  {
    [result addObject: [uuid stringValue]];
  }
  return result;
}

static NSArray *ArrayWithHexStringsForDatas(NSArray *arr)
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
  for (NSData *data in arr)
  {
    [result addObject: [data hexString]];
  }
  return result;
}

static NSArray *ArrayWithDatasForHexStrings(NSArray *arr)
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
  for (NSString *str in arr)
  {
    [result addObject: [NSData dataWithHexString: str]];
  }
  return result;
}

@implementation COHistoryGraphNode (Private)

- (id)       initWithUUID: (ETUUID*)uuid
         storeCoordinator: (COStoreCoordinator*)store
               properties: (NSDictionary*)properties
          parentNodeUUIDs: (NSArray*)parents
           childNodeUUIDs: (NSArray*)children
uuidToObjectVersionMaping: (NSDictionary*)mapping
{
  SUPERINIT;
  _uuid = [uuid retain];
  _store = store; // Weak reference
  _properties = [[NSMutableDictionary alloc] initWithDictionary: properties];
  _parentNodeUUIDs = [[NSMutableArray alloc] initWithArray: parents];
  _childNodeUUIDs = [[NSMutableArray alloc] initWithArray: children];
  _uuidToObjectVersionMaping = [[NSDictionary alloc] initWithDictionary: mapping];
  return self;
}

- (id) initWithPropertyList: (NSDictionary*)plist storeCoordinator: (COStoreCoordinator *)store
{
  // FIXME: ugly
  NSDictionary *mapping = [NSDictionary dictionaryWithObjects: ArrayWithDatasForHexStrings([[plist valueForKey: @"mapping"] allObjects])
                                                      forKeys: ArrayWithUUIDsForUUIDStrings([[plist valueForKey: @"mapping"] allKeys])];

  return [self initWithUUID: [ETUUID UUIDWithString: [plist valueForKey: @"uuid"]]
           storeCoordinator: store
                 properties: [plist valueForKey: @"properties"]
            parentNodeUUIDs: ArrayWithUUIDsForUUIDStrings([plist valueForKey: @"parentNodeUUIDs"])
             childNodeUUIDs: ArrayWithUUIDsForUUIDStrings([plist valueForKey: @"childNodeUUIDs"]) 
  uuidToObjectVersionMaping: mapping];
}

- (NSDictionary *)propertyList
{
  NSDictionary *mapping = [NSDictionary dictionaryWithObjects: ArrayWithHexStringsForDatas([_uuidToObjectVersionMaping allValues])
                                                      forKeys: ArrayWithUUIDStringsForUUIDs([_uuidToObjectVersionMaping allKeys])];
  return [NSDictionary dictionaryWithObjectsAndKeys:
    [_uuid stringValue], @"uuid",
    _properties, @"properties",
    ArrayWithUUIDStringsForUUIDs(_parentNodeUUIDs), @"parentNodeUUIDs",
    ArrayWithUUIDStringsForUUIDs(_childNodeUUIDs), @"childNodeUUIDs",
    mapping, @"mapping",
    nil];
}

- (ETUUID*)uuid
{
  return _uuid;
}

- (void) dealloc
{
  [_uuid release];
  [_properties release];
  [_parentNodeUUIDs release];
  [_childNodeUUIDs release];
  [_uuidToObjectVersionMaping release];
  [super dealloc];
}

- (void) addChildNodeUUID: (ETUUID*)child
{
  [_childNodeUUIDs addObject: child];
}

@end