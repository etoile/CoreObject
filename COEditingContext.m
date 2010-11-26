#import "COEditingContext.h"
#import <EtoileFoundation/ETModelDescriptionRepository.h>

@implementation COEditingContext

+ (COEditingContext*)contextWithURL: (NSURL*)aURL
{
	COEditingContext *ctx = [[self alloc] initWithStore: [[[COStore alloc] initWithURL: aURL] autorelease]];
	return [ctx autorelease];
}

- (id) initWithStore: (COStore*)store
{
	SUPERINIT;
	
	ASSIGN(_store, store);
	
	_damagedObjectUUIDs = [[NSMutableSet alloc] init];
	_instantiatedObjects = [[NSMutableDictionary alloc] init];
	_commitUUIDForObject = [[NSMutableDictionary alloc] init];
	_modelRepository = [[ETModelDescriptionRepository mainRepository] retain];
	
	_tipNodeForObjectUUIDOnBranchWithUUID = [[NSMutableDictionary alloc] init];
	_currentNodeForObjectUUIDOnBranchWithUUID = [[NSMutableDictionary alloc] init];
	_currentBranchForObjectUUID = [[NSMutableDictionary alloc] init];
	_insertedObjectUUIDs = [[NSMutableSet alloc] init];
	_deletedObjectUUIDs = [[NSMutableSet alloc] init];
	
	return self;
}
- (COStore*)store
{
	return _store;
}

- (void) dealloc
{
	DESTROY(_store);
	DESTROY(_damagedObjectUUIDs);
	DESTROY(_instantiatedObjects);
	DESTROY(_commitUUIDForObject);
	DESTROY(_modelRepository);
	
	DESTROY(_tipNodeForObjectUUIDOnBranchWithUUID);
	DESTROY(_currentNodeForObjectUUIDOnBranchWithUUID);
	DESTROY(_currentBranchForObjectUUID);
	DESTROY(_insertedObjectUUIDs);
	DESTROY(_deletedObjectUUIDs);
	[super dealloc];
}

// Accessors

- (ETModelDescriptionRepository*) modelRepository
{
	return _modelRepository; 
}


- (BOOL) hasChanges
{
	return ![_damagedObjectUUIDs isEmpty];
}

- (BOOL) objectHasChanges: (ETUUID*)uuid
{
	return [_damagedObjectUUIDs containsObject: uuid];
}
- (NSSet*) changedObjectUUIDs
{
	return [NSSet setWithSet: _damagedObjectUUIDs];
}

// Creating and accessing objects

- (Class) classForEntityDescription: (ETEntityDescription*)desc
{
	Class cls = [_modelRepository classForEntityDescription: desc];
	if (cls == Nil)
	{
		cls = [COObject class];
	}
	return cls;
}

- (COObject*) insertObjectWithEntityName: (NSString*)aFullName
{
	COObject *result = nil;
	ETEntityDescription *desc = [_modelRepository descriptionForName: aFullName];
	if (desc != nil)
	{
		ETUUID *uuid = [[ETUUID alloc] init];
		Class cls = [self classForEntityDescription: desc];
		result = [[cls alloc] initWithUUID: uuid
						 entityDescription: desc
								   context: self
								   isFault: NO];
		[_instantiatedObjects setObject: result forKey: uuid];
		[_insertedObjectUUIDs addObject: uuid];
		[result release];
		[uuid release];
	}
	return result;
}

- (COObject*) objectWithUUID: (ETUUID*)uuid
{
	return [self objectWithUUID: uuid entityName: nil];
}


// FIXME: implement
/*
- (COObject*) insertObject: (COObject*)obj
{
	
	ETUUID *uuid = [obj UUID];
	[_instantiatedObjects objectForKey: 
	 
	 id copy = [[[self class] alloc] initWithModelDescription: _description 
													  context: ctx
														 uuid: _uuid
														isNew: YES];
	 [_ctx recordObject: copy forUUID: [self UUID]];
	 return copy;
	 }

	return nil;
}
*/

- (void) deleteObjectWithUUID: (ETUUID*)uuid
{
	[_deletedObjectUUIDs addObject: uuid];
	[_instantiatedObjects removeObjectForKey: uuid];
}




// Committing changes

- (void) commit
{
	[self commitWithType: nil shortDescription: nil longDescription: nil];
}
- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription
{
	for (ETUUID *uuid in _insertedObjectUUIDs)
	{
		NSString *name = [[[self objectWithUUID: uuid] entityDescription] fullName];
		//NSLog(@"Storing entity name %@ for %@", name, uuid);
		[_store setEntityName: name
				forObjectUUID: uuid];
	}
	
	[_store beginCommitWithMetadata: nil];
	for (ETUUID *uuid in _damagedObjectUUIDs)
	{
		COCommit *parentCommit = [_store commitForUUID: [_store currentCommitForObjectUUID: uuid onBranch: nil]];
		
		[_store beginChangesForObject: uuid
				   onNamedBranch: nil
			   updateObjectState: YES
					parentCommit: parentCommit
					mergedCommit: nil];
		COObject *obj = [self objectWithUUID: uuid];
		//NSLog(@"Committing changes for %@", obj);
		for (NSString *prop in [obj properties])
		{
			id value = [obj valueForProperty: prop];
			id plist = [obj propertyListForValue: value];
			
			[_store setValue: plist
			 forProperty: prop
			 ofObject: uuid
			 shouldIndex: NO];
		}
		
		[_store finishChangesForObject: uuid];
	}
	
	COCommit *c = [_store finishCommit];
	assert(c != nil);
	
	[_insertedObjectUUIDs removeAllObjects];
	for (ETUUID *uuid in [NSArray arrayWithArray: _damagedObjectUUIDs])
	{
		[self markObjectUndamaged: [self objectWithUUID: uuid]];
	}
}

@end

 
@implementation COEditingContext (PrivateToCOObject)
 
- (void) markObjectDamaged: (COObject*)obj
{
	[obj setDamaged: YES];
	[_damagedObjectUUIDs addObject: [obj UUID]]; 
}
- (void) markObjectUndamaged: (COObject*)obj
{
	[obj setDamaged: NO]; 
	[_damagedObjectUUIDs removeObject: [obj UUID]];
}
 
- (void) loadObject: (COObject*)obj
{
	[self loadObject: obj atCommit: nil];
}

- (void)loadObject: (COObject*)obj atCommit: (COCommit*)aCommit
{
	ETUUID *objUUID = [obj UUID];
	if (aCommit == nil)
	{
		ETUUID *commitUUID = [_commitUUIDForObject objectForKey: objUUID];
		aCommit = [_store commitForUUID: commitUUID];
		if (aCommit == nil)
		{
			commitUUID = [_store currentCommitForObjectUUID: objUUID onBranch: [_store activeBranchForObjectUUID: objUUID]];
			aCommit = [_store commitForUUID: commitUUID];
		}
	}
	
	if (aCommit == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Object %@ not found in store", obj];
	}
	
	NSMutableSet *propertiesToFetch = [NSMutableSet setWithArray: [obj properties]];
	//NSLog(@"Properties to fetch: %@", propertiesToFetch);
	
	obj->_isIgnoringDamageNotifications = YES;
	
	while ([propertiesToFetch count] > 0)
	{
		if (aCommit == nil)
		{
			[NSException raise: NSInternalInconsistencyException format: @"Store is missing properties %@ for %@", propertiesToFetch, obj];
		}
		
		NSDictionary *dict = [aCommit valuesAndPropertiesForObject: objUUID];
		
		for (NSString *key in [dict allKeys])
		{
			id plist = [dict objectForKey: key];
			id value = [obj valueForPropertyList: plist];
			//NSLog(@"key %@, unparsed %@, parsed %@", key, plist, value);
			[obj setValue: value
			  forProperty: key];
			[propertiesToFetch removeObject: key];
		}
		
		aCommit = [aCommit parentCommitForObject: objUUID];
	}
	
	obj->_isFault = NO;
	[self markObjectUndamaged: obj];
	obj->_isIgnoringDamageNotifications = NO;
}

- (COObject*) objectWithUUID: (ETUUID*)uuid entityName: (NSString*)name
{
	COObject *result = [_instantiatedObjects objectForKey: uuid];
	
	if (result == nil)
	{
		ETEntityDescription *desc = [_modelRepository descriptionForName: name];
		if (desc == nil)
		{
			NSString *name = [_store entityNameForObjectUUID: uuid];
			if (name == nil)
			{
				//[NSException raise: NSGenericException format: @"Failed to find an entity name for %@", uuid];
				NSLog(@"WARNING: -[COEditingContext objectWithUUID:entityName:] failed to find an entity name for %@ (probably, the requested object does not exist)", uuid);
				return nil;
			}
			desc = [_modelRepository descriptionForName: name];
		}
		
		Class cls = [self classForEntityDescription: desc];
		result = [[cls alloc] initWithUUID: uuid
						 entityDescription: desc
								   context: self
								   isFault: YES];
		
		[_instantiatedObjects setObject: result forKey: uuid];
		[result release];
	}
	
	return result;
}

@end


// FIXME:
@implementation COEditingContext (PrivateToCOHistoryTrack)

- (ETUUID*) namedBranchForObjectUUID: (ETUUID*)obj
{
	id branch = [_currentBranchForObjectUUID objectForKey: obj];
	if (branch == [NSNull null]) { branch = nil; }
	return branch;
}
- (void) setNamedBranch: (ETUUID*)branch forObjectUUID: (ETUUID*)obj
{
	if (branch == nil) { branch = [NSNull null]; }
	[_currentBranchForObjectUUID setObject:branch forKey: obj];
}

- (ETUUID*)currentCommitForObjectUUID: (ETUUID*)object
{
	// FIXME: Quick hack for testing
	return [_store currentCommitForObjectUUID: object onBranch: nil];
}
- (void) setCurrentCommit: (ETUUID*)commit forObjectUUID: (ETUUID*)object
{
	// FIXME: Quick hack for testing
	[_store setCurrentCommit: commit forObjectUUID: object onBranch: nil];
	[self loadObject: [self objectWithUUID: object] atCommit: commit];
}

- (ETUUID*)currentCommitForObjectUUID: (ETUUID*)object onBranch: (ETUUID*)branch
{
	if (branch == nil) { branch = [NSNull null]; }
	//return [[_currentNodeForObjectUUIDOnBranchWithUUID objectForKey: object] objectForKey: branch];
	return nil;
}
- (void) setCurrentCommit: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch
{
	if (branch == nil) { branch = [NSNull null]; }
}

- (ETUUID*)tipForObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch
{
	if (branch == nil) { branch = [NSNull null]; }
	return nil;
}
- (void) setTip: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch
{
	if (branch == nil) { branch = [NSNull null]; }
	return nil;	
}

@end



@implementation COEditingContext (Rollback)

- (void) discardAllChanges
{
	for (COObject *object in [_instantiatedObjects allValues])
	{
		[self discardAllChangesInObject: object];
	}
	assert([self hasChanges] == NO);
}

- (void) discardAllChangesInObject: (COObject*)object
{
	// FIXME: is this what we want?
	
	// Special case for objects which haven't yet been comitted
	if ([_insertedObjectUUIDs containsObject: [object UUID]])
	{
		[self markObjectUndamaged: object];
		[_insertedObjectUUIDs removeObject: [object UUID]];
		[_instantiatedObjects removeObjectForKey: [object UUID]];
		// lingering instances may be in a 'zombie' state now... not sure how to solve that problem
	}
	else
	{
		[self loadObject: object];
	}
}

/*

- (void) rollbackToRevision: (COHistoryNode *)node
{
	// FIXME: this is broken, it only reverts loaded objects
	
	[_damagedObjectUUIDs removeAllObjects];
	
	for (COObject *object in [_instantiatedObjects allValues])
	{
		[self loadObject: object withDataAtHistoryGraphNode: node];
	}
	
	[_damagedObjectUUIDs addObjectsFromArray: [_instantiatedObjects allKeys]];
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
	
	COObjectGraphDiff *oa = [COObjectGraphDiff diffHistoryNode: ver
											   withHistoryNode: priorToVer];
	NSLog(@"!!!!OA %@", oa);
	
	COObjectGraphDiff *ob = [COObjectGraphDiff diffHistoryNode: ver
											   withHistoryNode: _baseHistoryGraphNode];
	NSLog(@"!!!!OB %@", ob);
	
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
	NSLog(@"!!!!merged %@", merged);
	
	
	COHistoryNode *oldBaseNode = [self baseHistoryGraphNode];
	// The 'merged' diff we are going to apply is relative to 'ver', so we ; change
	[self setBaseHistoryGraphNode: ver];
	
	[merged applyToContext: self];
	
	[self setBaseHistoryGraphNodeUnsafe: oldBaseNode];
	
	NSLog(@"Changed objects after selective undo:");
	for (ETUUID *uuid in _damagedObjectUUIDs)
	{
		COObject *obj = [self objectWithUUID: uuid];
		NSLog(@"Obj %@", [obj detailedDescription]);
	}
	
}
*/

@end
