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

- (COCommit *)tip
{
	NSString *uuidString = [COSerializer unserializeData: [_store dataForKey: @"tip"]];
	COCommit *node = nil;
	if (uuidString != nil)
	{
		node = [self historyGraphNodeForUUID: [ETUUID UUIDWithString: uuidString]];
	}
	return node;
}

- (COCommit *) createBranchOfNode: (COCommit*)node
{
	COCommit *newNode = [[[COCommit alloc] initWithUUID: [ETUUID UUID]
														   storeCoordinator: self
																 properties: nil
															parentNodeUUIDs: [NSArray arrayWithObject:node]
															 childNodeUUIDs: nil
												  uuidToObjectVersionMaping: nil] autorelease];
	[node addChildNodeUUID: [newNode commitUUID]];
	
	// FIXME: these should be atomic together
	[self commitHistoryGraphNode: node];
	[self commitHistoryGraphNode: newNode];
	return newNode;
}
- (COCommit *) createMergeOfNode: (COCommit*)node1 andNode: (COCommit*)node2
{
	COCommit *newNode = nil;
	
	return newNode;
}
- (COCommit *) commitChangesInObjectContext: (COEditingContext *)ctx 
                                            afterNode: (COCommit*)node
                                         withMetadata: (NSDictionary*)metadata
{
	return [self commitChangesInObjects: [ctx changedObjects] afterNode: node withMetadata: metadata];
}

- (COCommit *) commitObjectDatas: (NSArray *)datas
								 afterNode: (COCommit*)node
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
	
	COCommit *newNode = [[[COCommit alloc] initWithUUID: uuid
														   storeCoordinator: self
																 properties: meta
															parentNodeUUIDs: node ? A([node uuid]) : nil
															 childNodeUUIDs: nil
												  uuidToObjectVersionMaping: mapping] autorelease];
	
	if (node)
	{
		[node addChildNodeUUID: [newNode commitUUID]];
		
		// FIXME: these next two lines should be atomic together
		[self commitHistoryGraphNode: node];
	}
	[self commitHistoryGraphNode: newNode];
	
	
	// Post notification
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [mapping allKeys], @"objectUUIDs",
							  [newNode commitUUID], @"commitUUID",
							  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName: COStoreDidCommitNotification
														object: self
													  userInfo: userInfo];
	
	return newNode;
}

- (COCommit *) commitChangesInObjects: (NSArray *)objects 
                                      afterNode: (COCommit*)node
								   withMetadata: (NSDictionary*)metadata
{
	return [self commitObjectDatas: [[objects mappedCollection] propertyList]
						 afterNode: node
					  withMetadata: metadata
			   withHistoryNodeUUID: [ETUUID UUID]];
}

@end

@implementation COStoreCoordinator (Private)

- (NSDictionary*) dataForObjectWithUUID: (ETUUID*)uuid atCommit: (COCommit *)node
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

- (COCommit *) historyGraphNodeForUUID: (ETUUID*)uuid
{
	assert([uuid isKindOfClass: [ETUUID class]]);
	COCommit *node = [_historyGraphNodes objectForKey: uuid];
	if (nil == node)
	{
		NSDictionary *nodePlist = [COSerializer unserializeData: [_store dataForKey: [uuid stringValue]]];
		if (nodePlist)
		{
			node = [[[COCommit alloc] initWithPropertyList: nodePlist storeCoordinator: self] autorelease];
			NSLog(@"Read history node %@", [node commitUUID]);
			[_historyGraphNodes setObject: node forKey: [node commitUUID]];
		}
		else
		{
			NSLog(@"WARNING: Requested node %@ not in store", uuid);
		}
	}
	
	return node;
}

- (void) commitHistoryGraphNode: (COCommit *)node
{
	//FIXME: ugly
	[_historyGraphNodes setObject: node forKey: [node commitUUID]];
	
	[_store setData: [COSerializer serializeObject: [node propertyList]]
			 forKey: [[node commitUUID] stringValue]];
	
	{
		NSLog(@"Marking %@ as tip", node);
		[_store setData: [COSerializer serializeObject: [[node commitUUID] stringValue]]
				 forKey: @"tip"];
	}
	
	NSLog(@"History graph node %@ committed.", [node commitUUID]);
}

@end
