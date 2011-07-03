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

- (BOOL) hasChanges
{
	return [_damagedObjectUUIDs count] > 0;
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
	//COEditingContext *sourceContext = [sourceObject editingContext];
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
	
	for (NSString *prop in [sourceObject propertyNames])
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
- (void) commitWithMetadata: (NSDictionary*)metadata
{
	[_store beginCommitWithMetadata: metadata];
	for (ETUUID *uuid in [_damagedObjectUUIDs allKeys])
	{		
		[_store beginChangesForObject: uuid];
		COObject *obj = [self objectWithUUID: uuid];
		//NSLog(@"Committing changes for %@", obj);
		
		NSArray *propsToCommit;
		if ([_insertedObjectUUIDs containsObject: uuid])
		{
			propsToCommit = [obj propertyNames]; // for the first commit, commit all property values
		}
		else
		{
			propsToCommit = [_damagedObjectUUIDs objectForKey: uuid]; // otherwise just damaged values
		}

		
		for (NSString *prop in propsToCommit)
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
	for (ETUUID *uuid in [_damagedObjectUUIDs allKeys])
	{
		[self markObjectUndamaged: [self objectWithUUID: uuid]];
	}
}

// Private

- (uint64_t)currentRevisionNumber
{
	if (_revision == nil)
	{
		return [_store latestRevisionNumber];
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

	NSMutableSet *propertiesToFetch = [NSMutableSet setWithArray: [obj propertyNames]];
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
				//NSLog(@"WARNING: -[COEditingContext objectWithUUID:entityName:] failed to find an entity name for %@ (probably, the requested object does not exist)", uuid);
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

@end
