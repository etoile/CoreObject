#import "COEditingContext.h"

const NSString *COEditingContextBaseHistoryGraphNodeDidChangeNotification = @"COEditingContextBaseHistoryGraphNodeDidChangeNotification";

@implementation COEditingContext

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

- (id) initWithHistoryGraphNode: (COHistoryNode*)node
{
	self = [self initWithStoreCoordinator: [node storeCoordinator]];
	ASSIGN(_baseHistoryGraphNode, node);
	return self;
}

- (id) init
{
	return [self initWithHistoryGraphNode: nil];
}

- (void) dealloc
{
	DESTROY(_baseHistoryGraphNode);
	DESTROY(_storeCoordinator);
	DESTROY(_changedObjectUUIDs);
	DESTROY(_instantiatedObjects);
	[super dealloc];
}

- (void) commitWithMetadata: (NSDictionary*)metadata
{
	COHistoryNode *newNode = [[self storeCoordinator]
								   commitChangesInObjectContext: self
								   afterNode: [self baseHistoryGraphNode]
								   withMetadata: metadata];
	[_changedObjectUUIDs removeAllObjects];
	
	// We can use the unsafe variant because we know all objects are in the same state
	// as in the newly committed node
	[self setBaseHistoryGraphNodeUnsafe: newNode];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: COEditingContextBaseHistoryGraphNodeDidChangeNotification
														object: self
													  userInfo: newNode]; 
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

- (COHistoryNode *) baseHistoryGraphNode
{
	return _baseHistoryGraphNode;
}

/**
 * Sets the base history graph node, clears any uncommitted changes,
 * and reloads all instantiated objects.
 */
- (void) setBaseHistoryGraphNode: (COHistoryNode*)node
{
	ASSIGN(_baseHistoryGraphNode, node);
	
	if ([_changedObjectUUIDs count] != 0)
	{
		NSLog(@"WARNING: -[COEditingContext setBaseHistoryGraphNode] discarded some changes; probably indicates a bug");
		[_changedObjectUUIDs removeAllObjects];
	}
	
	// Reload all instantiated objects
	for (COObject *obj in [_instantiatedObjects allValues])
	{
		[self loadObject: obj withDataAtHistoryGraphNode: node];
	}
}

/**
 * Sets the base history graph node.
 */
- (void) setBaseHistoryGraphNodeUnsafe: (COHistoryNode*)node
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

- (void) loadObject: (COObject*)obj withDataAtHistoryGraphNode: (COHistoryNode*)node
{
	[obj unfaultWithData: [_storeCoordinator dataForObjectWithUUID: [obj uuid]
												atHistoryGraphNode: node]];
}

- (void) loadObjectWithDataAtBaseHistoryGraphNode: (COObject*)obj
{
	[self loadObject: obj withDataAtHistoryGraphNode: _baseHistoryGraphNode];
}

- (void) markObjectUUIDChanged: (ETUUID*)uuid
{
	[_changedObjectUUIDs addObject: uuid];
}
- (void) markObjectUUIDUnchanged: (ETUUID*)uuid
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

- (void) rollbackToRevision: (COHistoryNode *)node
{
	// FIXME: this is broken, it only reverts loaded objects
	
	[_changedObjectUUIDs removeAllObjects];
	
	for (COObject *obj in [_instantiatedObjects allValues])
	{
		[obj unfaultWithData: [[self storeCoordinator] dataForObjectWithUUID: [obj uuid]
														  atHistoryGraphNode: node]];
	}
	
	[_changedObjectUUIDs addObjectsFromArray: [_instantiatedObjects allKeys]];
}

- (void)selectiveUndoChangesMadeInRevision: (COHistoryNode *)ver
{
	NSLog(@"-[COEditingContext selectiveUndoChangesMadeInRevision: %@]", ver);
	
	COHistoryNode *priorToVer = [ver parent];
	if (priorToVer == nil)
	{
		NSLog(@"Can't undo first change");
		return;
	}
	
	NSLog(@"Using %@ as parent", priorToVer);
    
	COObjectGraphDiff *oa = [COObjectGraphDiff diffHistoryNode:ver  withHistoryNode: priorToVer];
	NSLog(@"!!!!OA %@", oa);
	
	COObjectGraphDiff *ob = [COObjectGraphDiff diffHistoryNode:ver withHistoryNode: [self baseHistoryGraphNode]];
	NSLog(@"!!!!OB %@", ob);
	
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
	NSLog(@"!!!!merged %@", merged);
	
	
	COHistoryNode *oldBaseNode = [self baseHistoryGraphNode];
	// The 'merged' diff we are going to apply is relative to 'ver', so we temporairly change
	[self setBaseHistoryGraphNode: ver];
	
	[merged applyToContext: self];
	
	[self setBaseHistoryGraphNodeUnsafe: oldBaseNode];
	
	NSLog(@"Changed objects after selective undo:");
	for (ETUUID *uuid in _changedObjectUUIDs)
	{
		COObject *obj = [self objectForUUID: uuid];
		NSLog(@"Obj %@", [obj detailedDescription]);
	}
	
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
	COHistoryNode *newNode = [[self storeCoordinator] commitChangesInObjects: objects
																		afterNode: [self baseHistoryGraphNode]];
	[self setBaseHistoryGraphNode: newNode];
}
- (void) rollbackObjects: (NSArray*)objects toRevision: (COHistoryNode *)ver
{
}
- (void) threeWayMergeObjects: (NSArray*)objects withObjects: (NSArray*)otherObjects bases: (NSArray*)bases
{
}
- (void) twoWayMergeObjects: (NSArray*)objects withObjects: (NSArray*)otherObjects
{
}
- (void) selectiveUndoChangesInObjects: (NSArray*)objects madeInRevision: (COHistoryNode *)ver
{
}



@end