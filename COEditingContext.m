#import "COEditingContext.h"
#import "COObject.h"
#import "COStore.h"
#import "CORevision.h"

@implementation COEditingContext

+ (COEditingContext*)contextWithURL: (NSURL*)aURL
{
	COEditingContext *ctx = [[self alloc] initWithStore: [[[COStore alloc] initWithURL: aURL] autorelease]];
	return [ctx autorelease];
}

static COEditingContext *currentCtxt = nil;

+ (COEditingContext *) currentContext
{
	return currentCtxt;
}

+ (void) setCurrentContext: (COEditingContext *)aCtxt
{
	ASSIGN(currentCtxt, aCtxt);
}

- (id) initWithStore: (COStore*)store revision: (CORevision*)aRevision
{
	SUPERINIT;

	ASSIGN(_store, store);
	ASSIGN(_revision, aRevision);
	
	_damagedObjectUUIDs = [[NSMutableDictionary alloc] init];
	_instantiatedObjects = [[NSMutableDictionary alloc] init];
	_modelRepository = [[ETModelDescriptionRepository mainRepository] retain];
	assert([[[_modelRepository descriptionForName: @"Anonymous.COContainer"] 
		propertyDescriptionForName: @"contents"] isComposite]);
	assert([[[[_modelRepository descriptionForName: @"Anonymous.COCollection"] 
		parent] name] isEqual: @"COObject"]);
	
	_insertedObjectUUIDs = [[NSMutableSet alloc] init];
	_deletedObjectUUIDs = [[NSMutableSet alloc] init];
	
	return self;
}

- (id) initWithStore: (COStore*)store
{
	return [self initWithStore: store revision: nil];
}

- (id)initWithRevision: (CORevision*)aRevision
{
	return [self initWithStore: [aRevision store] revision: aRevision];
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
	DESTROY(_revision);
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

- (NSSet *) loadedObjects
{
	return [NSSet setWithArray: [_instantiatedObjects allValues]];
}

- (BOOL) hasChanges
{
	return ([_damagedObjectUUIDs count] > 0 
		|| [_insertedObjectUUIDs count] > 0 
		|| [_deletedObjectUUIDs count] > 0);
}

- (BOOL) objectHasChanges: (ETUUID*)uuid
{
	return [_damagedObjectUUIDs objectForKey: uuid] != nil;
}
- (NSSet*) changedObjectUUIDs
{
	return [NSSet setWithArray: [_damagedObjectUUIDs allKeys]];
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

- (void) registerObject: (COObject *)object
{
	[_instantiatedObjects setObject: object forKey: [object UUID]];
	[_insertedObjectUUIDs addObject: [object UUID]];
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
	/* Nil root object means the new object will be a root */
	result = [[cls alloc] initWithUUID: aUUID
					 entityDescription: desc
	                        rootObject: nil
							   context: self
							   isFault: NO];
	[self registerObject: result];
	[result release];
	
	return result;
}

- (COObject *) insertObjectWithClass: (Class)aClass
{
	return [self insertObjectWithEntityName: [[_modelRepository entityDescriptionForClass: aClass] fullName]];
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
static id handle(id value, COEditingContext *ctx, ETPropertyDescription *desc, BOOL consistency, BOOL newUUID)
{
	if ([value isKindOfClass: [NSArray class]])
	{
		NSMutableArray *copy = [NSMutableArray array];
		for (id subvalue in value)
		{
			id subvaluecopy = handle(subvalue, ctx, desc, consistency, newUUID);
			if (nil == subvaluecopy)
			{
				//NSLog(@"error");
			}
			else
			{
				[copy addObject: subvaluecopy];
			}
		}
		return copy;
	}
	else if ([value isKindOfClass: [NSSet class]])
	{
		NSMutableSet *copy = [NSMutableSet set];
		for (id subvalue in value)
		{
			id subvaluecopy = handle(subvalue, ctx, desc, consistency, newUUID);
			if (nil == subvaluecopy)
			{
				//NSLog(@"error");
			}
			else
			{
				[copy addObject: subvaluecopy];	
			}
		}		
		return copy;
	}
	else if ([value isKindOfClass: [COObject class]])
	{
		if ([desc isComposite])
		{
			return [ctx insertObject: value withRelationshipConsistency: consistency newUUID: newUUID];
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

- (id) insertObject: (COObject*)sourceObject withRelationshipConsistency: (BOOL)consistency  newUUID: (BOOL)newUUID
{
	COEditingContext *sourceContext = [sourceObject editingContext];
	ETAssert(sourceContext != nil);
	/* See -[COObject becomePersistentInContext:rootObject:] */
	BOOL isBecomingPersistent = (newUUID == NO && sourceContext == self);

	/* Source object was not persistent until then
	   
	   So we don't want to create a new instance, but just register it */

	if (isBecomingPersistent)
	{
		[self registerObject: sourceObject];
		return sourceObject;
	}

	/* Source Object is already persistent
	
	   So we create a persistent object alias or copy in the receiver context */

	NSString *entityName = [[sourceObject entityDescription] fullName];
	assert(entityName != nil);
	
	COObject *copy;
	
	if (!newUUID)
	{	
		copy = [self objectWithUUID: [sourceObject UUID]];

		if (copy == nil)
		{
			copy = [self insertObjectWithEntityName: entityName UUID: [sourceObject UUID]];
		}
	}
	else
	{
		copy = [self insertObjectWithEntityName: entityName UUID: [ETUUID UUID]];
	}

	if (!consistency)
	{
		assert(![copy isIgnoringRelationshipConsistency]);
		[copy setIgnoringRelationshipConsistency: YES];
	}

	// FIXME: Copy transient properties if needed
	for (NSString *prop in [sourceObject persistentPropertyNames])
	{
		ETPropertyDescription *desc = [[sourceObject entityDescription] propertyDescriptionForName: prop];
		
		id value = [sourceObject valueForProperty: prop];
		id valueCopy = handle(value, self, desc, consistency, newUUID);
		
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
	return [self insertObject: sourceObject withRelationshipConsistency: YES newUUID: NO];
}

- (id) insertObjectCopy: (COObject*)sourceObject
{
	return [self insertObject: sourceObject withRelationshipConsistency: YES newUUID: YES];
}

- (void) deleteObjectWithUUID: (ETUUID*)uuid
{
	[_deletedObjectUUIDs addObject: uuid];
	[_instantiatedObjects removeObjectForKey: uuid];
}




// Committing changes

- (NSMapTable *) UUIDsByRootObjectFromObjectUUIDs: (id <ETCollection>)objectUUIDs
{
	NSMapTable *UUIDsByRootObject = [NSMapTable mapTableWithStrongToStrongObjects];

	FOREACH(objectUUIDs, uuid, ETUUID*)
	{
		COObject *object = [self objectWithUUID: uuid];
		COObject *rootObject = [object rootObject];
		NSMutableSet *UUIDs = [UUIDsByRootObject objectForKey: rootObject];

		if (UUIDs == nil)
		{
			UUIDs = [NSMutableSet set];
			[UUIDsByRootObject setObject: UUIDs forKey: rootObject];
		}
		[UUIDs addObject: uuid];
	}

	return UUIDsByRootObject;
}

- (NSMapTable *) insertedObjectUUIDsByRootObject
{
	return [self UUIDsByRootObjectFromObjectUUIDs: _insertedObjectUUIDs];
}

- (NSMapTable *) damagedObjectUUIDsByRootObject
{
	return [self UUIDsByRootObjectFromObjectUUIDs: [_damagedObjectUUIDs allKeys]];
}

- (void) commit
{
	[self commitWithType: nil shortDescription: nil longDescription: nil];
}

- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription
{
	[self commitWithMetadata: nil];
}

- (NSDictionary *) damagedObjectUUIDSubsetForUUIDs: (NSArray *)keys
{
	NSMutableDictionary *subset = [NSMutableDictionary dictionary];

	for (ETUUID *uuid in _damagedObjectUUIDs)
	{
		if ([keys containsObject: uuid] == NO)
			continue;

		[subset setObject: [_damagedObjectUUIDs objectForKey: uuid] 
		           forKey: uuid];
	}

	return subset;
}

- (void) commitWithMetadata: (NSDictionary *)metadata 
                 rootObject: (COObject *)rootObject
        insertedObjectUUIDs: (NSSet *)insertedObjectUUIDs
         damagedObjectUUIDs: (NSDictionary *)damagedObjectUUIDs
{
	NSParameterAssert(rootObject != nil);
	NSParameterAssert(insertedObjectUUIDs != nil);
	NSParameterAssert(damagedObjectUUIDs != nil);
	// TODO: ETAssert([rootObject isRoot]);
	// TODO: We should add the deleted object UUIDs to the set below
	NSSet *committedObjectUUIDs = 
		[insertedObjectUUIDs setByAddingObjectsFromArray: [damagedObjectUUIDs allKeys]];

	[_store beginCommitWithMetadata: metadata 
	                 rootObjectUUID: [rootObject UUID]];

	for (ETUUID *uuid in committedObjectUUIDs)
	{		
		[_store beginChangesForObjectUUID: uuid];

		COObject *obj = [self objectWithUUID: uuid];
		NSArray *persistentProperties = [obj persistentPropertyNames];
		id <ETCollection> propertiesToCommit = nil;

		//NSLog(@"Committing changes for %@", obj);

		if ([insertedObjectUUIDs containsObject: uuid])
		{
			// for the first commit, commit all property values
			propertiesToCommit = persistentProperties;
			ETAssert([_insertedObjectUUIDs containsObject: uuid]);
		}
		else
		{
			// otherwise just damaged values
			NSArray *damagedProperties = [damagedObjectUUIDs objectForKey: uuid];

			propertiesToCommit = [NSMutableSet setWithArray: damagedProperties];
			[(NSMutableSet *)propertiesToCommit intersectSet: [NSSet setWithArray: persistentProperties]];
			ETAssert([_insertedObjectUUIDs containsObject: uuid] == NO);
		}

		FOREACH(propertiesToCommit, prop, NSString*)
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
		
		[_store finishChangesForObjectUUID: uuid];
	}
	
	CORevision *rev = [_store finishCommit];
	assert(rev != nil);
	
	[_insertedObjectUUIDs minusSet: insertedObjectUUIDs];
	for (ETUUID *uuid in [damagedObjectUUIDs allKeys])
	{
		[self markObjectUndamaged: [self objectWithUUID: uuid]];
	}
}

- (void) commitWithMetadata: (NSDictionary*)metadata
{
	NSMapTable *insertedObjectUUIDs = [self insertedObjectUUIDsByRootObject];
	NSMapTable *damagedObjectUUIDs = [self damagedObjectUUIDsByRootObject];
	NSSet *rootObjects = [NSSet setWithArray: [[[insertedObjectUUIDs keyEnumerator] allObjects] 
		arrayByAddingObjectsFromArray: [[damagedObjectUUIDs keyEnumerator] allObjects]]];

	NSMutableSet *insertedRootObjectUUIDs = [NSMutableSet setWithSet: _insertedObjectUUIDs];
	[insertedRootObjectUUIDs intersectSet: (id)[[rootObjects mappedCollection] UUID]];
	[_store insertRootObjectUUIDs: insertedRootObjectUUIDs];

	// TODO: Add a batch commit UUID in the metadata
	for (COObject *rootObject in rootObjects)
	{
		NSSet *insertedObjectSubset = [insertedObjectUUIDs objectForKey: rootObject];
		NSDictionary *damagedObjectUUIDSubset = [self damagedObjectUUIDSubsetForUUIDs: 
			[damagedObjectUUIDs objectForKey: rootObject]];

		[self commitWithMetadata: metadata
		              rootObject: rootObject
		     insertedObjectUUIDs: (insertedObjectSubset != nil ? insertedObjectSubset : [NSSet set])
		      damagedObjectUUIDs: damagedObjectUUIDSubset];
	}
}

/*- (void) commitWithMetadata: (NSDictionary*)metadata
{
		[self commitWithMetadata: metadata
		              rootObject: nil
		     insertedObjectUUIDs: _insertedObjectUUIDs
		      damagedObjectUUIDs: _damagedObjectUUIDs];
}*/

// Private

- (uint64_t)currentRevisionNumber
{
	if (_revision == nil)
	{
		if (_store == nil)
		{
			return 0;
		}
		else 
		{
			return [_store latestRevisionNumber];
		}
	}
	else
	{
		return [_revision revisionNumber];
	}
}

@end

 
@implementation COEditingContext (PrivateToCOObject)
 
- (void) markObjectDamaged: (COObject*)obj forProperty: (NSString*)aProperty
{
	if (nil == [_damagedObjectUUIDs objectForKey: [obj UUID]])
	{
		[_damagedObjectUUIDs setObject: [NSMutableArray array] forKey: [obj UUID]];
	}
	if (aProperty != nil)
	{
		assert([aProperty isKindOfClass: [NSString class]]);
		[[_damagedObjectUUIDs objectForKey: [obj UUID]] addObject: aProperty]; 
	}
}
- (void) markObjectUndamaged: (COObject*)obj
{
	if (obj != nil)// FIXME: hack
	[_damagedObjectUUIDs removeObjectForKey: [obj UUID]];
}
 
- (void) loadObject: (COObject*)obj
{
	[self loadObject: obj atRevision: nil];
}

- (NSString*)entityNameForObjectUUID: (ETUUID*)obj
{
	for (uint64_t revNum = [self currentRevisionNumber]; revNum > 0; revNum--)
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

	NSMutableSet *propertiesToFetch = [NSMutableSet setWithArray: [obj persistentPropertyNames]];
	//NSLog(@"Properties to fetch: %@", propertiesToFetch);
	
	obj->_isIgnoringDamageNotifications = YES;
	[obj setIgnoringRelationshipConsistency: YES];

	uint64_t revNum;
	if (aRevision == nil)
	{
		revNum = [self currentRevisionNumber];
	}
	else
	{
		revNum = [aRevision revisionNumber];
	}

	//NSLog(@"Load object %@ at %i", objUUID, (int)revNum);
	
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
				[obj setValue: value forProperty: key];
				[propertiesToFetch removeObject: key];
			}
		}
		
		revNum--;
	}
	
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
				//NSLog(@"WARNING: -[COEditingContext objectWithUUID:entityName:] failed to find an entity name for %@ (probably, the requested object does not exist)", uuid);
				return nil;
			}
			desc = [_modelRepository descriptionForName: name];
		}
		
		// NOTE: We could resolve the root object at loading time, but since 
		// it's going to should be available in memory, we rather resolve it now.
		ETUUID *rootUUID = [_store rootObjectUUIDForUUID: uuid];
		ETAssert(rootUUID != nil);
		BOOL isRoot = [rootUUID isEqual: uuid];
		id rootObject = nil;

		if (!isRoot)
		{
			rootObject = [self objectWithUUID: rootUUID entityName: nil];
		}

		Class cls = [self classForEntityDescription: desc];
		result = [[cls alloc] initWithUUID: uuid
						 entityDescription: desc
	                            rootObject: rootObject
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

@end
