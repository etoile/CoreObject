#import "COStoreCoordinator.h"
#import "COSerializer.h"
#import "NSData+sha1.h"

NSString * const COStoreDidCommitNotification = @"COStoreDidCommitNotification";

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

- (COHistoryNode *)tip
{
	NSString *uuidString = [COSerializer unserializeData: [_store dataForKey: @"tip"]];
	COHistoryNode *node = nil;
	if (uuidString != nil)
	{
		node = [self historyGraphNodeForUUID: [ETUUID UUIDWithString: uuidString]];
	}
	return node;
}

- (COHistoryNode *) createBranchOfNode: (COHistoryNode*)node
{
	COHistoryNode *newNode = [[[COHistoryNode alloc] initWithUUID: [ETUUID UUID]
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
- (COHistoryNode *) createMergeOfNode: (COHistoryNode*)node1 andNode: (COHistoryNode*)node2
{
	COHistoryNode *newNode = nil;
	
	return newNode;
}
- (COHistoryNode *) commitChangesInObjectContext: (COEditingContext *)ctx 
                                            afterNode: (COHistoryNode*)node
                                         withMetadata: (NSDictionary*)metadata
{
	return [self commitChangesInObjects: [ctx changedObjects] afterNode: node withMetadata: metadata];
}

- (COHistoryNode *) commitObjectDatas: (NSArray *)datas
								 afterNode: (COHistoryNode*)node
							  withMetadata: (NSDictionary*)metadata
					   withHistoryNodeUUID: (ETUUID*)uuid
{
	NSMutableDictionary *mapping = [NSMutableDictionary dictionaryWithCapacity: [datas count]];
	
	for (NSDictionary *data in datas)
	{
		NSData *hash = [data sha1Hash];
		
		[_store setData: [COSerializer serializeObject: data]
				 forKey: [hash hexString]];
		
		[mapping setObject: hash forKey: [ETUUID UUIDWithString: [data objectForKey: @"uuid"]]];
	}
	
	NSDictionary *meta = [NSMutableDictionary dictionaryWithDictionary: metadata];
	[meta setObject: [NSDate date] forKey: kCODateHistoryGraphNodeProperty];
	
	COHistoryNode *newNode = [[[COHistoryNode alloc] initWithUUID: uuid
														   storeCoordinator: self
																 properties: meta
															parentNodeUUIDs: node ? A([node uuid]) : nil
															 childNodeUUIDs: nil
												  uuidToObjectVersionMaping: mapping] autorelease];
	
	if (node)
	{
		[node addChildNodeUUID: [newNode uuid]];
		
		// FIXME: these next two lines should be atomic together
		[self commitHistoryGraphNode: node];
	}
	[self commitHistoryGraphNode: newNode];
	
	
	// Post notification
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [mapping allKeys], @"objectUUIDs",
							  [newNode uuid], @"commitUUID",
							  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName: COStoreDidCommitNotification
														object: self
													  userInfo: userInfo];
	
	return newNode;
}

- (COHistoryNode *) commitChangesInObjects: (NSArray *)objects 
                                      afterNode: (COHistoryNode*)node
								   withMetadata: (NSDictionary*)metadata
{
	return [self commitObjectDatas: [[objects mappedCollection] propertyList]
						 afterNode: node
					  withMetadata: metadata
			   withHistoryNodeUUID: [ETUUID UUID]];
}

@end

@implementation COStoreCoordinator (Private)

- (NSDictionary*) dataForObjectWithUUID: (ETUUID*)uuid atHistoryGraphNode: (COHistoryNode *)node
{
	// Find the node in which the given object UUID was last modified
	NSData *hash = nil;
	
	for ( ; node != nil; node = [node parent])
	{
		hash = [[node uuidToObjectVersionMaping] objectForKey: uuid];
		if (hash != nil)
		{
			break; 
		}
	}
	
	NSDictionary *data = [COSerializer unserializeData: [_store dataForKey: [hash hexString]]];
	if (nil == data)
	{
		NSLog(@"Object %@ data missing", uuid);
	}
	
	return data;
}

- (COHistoryNode *) historyGraphNodeForUUID: (ETUUID*)uuid
{
	assert([uuid isKindOfClass: [ETUUID class]]);
	COHistoryNode *node = [_historyGraphNodes objectForKey: uuid];
	if (nil == node)
	{
		NSDictionary *nodePlist = [COSerializer unserializeData: [_store dataForKey: [uuid stringValue]]];
		if (nodePlist)
		{
			node = [[[COHistoryNode alloc] initWithPropertyList: nodePlist storeCoordinator: self] autorelease];
			NSLog(@"Read history node %@", [node uuid]);
			[_historyGraphNodes setObject: node forKey: [node uuid]];
		}
		else
		{
			NSLog(@"WARNING: Requested node %@ not in store", uuid);
		}
	}
	
	return node;
}

- (void) commitHistoryGraphNode: (COHistoryNode *)node
{
	//FIXME: ugly
	[_historyGraphNodes setObject: node forKey: [node uuid]];
	
	[_store setData: [COSerializer serializeObject: [node propertyList]]
			 forKey: [[node uuid] stringValue]];
	
	{
		NSLog(@"Marking %@ as tip", node);
		[_store setData: [COSerializer serializeObject: [[node uuid] stringValue]]
				 forKey: @"tip"];
	}
	
	NSLog(@"History graph node %@ committed.", [node uuid]);
}

@end
