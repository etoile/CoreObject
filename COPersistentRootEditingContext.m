#import "COPersistentRootEditingContext.h"
#import "COEditingContext.h"
#import "COError.h"
#import "COObject.h"
#import "COStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COPersistentRootEditingContext

@synthesize persistentRootUUID = _persistentRootUUID, parentContext = _parentContext,
	commitTrack = _commitTrack, rootObject = _rootObject, revision = _revision;

- (id)initWithPersistentRootUUID: (ETUUID *)aUUID
				 commitTrackUUID: (ETUUID *)aTrackUUID
					  rootObject: (COObject *)aRootObject
				   parentContext: (COEditingContext *)aCtxt
{
	SUPERINIT;

	ASSIGN(_persistentRootUUID, aUUID);
	// TODO: Use the track UUID and the root object as no editing context at all
	// when the initializer is called.
	//ASSIGN(_commitTrack, [COCommitTrack trackWithObject: aRootObject]);
	ASSIGN(_rootObject, aRootObject);
	_parentContext = aCtxt;

	_insertedObjects = [[NSMutableSet alloc] init];
	_deletedObjects = [[NSMutableSet alloc] init];
	ASSIGN(_updatedPropertiesByObject, [NSMapTable mapTableWithStrongToStrongObjects]);

	return self;
}

- (void)dealloc
{
	DESTROY(_commitTrack);
	DESTROY(_rootObject);
	DESTROY(_revision);
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
		[_parentContext discardLoadedObjectForUUID: [object UUID]];
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
	
	Class cls = [_parentContext classForEntityDescription: desc];
	/* Nil root object means the new object will be a root */
	COObject *result = [[cls alloc]
			  initWithUUID: aUUID
			  entityDescription: desc
			  rootObject: _rootObject
			  context: (id)self
			  isFault: NO];

	[result becomePersistentInContext: (id)self
	                       rootObject: (_rootObject != nil ? _rootObject : result)];
	/* -becomePersistentInContent:rootObject: calls -registerObject: that retains the object */
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
static id handle(id value, COPersistentRootEditingContext *ctx, ETPropertyDescription *desc, BOOL consistency, BOOL newUUID)
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
	NSParameterAssert([sourceObject editingContext] != nil);
	
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

- (CORevision *)commitWithMetadata: (NSDictionary *)metadata
{
	NSParameterAssert(_rootObject != nil);
	NSParameterAssert(_insertedObjects != nil);
	NSParameterAssert(_updatedPropertiesByObject != nil);

	// TODO: ETAssert([rootObject isRoot]);
	// TODO: We should add the deleted object UUIDs to the set below
	NSSet *committedObjects = 
		[_insertedObjects setByAddingObjectsFromArray: [_updatedPropertiesByObject allKeys]];
	COStore *store = [_parentContext store];

	if ([_insertedObjects containsObject: _rootObject])
	{
		[store insertRootObjectUUIDs: S([_rootObject UUID])];
	}

	[store beginCommitWithMetadata: metadata 
	                 rootObjectUUID: [_rootObject UUID]
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
			[_parentContext discardLoadedObjectForUUID: [obj UUID]];
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

	[_parentContext setLatestRevisionNumber: [rev revisionNumber]];
	return rev;
}

- (void)registerObject: (COObject *)object
{
	[_parentContext cacheLoadedObject: object];
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
	CORevision *objectRev = nil;
	ETUUID *objUUID = [obj UUID];
	
	NSMutableSet *propertiesToFetch = [NSMutableSet setWithArray: [obj persistentPropertyNames]];
	//NSLog(@"Properties to fetch: %@", propertiesToFetch);
	
	obj->_isIgnoringDamageNotifications = YES;
	[obj setIgnoringRelationshipConsistency: YES];
	
	if (aRevision == nil)
	{
		aRevision = [obj revision];
	}
	
	//NSLog(@"Load object %@ at %i", objUUID, (int)revNum);
	
	while ([propertiesToFetch count] > 0 && aRevision != nil)
	{
		NSDictionary *dict = [aRevision valuesAndPropertiesForObjectUUID: objUUID];
		
		for (NSString *key in [dict allKeys])
		{
			if ([propertiesToFetch containsObject: key])
			{
				if (nil == objectRev)
				{
					objectRev = aRevision;
				}
				
				id plist = [dict objectForKey: key];
				id value = [obj valueForPropertyList: plist];
				//NSLog(@"key %@, unparsed %@, parsed %@", key, plist, value);
				[obj setSerializedValue: value forProperty: key];
				[propertiesToFetch removeObject: key];
			}
		}
		
		aRevision = [aRevision baseRevision];
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
	
	ETUUID *rootObjectUUID = [[self rootObject] UUID];
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
	NSSet *allIDs = [store UUIDsForRootObjectUUID: rootObjectUUID];
	
	// Objects needed in this revision
	NSSet *neededIDs = [store UUIDsForRootObjectUUID: rootObjectUUID atRevision: revision];
	
	// Loaded objects in editing context
	NSMutableSet *loadedIDs = [NSMutableSet setWithSet: allIDs];
	[loadedIDs intersectSet: [_parentContext loadedObjectUUIDs]];
	
	// Needed and already loaded objects in editing context
	NSMutableSet *neededAndLoadedIDs = [NSMutableSet setWithSet: neededIDs];
	[neededAndLoadedIDs intersectSet: loadedIDs];
	
	// Loaded objects to be unloaded
	NSMutableSet *unwantedIDs = [NSMutableSet setWithSet: loadedIDs];
	[unwantedIDs minusSet: neededIDs];
	
	FOREACH(neededAndLoadedIDs, uuid, ETUUID*)
	{
		[self loadObject: [_parentContext loadedObjectForUUID: uuid] atRevision: revision];
	}
	
	FOREACH(unwantedIDs, uuid, ETUUID*)
	{
		[_parentContext discardLoadedObjectForUUID: uuid];
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
	ETUUID *rootObjectUUID = [[self rootObject] UUID];
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
	NSSet *allIDs = [store UUIDsForRootObjectUUID: rootObjectUUID];
	
	// Loaded objects in editing context
	NSMutableSet *loadedIDs = [NSMutableSet setWithSet: allIDs];
	[loadedIDs intersectSet: [_parentContext loadedObjectUUIDs]];
	
	// Loaded objects to be unloaded
	NSMutableSet *unwantedIDs = [NSMutableSet setWithSet: loadedIDs];
	
	FOREACH(unwantedIDs, uuid, ETUUID*)
	{
		[_parentContext discardLoadedObjectForUUID: uuid];
	}
	
	[_parentContext discardLoadedObjectForUUID: rootObjectUUID];
}

@end