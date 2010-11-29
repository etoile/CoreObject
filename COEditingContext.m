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
	_modelRepository = [[ETModelDescriptionRepository mainRepository] retain];
	
	_insertedObjectUUIDs = [[NSMutableSet alloc] init];
	_deletedObjectUUIDs = [[NSMutableSet alloc] init];
	
	return self;
}

- (id) init
{
	return [self initWithStore: nil];
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
	DESTROY(_modelRepository);
	
	DESTROY(_insertedObjectUUIDs);
	DESTROY(_deletedObjectUUIDs);
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	id copy = [[COEditingContext alloc] initWithStore: _store];
	// FIXME:
	return copy;
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

- (COObject*) insertObjectWithEntityName: (NSString*)aFullName UUID: (ETUUID*)aUUID
{
	COObject *result = nil;
	ETEntityDescription *desc = [_modelRepository descriptionForName: aFullName];
	if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	
	Class cls = [self classForEntityDescription: desc];
	result = [[cls alloc] initWithUUID: aUUID
					 entityDescription: desc
							   context: self
							   isFault: NO];
	[_instantiatedObjects setObject: result forKey: aUUID];
	[_insertedObjectUUIDs addObject: aUUID];
	[result release];
	
	return result;
}

- (COObject*) insertObjectWithEntityName: (NSString*)aFullName
{
	return [self insertObjectWithEntityName:aFullName UUID: [ETUUID UUID]];
}

- (COObject*) objectWithUUID: (ETUUID*)uuid
{
	return [self objectWithUUID: uuid entityName: nil];
}


/**
 * Helper method for -insertObject:
 */
static id handle(id value, COEditingContext *ctx, ETPropertyDescription *desc, BOOL sharedStore)
{
	if ([value isKindOfClass: [NSArray class]])
	{
		NSMutableArray *copy = [NSMutableArray array];
		for (id subvalue in value)
		{
			id subvaluecopy = handle(subvalue, ctx, desc, sharedStore);
			if (nil == subvaluecopy)
			{
				NSLog(@"error");
			}
			[copy addObject: subvaluecopy];
		}
		return copy;
	}
	else if ([value isKindOfClass: [NSSet class]])
	{
		NSMutableSet *copy = [NSMutableSet set];
		for (id subvalue in value)
		{
			id subvaluecopy = handle(subvalue, ctx, desc, sharedStore);
			if (nil == subvaluecopy)
			{
				NSLog(@"error");
			}
			[copy addObject: subvaluecopy];			
		}		
		return copy;
	}
	else if ([value isKindOfClass: [COObject class]])
	{
		if ([desc isComposite])
		{
			return [ctx insertObject: value];
		}
		else
		{
			COObject *copy = [ctx objectWithUUID: [value UUID]];
			return copy;
		}
	}
	else
	{
		return [[value mutableCopy] autorelease];
	}
}

- (id) insertObject: (COObject*)sourceObject withRelationshipConsistency: (BOOL)consistency
{
	COEditingContext *sourceContext = [sourceObject editingContext];
	NSString *entityName = [[sourceObject entityDescription] fullName];
	assert(entityName != nil);
	
	COObject *copy = [self objectWithUUID: [sourceObject UUID]];

	if (copy == nil)
	{
		copy = [self insertObjectWithEntityName: entityName UUID: [sourceObject UUID]];
	}
	
	BOOL sharedStore = (_store == [sourceContext store]);
	
	if (!consistency)
	{
		assert(![copy isIgnoringRelationshipConsistency]);
		[copy setIgnoringRelationshipConsistency: YES];
	}
	
	for (NSString *prop in [sourceObject properties])
	{
		ETPropertyDescription *desc = [[sourceObject entityDescription] propertyDescriptionForName: prop];
		
		id value = [sourceObject valueForProperty: prop];
		id valueCopy = handle(value, self, desc, sharedStore);
		
		[copy setValue: valueCopy forProperty: prop];
	}

	if (!consistency)
	{
		[copy setIgnoringRelationshipConsistency: NO];
	}
	
	return copy;
}

- (id) insertObject: (COObject*)sourceObject
{
	return [self insertObject: sourceObject withRelationshipConsistency: YES];
}

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
	[_store beginCommitWithMetadata: nil];
	for (ETUUID *uuid in _damagedObjectUUIDs)
	{		
		[_store beginChangesForObject: uuid];
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
		
		// FIXME: Hack
		NSString *name = [[[self objectWithUUID: uuid] entityDescription] fullName];
		[_store setValue: name
			 forProperty: @"_entity"
				ofObject: uuid
			 shouldIndex: NO];
		
		[_store finishChangesForObject: uuid];
	}
	
	CORevision *c = [_store finishCommit];
	assert(c != nil);
	
	[_insertedObjectUUIDs removeAllObjects];
	for (ETUUID *uuid in [_damagedObjectUUIDs allObjects])
	{
		[self markObjectUndamaged: [self objectWithUUID: uuid]];
	}
}

@end

 
@implementation COEditingContext (PrivateToCOObject)
 
- (void) markObjectDamaged: (COObject*)obj
{
	[_damagedObjectUUIDs addObject: [obj UUID]]; 
}
- (void) markObjectUndamaged: (COObject*)obj
{
	[_damagedObjectUUIDs removeObject: [obj UUID]];
}
 
- (void) loadObject: (COObject*)obj
{
	[self loadObject: obj atRevision: nil];
}

- (NSString*)entityNameForObjectUUID: (ETUUID*)obj
{
	for (uint64_t revNum = [_store latestRevisionNumber]; revNum > 0; revNum--)
	{
		CORevision *revision = [_store revisionWithRevisionNumber: revNum];
		NSString *name = [[revision valuesAndPropertiesForObject: obj] objectForKey: @"_entity"];
		if (name != nil)
		{
			return name;
		}
	}
	return nil;
}

// FIXME: Probably need to turn off relationship consistency around loading.
- (void)loadObject: (COObject*)obj atRevision: (CORevision*)aRevision
{
	ETUUID *objUUID = [obj UUID];

	NSMutableSet *propertiesToFetch = [NSMutableSet setWithArray: [obj properties]];
	//NSLog(@"Properties to fetch: %@", propertiesToFetch);
	
	obj->_isIgnoringDamageNotifications = YES;
	[obj setIgnoringRelationshipConsistency: YES];
	
	uint64_t revNum;
	if (aRevision == nil)
	{
		revNum = [_store latestRevisionNumber];
	}
	else
	{
		revNum = [aRevision revisionNumber];
	}

	
	while ([propertiesToFetch count] > 0)
	{
		CORevision *revision = [_store revisionWithRevisionNumber: revNum];
		if (revision == nil)
		{
			[NSException raise: NSInternalInconsistencyException format: @"Store is missing properties %@ for %@", propertiesToFetch, obj];
		}
		
		NSDictionary *dict = [revision valuesAndPropertiesForObject: objUUID];
		
		for (NSString *key in [dict allKeys])
		{
			if ([propertiesToFetch containsObject: key])
			{
				id plist = [dict objectForKey: key];
				id value = [obj valueForPropertyList: plist];
				//NSLog(@"key %@, unparsed %@, parsed %@", key, plist, value);
				[obj setValue: value
				  forProperty: key];
				[propertiesToFetch removeObject: key];
			}
		}
		
		revNum--;
	}
	
	obj->_isFault = NO;
	[self markObjectUndamaged: obj];
	obj->_isIgnoringDamageNotifications = NO;
	[obj setIgnoringRelationshipConsistency: NO];	
}

- (COObject*) objectWithUUID: (ETUUID*)uuid entityName: (NSString*)name
{
	COObject *result = [_instantiatedObjects objectForKey: uuid];
	
	if (result == nil)
	{
		ETEntityDescription *desc = [_modelRepository descriptionForName: name];
		if (desc == nil)
		{
			NSString *name = [self entityNameForObjectUUID: uuid];
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
