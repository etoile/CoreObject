#import "COPersistentRoot.h"
#import "COEditingContext.h"
#import "COError.h"
#import "COObject.h"
#import "COStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COPersistentRoot

@synthesize persistentRootUUID = _persistentRootUUID, parentContext = _parentContext,
	commitTrack = _commitTrack, rootObject = _rootObject, revision = _revision;

- (CORevision *)loadableRevisionForRevision: (CORevision *)aRevision
							 rootObjectUUID: (ETUUID *)aRootObjectUUID
{
	int64_t maxRevNumber = [_parentContext maxRevisionNumber];
	BOOL hasMaxRev = (maxRevNumber > 0);
	int64_t revNumber = (aRevision != nil ? [aRevision revisionNumber] : maxRevNumber);
	
	if (hasMaxRev && revNumber > maxRevNumber)
	{
		revNumber = maxRevNumber;
	}
	
	
	// TODO: Should use -maxRevision:forCommitTrackUUID: or -maxRevision:forTrackUUID:
	return [[self store] maxRevision: revNumber
	               forRootObjectUUID: aRootObjectUUID];
}

- (ETUUID *)rootObjectUUID
{
	if (_rootObject != nil)
	{
		return [_rootObject UUID];
	}
	else
	{
		return [[_parentContext store]
			rootObjectUUIDForPersistentRootUUID: [self persistentRootUUID]];
	}
}

- (id)initWithPersistentRootUUID: (ETUUID *)aUUID
				 commitTrackUUID: (ETUUID *)aTrackUUID
                        revision: (CORevision *)aRevision
				   parentContext: (COEditingContext *)aCtxt
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(aTrackUUID);

	SUPERINIT;

	ASSIGN(_persistentRootUUID, aUUID);
	_parentContext = aCtxt;
	if ([_parentContext store] != nil)
	{
		_commitTrack = [[COCommitTrack alloc] initWithUUID: aTrackUUID editingContext: self];
	}
	ASSIGN(_revision, aRevision);

	_loadedObjects = [NSMutableDictionary new];
	_insertedObjects = [NSMutableSet new];
	_deletedObjects = [NSMutableSet new];
	ASSIGN(_updatedPropertiesByObject, [NSMapTable mapTableWithStrongToStrongObjects]);

	return self;
}

- (void)dealloc
{
	DESTROY(_persistentRootUUID);
	DESTROY(_commitTrack);
	DESTROY(_rootObject);
	DESTROY(_revision);
	DESTROY(_loadedObjects);
	DESTROY(_insertedObjects);
	DESTROY(_deletedObjects);
	DESTROY(_updatedPropertiesByObject);
	[super dealloc];
}

- (COCommitTrack *)commitTrack
{
	if (_commitTrack == nil)
	{
		ASSIGN(_commitTrack, [COCommitTrack trackWithObject: [self rootObject]]);
	}
	return _commitTrack;
}

- (COStore *)store
{
	return [_parentContext store];
}
#if 0
- (id)rootObject
{
	if (_rootObject == nil)
	{
		ASSIGN(_rootObject, [persistentRoot objectWithUUID: [self rootObjectUUID]
		                                        atRevision: revision]);
	}
	return _rootObject;
}
#endif
- (NSString *)entityNameForObjectUUID: (ETUUID *)aUUID
{
	int64_t maxRevNumber = [_parentContext maxRevisionNumber];
	int64_t maxNum = (maxRevNumber > 0 ? maxRevNumber : [[_parentContext store] latestRevisionNumber]);
	
	for (int64_t revNum = maxNum; revNum > 0; revNum--)
	{
		CORevision *revision = [[_parentContext store] revisionWithRevisionNumber: revNum];
		NSString *name = [[revision valuesAndPropertiesForObjectUUID: aUUID] objectForKey: @"_entity"];

		if (name != nil)
		{
			return name;
		}
	}
	return nil;
}

// NOTE: If we decide to make the method public, move it to COEditingContext
- (NSString *)defaultEntityName
{
	return @"COObject";
}

- (ETEntityDescription *)descriptionForName: (NSString *)name objectUUID: (ETUUID *)uuid
{
	ETModelDescriptionRepository *repo = [_parentContext modelRepository];
	ETEntityDescription *desc = [repo descriptionForName: name];

	/* If the entity name or description is nil */
	if (desc == nil)
	{
		NSString *name = [self entityNameForObjectUUID: uuid];
		if (name == nil)
		{
			//[NSException raise: NSGenericException format: @"Failed to find an entity name for %@", uuid];
			//NSLog(@"WARNING: -[COEditingContext objectWithUUID:entityName:] failed to find an entity name for %@ (probably, the requested object does not exist)", uuid);
			return nil;
		}
		desc = [repo descriptionForName: name];
	}
	return (desc != nil ? desc : [repo descriptionForName: [self defaultEntityName]]);
}

- (COObject *)loadedObjectForUUID: (ETUUID *)uuid revision: (CORevision *)revision
{
	COObject *obj = [self loadedObjectForUUID: uuid];
	
	if (obj != nil && revision != nil)
	{
		CORevision *existingRevision = [obj revision];
		
		if (![existingRevision isEqual: revision])
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Object %@ requested at revision %@ but already loaded at revision %@",
			 obj, revision, existingRevision];
		}
	}
	return obj;
}

/* When this method is called, the root object might not be loaded. */
- (void)cacheLoadedRevisionForRevision: (CORevision *)revision
{
	if ([self revision] != nil)
		return;

	ETUUID *rootObjectUUID = [self rootObjectUUID];
	ETAssert(rootObjectUUID != nil);

	[self setRevision: [self loadableRevisionForRevision: revision rootObjectUUID: rootObjectUUID]];
}

/** 
 * To prevent branch mismatch, the best approach in document editors is to use
 * a dedicate editing context per document. 
 *
 * COCustomTrack can then use a delegate to look up the context targeted by 
 * undo/redo operations e.g. editingContextForPersistentRootUUID:.
 */
- (COObject *)rootObjectForPersistentRootWithUUID: (ETUUID *)aUUID
{
	NILARG_EXCEPTION_TEST(aUUID);
	ETUUID *persistentRootUUID = nil;
	ETUUID *trackUUID = nil;

	if ([[_parentContext store] isPersistentRootUUID: aUUID] == NO)
	{
		persistentRootUUID = [[_parentContext store] persistentRootUUIDForCommitTrackUUID: aUUID];
		trackUUID = aUUID;
	}
	else
	{
		persistentRootUUID = aUUID;
		trackUUID = [[_parentContext store] mainBranchUUIDForPersistentRootUUID: aUUID];
	}

	/* If the UUID matches no persistent root or track */
	if (persistentRootUUID == nil || trackUUID == nil)
		return nil;

	COPersistentRoot *persistentRoot = [_parentContext persistentRootForUUID: persistentRootUUID];
	BOOL hasBranchMismatch = (persistentRoot != nil && [trackUUID isEqual: [[persistentRoot commitTrack] UUID]] == NO);

	if (hasBranchMismatch)
	{
		// TODO:  Introduce COBranchMismatchException
		[NSException raise: NSInternalInconsistencyException
					format: _(@"Cannot load branch %@ because branch %@ in use doesn't match for %@"),
		                    trackUUID, [persistentRoot commitTrack], persistentRoot];
							  
	}
	/* Can return a root object object that bears the same UUID than the current 
	   persistent root object if persistentRoot is derived from the receiver 
	   through one or several cheap copies.
	   This use case is supported because of -[COObject isEqual:] implementation 
	   and COObject serialization of references accross persistent roots. */
	return [persistentRoot rootObject];
}

- (BOOL)isInnerObjectUUID: (ETUUID *)aUUID
{
	NSSet *allInnerObjectUUIDs =
		[[_parentContext store] objectUUIDsForCommitTrackUUID: [[self commitTrack] UUID]];
	return [allInnerObjectUUIDs containsObject: aUUID];
}

- (COObject *)objectWithUUID: (ETUUID *)uuid entityName: (NSString *)name atRevision: (CORevision *)revision
{
	// NOTE: We serialize UUIDs into strings in various places, this check
	// helps to intercept string objects that ought to be ETUUID objects.
	NSParameterAssert([uuid isKindOfClass: [ETUUID class]]);
	
	/* Check the object cache */

	COObject *obj = [self loadedObjectForUUID: uuid revision: revision];

	if (obj != nil)
		return obj;

	/* Otherwise instantiate the object */

	// TODO: -isInnerObjectUUID: could be a bottleneck here, because we retrieve
	// all the inner object UUIDs from the database each time a fault is created.
	BOOL hasBeenCommitted = [self isInnerObjectUUID: uuid];

	/* When the object is neither in the cache nor serialized in the store */
	if (hasBeenCommitted == NO)
	{
		/* Could be a reference to another persistent root */
		return [self rootObjectForPersistentRootWithUUID: uuid];
	}

	ETEntityDescription *desc = [self descriptionForName: name objectUUID: uuid];
	Class objClass = [[_parentContext modelRepository] classForEntityDescription: desc];

	obj = [[objClass alloc] initWithUUID: uuid
			           entityDescription: desc
			                     context: self
			                    isFault: YES];
	[self cacheLoadedObject: obj];
	[obj release];
	[self cacheLoadedRevisionForRevision: revision];

	return obj;
}

- (COObject *)objectWithUUID: (ETUUID *)uuid
{
	return [self objectWithUUID: uuid entityName: nil atRevision: nil];
}

- (COObject *)objectWithUUID: (ETUUID *)uuid atRevision: (CORevision *)revision
{
	return [self objectWithUUID: uuid entityName: nil atRevision: revision];
}

- (NSSet *)loadedObjects
{
	return [NSSet setWithArray: [_loadedObjects allValues]];
}

- (NSSet *)loadedObjectUUIDs
{
	return [NSSet setWithArray: [_loadedObjects allKeys]];
}

- (NSSet *)loadedRootObjects
{
	NSMutableSet *loadedRootObjects = [NSMutableSet setWithSet: [self loadedObjects]];
	[[loadedRootObjects filter] isRoot];
	return loadedRootObjects;
}

- (id)loadedObjectForUUID: (ETUUID *)uuid
{
	return [_loadedObjects objectForKey: uuid];
}

- (void)cacheLoadedObject: (COObject *)object
{
	[_loadedObjects setObject: object forKey: [object UUID]];
}

- (void)discardLoadedObjectForUUID: (ETUUID *)aUUID
{
	[_loadedObjects removeObjectForKey: aUUID];
}

- (NSSet *)insertedObjects
{
	return [NSSet setWithSet: _insertedObjects];
}

- (NSSet *)updatedObjects
{
	return [NSSet setWithArray: [_updatedPropertiesByObject allKeys]];
}

- (NSSet *)updatedObjectUUIDs
{
	return [NSSet setWithArray: (id)[[[_updatedPropertiesByObject allKeys] mappedCollection] UUID]];
}

- (BOOL)isUpdatedObject: (COObject *)anObject
{
	return ([_updatedPropertiesByObject objectForKey: anObject] != nil);
}

- (NSSet *)deletedObjects
{
	return [NSSet setWithSet: _deletedObjects];
}

- (NSSet *)changedObjects
{
	NSSet *changedObjects = [_insertedObjects setByAddingObjectsFromSet: _deletedObjects];
	return [changedObjects setByAddingObjectsFromSet: [self updatedObjects]];
}

- (BOOL)hasChanges
{
	return ([_updatedPropertiesByObject count] > 0
			|| [_insertedObjects count] > 0
			|| [_deletedObjects count] > 0);
}

- (void)discardAllChanges
{
	for (COObject *object in [[self parentContext] loadedObjects])
	{
		[self discardChangesInObject: object];
	}
	assert([self hasChanges] == NO);
}

- (void)discardChangesInObject: (COObject *)object
{
	BOOL isInsertedObject = [_insertedObjects containsObject: object];
	BOOL isUpdatedObject = ([_updatedPropertiesByObject objectForKey: object] != nil);

	if (isInsertedObject)
	{
		/* Remove the object from the cache because it has never been committed */
		[self discardLoadedObjectForUUID: [object UUID]];
	}
	if (isUpdatedObject)
	{
		/* Revert the object state back to the current persistent root revision */
		[self loadObject: object];
	}
	
	[_insertedObjects removeObject: object];
	[_updatedPropertiesByObject removeObjectForKey: object];
	[_deletedObjects removeObject: object];
}

- (void)deleteObject: (COObject *)anObject
{
	// NOTE: Deleted objects are removed from the cache on commit.
	[_deletedObjects addObject: anObject];
}

- (COObject *)insertObjectWithEntityName: (NSString *)aFullName
                                    UUID: (ETUUID *)aUUID
{
	
	ETEntityDescription *desc = [[_parentContext modelRepository] descriptionForName: aFullName];
	if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	
	Class cls = [[_parentContext modelRepository] classForEntityDescription: desc];
	/* Nil root object means the new object will be a root */
	COObject *result = [[cls alloc]
			  initWithUUID: aUUID
			  entityDescription: desc
			  context: nil
			  isFault: NO];

	[result becomePersistentInContext: self];
	/* -becomePersistentInContent: calls -registerObject: that retains the object */
	[result release];

	return result;
}

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
	return [self insertObjectWithEntityName: aFullName UUID: [ETUUID UUID]];
}

- (id)insertObject: (COObject *)sourceObject
{
	return [self insertObject: sourceObject withRelationshipConsistency: YES newUUID: NO];
}

- (id)insertObjectCopy: (COObject *)sourceObject
{
	return [self insertObject: sourceObject withRelationshipConsistency: YES newUUID: YES];
}

/**
 * Helper method for -insertObject:
 */
static id handle(id value, COPersistentRoot *ctx, ETPropertyDescription *desc, BOOL consistency, BOOL newUUID)
{
	if ([value isKindOfClass: [NSArray class]] || [value isKindOfClass: [NSSet class]])
	{
		id copy = [[[[[value class] mutableClass] alloc] init] autorelease];
		
		// NOTE: We have to use -contentArray to get a collection copy,
		// otherwise weird issues happen, since using
		// -[COObject updateRelationshipConsistencyWithValue:forProperty:] sent
		// to a subobject can mutate a parent multivalued property because we
		// use recursion to copy the composite tree.
		for (id subvalue in [value contentArray])
		{
			id subvalueCopy = handle(subvalue, ctx, desc, consistency, newUUID);
			
			if (subvalueCopy != nil)
			{
				[copy addObject: subvalueCopy];
			}
			else
			{
				// FIXME: Can be reached when we copy an object to some other
				// context where some relationships cannot be resolved (-objectWithUUID: is returning nil).
				//[NSException raise: NSInternalInconsistencyException
				//            format: @"Multivalued property %@ contains a value %@ which cannot be copied", desc, value];
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
			COObject *copy = [[ctx parentContext] objectWithUUID: [value UUID]];
			return copy;
		}
	}
	else
	{
		return [[value mutableCopy] autorelease];
	}
}

- (id)insertObject: (COObject *)sourceObject withRelationshipConsistency: (BOOL)consistency  newUUID: (BOOL)newUUID
{
	NSParameterAssert([sourceObject persistentRoot] != nil);
	
	/* Source Object is already persistent
	 
	 So we create a persistent object alias or copy in the receiver context */
	
	NSString *entityName = [[sourceObject entityDescription] fullName];
	assert(entityName != nil);
	
	COObject *copy;
	
	if (!newUUID)
	{
		copy = [_parentContext objectWithUUID: [sourceObject UUID]];
		
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

- (CORevision *)commit
{
	return [self commitWithType: nil shortDescription: nil];
}

- (CORevision *)commitWithType: (NSString *)type
           shortDescription: (NSString *)shortDescription
{
	NSString *commitType = type;
	
	if (type == nil)
	{
		commitType = @"Unknown";
	}
	if (shortDescription == nil)
	{
		shortDescription = @"";
	}
	return [self commitWithMetadata: D(shortDescription, @"shortDescription", commitType, @"type")];
}


- (CORevision *)commitWithMetadata: (NSDictionary *)metadata
{
	NSArray *revs = [_parentContext commitWithMetadata: metadata
	                restrictedToPersistentRoots: A(self)];
	ETAssert([revs count] == 1);
	return [revs lastObject];
}

- (CORevision *)saveCommitWithMetadata: (NSDictionary *)metadata
{
	NSParameterAssert(_rootObject != nil);
	NSParameterAssert(_insertedObjects != nil);
	NSParameterAssert(_updatedPropertiesByObject != nil);

	// TODO: ETAssert([rootObject isRoot]);
	// TODO: We should add the deleted object UUIDs to the set below
	NSSet *committedObjects = 
		[_insertedObjects setByAddingObjectsFromArray: [_updatedPropertiesByObject allKeys]];
	COStore *store = [_parentContext store];
	BOOL isNewPersistentRoot = ([self revision] == nil);

	if (isNewPersistentRoot)
	{

		ETAssert([_insertedObjects containsObject: _rootObject]);

		[store insertPersistentRootUUID: [self persistentRootUUID]
						commitTrackUUID: [[self commitTrack] UUID]
						 rootObjectUUID: [_rootObject UUID]];
	}

	[store beginCommitWithMetadata: metadata
	            persistentRootUUID: [self persistentRootUUID]
	               commitTrackUUID: [[self commitTrack] UUID]
	                  baseRevision: [_rootObject revision]];

	for (COObject *obj in committedObjects)
	{		
		[store beginChangesForObjectUUID: [obj UUID]];

		NSArray *persistentProperties = [obj persistentPropertyNames];
		id <ETCollection> propertiesToCommit = nil;

		//NSLog(@"Committing changes for %@", obj);

		if ([_insertedObjects containsObject: obj])
		{
			// for the first commit, commit all property values
			propertiesToCommit = persistentProperties;
		}
		else
		{
			// otherwise just damaged values
			NSArray *updatedProperties = [_updatedPropertiesByObject objectForKey: obj];

			propertiesToCommit = [NSMutableSet setWithArray: updatedProperties];
			[(NSMutableSet *)propertiesToCommit intersectSet: [NSSet setWithArray: persistentProperties]];
		}

		for (NSString *prop in propertiesToCommit)
		{
			id value = [obj serializedValueForProperty: prop];
			id plist = [obj propertyListForValue: value];
			
			[store setValue: plist
			     forProperty: prop
			        ofObject: [obj UUID]
			     shouldIndex: NO];
		}
		
		if ([_deletedObjects containsObject: obj])
		{
			// TODO: Mark the object as deleted in the store
			[self discardLoadedObjectForUUID: [obj UUID]];
		}
		
		// FIXME: Hack
		NSString *name = [[obj entityDescription] fullName];

		[store setValue: name
		     forProperty: @"_entity"
		        ofObject: [obj UUID]
		     shouldIndex: NO];
		
		[store finishChangesForObjectUUID: [obj UUID]];
	}
	
	CORevision *rev = [store finishCommit];
	assert(rev != nil);

	[self setRevision: rev];
	[[self commitTrack] didMakeNewCommitAtRevision: rev];
	
	[_insertedObjects removeAllObjects];
	[_updatedPropertiesByObject removeAllObjects];
	[_deletedObjects removeAllObjects];

	return rev;
}

- (void)registerObject: (COObject *)object
{
	NILARG_EXCEPTION_TEST(object);
	INVALIDARG_EXCEPTION_TEST(object, [[_parentContext loadedObjects] containsObject: object] == NO);

	/* If -becomePersistentInContext: receives -makePersistentRoot as argument.
	   We must be sure no root object has ever been set (committed or not). */
	if (_rootObject == nil && [self rootObjectUUID] == nil)
	{
		[self setRootObject: object];
	}

	[self cacheLoadedObject: object];
	[_insertedObjects addObject: object];
}

- (void)markObjectUpdated: (COObject *)obj forProperty: (NSString *)aProperty
{
	if (nil == [_updatedPropertiesByObject objectForKey: obj])
	{
		[_updatedPropertiesByObject setObject: [NSMutableArray array] forKey: obj];
	}
	if (aProperty != nil)
	{
		assert([aProperty isKindOfClass: [NSString class]]);
		[[_updatedPropertiesByObject objectForKey: obj] addObject: aProperty];
	}
}

// FIXME: Probably need to turn off relationship consistency around loading.
- (void)loadObject: (COObject *)obj atRevision: (CORevision *)aRevision
{
	CORevision *loadedRev = aRevision;
	ETUUID *objUUID = [obj UUID];
	NSMutableSet *propertiesToFetch = [NSMutableSet setWithArray: [obj persistentPropertyNames]];
	//NSLog(@"Properties to fetch: %@", propertiesToFetch);
	
	obj->_isIgnoringDamageNotifications = YES;
	[obj setIgnoringRelationshipConsistency: YES];
	
	if (loadedRev == nil)
	{
		loadedRev = [obj revision];
	}
	ETAssert(loadedRev != nil);
	
	//NSLog(@"Load object %@ at %i", objUUID, (int)revNum);
	
	while ([propertiesToFetch count] > 0 && loadedRev != nil)
	{
		NSDictionary *dict = [loadedRev valuesAndPropertiesForObjectUUID: objUUID];
		
		for (NSString *key in [dict allKeys])
		{
			if ([propertiesToFetch containsObject: key])
			{
				id plist = [dict objectForKey: key];
				id value = [obj valueForPropertyList: plist];
				//NSLog(@"key %@, unparsed %@, parsed %@", key, plist, value);
				[obj setSerializedValue: value forProperty: key];
				[propertiesToFetch removeObject: key];
			}
		}
		
		loadedRev = [loadedRev baseRevision];
	}
	
	if ([propertiesToFetch count] > 0)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Store is missing properties %@ for %@", propertiesToFetch, obj];
	}
	
	[_updatedPropertiesByObject removeObjectForKey: obj];
	obj->_isIgnoringDamageNotifications = NO;
	[obj setIgnoringRelationshipConsistency: NO];
}

- (void)loadObject: (COObject *)obj
{
	[self loadObject: obj atRevision: nil];
}

- (void)reloadAtRevision: (CORevision *)revision
{
	// TODO: Handle invalid revision. May be call -unloadRootObjectTree: if the
	// revision is older than the root object creation revision.
	CORevision *currentRevision = [self revision];
	COStore *store = [_parentContext store];

	if ([revision isEqual: currentRevision])
		return;
	
	[self setRevision: revision];
	
	// FIXME: Optimise for undo/redo cases (revisions next to each other)
	
	// Case 1: unrelated revisions
	// This part is somewhat tricky. We need to reload all sub-objects
	// that already exist in the context, and we ought to get rid of all
	// subobjects that are no longer in use. Objects that exist in the
	// new revision but were not part of the old revision tree should
	// automatically be faulted in (I think).
	
	// All objects in all revisions
	NSSet *allIDs = [store objectUUIDsForCommitTrackUUID: [[self commitTrack] UUID]];
	
	// Objects needed in this revision
	NSSet *neededIDs = [store objectUUIDsForCommitTrackUUID: [[self commitTrack] UUID]
	                                             atRevision: revision];
	
	// Loaded objects in editing context
	NSMutableSet *loadedIDs = [NSMutableSet setWithSet: allIDs];
	[loadedIDs intersectSet: [self loadedObjectUUIDs]];
	
	// Needed and already loaded objects in editing context
	NSMutableSet *neededAndLoadedIDs = [NSMutableSet setWithSet: neededIDs];
	[neededAndLoadedIDs intersectSet: loadedIDs];
	
	// Loaded objects to be unloaded
	NSMutableSet *unwantedIDs = [NSMutableSet setWithSet: loadedIDs];
	[unwantedIDs minusSet: neededIDs];
	
	FOREACH(neededAndLoadedIDs, uuid, ETUUID *)
	{
		[self loadObject: [self loadedObjectForUUID: uuid] atRevision: revision];
	}
	
	FOREACH(unwantedIDs, uuid, ETUUID *)
	{
		[self discardLoadedObjectForUUID: uuid];
	}
	
	// As you can see, we haven't removed objects that are "dangling". There
	// might be an advantage to this, but most likely not. Its quite hard (we
	// have to search the whole object tree for references or use the store
	// to get the set of object ids in each revision and minus the sets) so
	// I couldn't be bothered right now. May in fact be easiest to dispose of
	// the editing context and reload it.
	
	// Case 2: [revision baseRevision] == oldRevision (redo)
	
	// Case 3: [oldRevision baseRevision] == revision (undo)
	
	[[self rootObject] didReload];
}

// TODO: Share code with -reload:atRevision:
- (void)unload
{
	COStore *store = [_parentContext store];
	//CORevision *oldRevision = [_rootObjectRevisions objectForKey: rootObjectUUID];

	[self setRevision: nil];
	
	// FIXME: Optimise for undo/redo cases (revisions next to each other)
	
	// Case 1: unrelated revisions
	// This part is somewhat tricky. We need to reload all sub-objects
	// that already exist in the context, and we ought to get rid of all
	// subobjects that are no longer in use. Objects that exist in the
	// new revision but were not part of the old revision tree should
	// automatically be faulted in (I think).
	
	// All objects in all revisions
	NSSet *allIDs = [store objectUUIDsForCommitTrackUUID: [[self commitTrack] UUID]];
	
	// Loaded objects in editing context
	NSMutableSet *loadedIDs = [NSMutableSet setWithSet: allIDs];
	[loadedIDs intersectSet: [self loadedObjectUUIDs]];
	
	// Loaded objects to be unloaded
	NSMutableSet *unwantedIDs = [NSMutableSet setWithSet: loadedIDs];
	
	FOREACH(unwantedIDs, uuid, ETUUID *)
	{
		[self discardLoadedObjectForUUID: uuid];
	}
	
	[self discardLoadedObjectForUUID: [[self rootObject] UUID]];
}

- (Class)referenceClassForRootObject: (COObject *)aRootObject
{
	// TODO: When the user has selected a precise branch, just return COCommitTrack.
	return [COPersistentRoot class];
}

@end