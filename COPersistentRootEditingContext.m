#import "COPersistentRootEditingContext.h"
#import "COEditingContext.h"
#import "COError.h"
#import "COObject.h"
#import "COStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COPersistentRootEditingContext

@synthesize persistentRootUUID, parentContext, commitTrack, rootObject = _rootObject, revision = _revision;

- (id)initWithPersistentRootUUID: (ETUUID *)aUUID
				 commitTrackUUID: (ETUUID *)aTrackUUID
					  rootObject: (COObject *)aRootObject
				   parentContext: (COEditingContext *)aCtxt
{
	SUPERINIT;

	ASSIGN(persistentRootUUID, aUUID);
	// TODO: Use the track UUID and the root object as no editing context at all
	// when the initializer is called.
	//ASSIGN(commitTrack, [COCommitTrack trackWithObject: aRootObject]);
	ASSIGN(_rootObject, aRootObject);
	parentContext = aCtxt;

	_insertedObjects = [[NSMutableSet alloc] init];
	_deletedObjects = [[NSMutableSet alloc] init];
	ASSIGN(_updatedPropertiesByObject, [NSMapTable mapTableWithStrongToStrongObjects]);

	return self;
}

- (void)dealloc
{
	DESTROY(commitTrack);
	DESTROY(_rootObject);
	DESTROY(_revision);
	DESTROY(_insertedObjects);
	DESTROY(_deletedObjects);
	DESTROY(_updatedPropertiesByObject);
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
	if (parentContext != nil && [parentContext respondsToSelector: aSelector])
	{
		//NSLog(@"Will forward selector %@", NSStringFromSelector(aSelector));
		return parentContext;
	}
	return [super forwardingTargetForSelector: aSelector];
}


- (COCommitTrack *)commitTrack
{
	if (commitTrack == nil)
	{
		ASSIGN(commitTrack, [COCommitTrack trackWithObject: [self rootObject]]);
	}
	return commitTrack;
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
		[parentContext discardLoadedObjectForUUID: [object UUID]];
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

- (id)objectWithUUID: (ETUUID *)uuid
{
	return [parentContext objectWithUUID: uuid];
}

- (COObject *)objectWithUUID: (ETUUID *)uuid entityName: (NSString *)name atRevision: (CORevision *)rev
{
	return [parentContext objectWithUUID: uuid entityName: name atRevision: rev];
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
	COStore *store = [parentContext store];

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
			[parentContext discardLoadedObjectForUUID: [obj UUID]];
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

	[parentContext setLatestRevisionNumber: [rev revisionNumber]];
	return rev;
}

- (void)registerObject: (COObject *)object
{
	[parentContext cacheLoadedObject: object];
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
	COStore *store = [parentContext store];

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
	[loadedIDs intersectSet: [parentContext loadedObjectUUIDs]];
	
	// Needed and already loaded objects in editing context
	NSMutableSet *neededAndLoadedIDs = [NSMutableSet setWithSet: neededIDs];
	[neededAndLoadedIDs intersectSet: loadedIDs];
	
	// Loaded objects to be unloaded
	NSMutableSet *unwantedIDs = [NSMutableSet setWithSet: loadedIDs];
	[unwantedIDs minusSet: neededIDs];
	
	FOREACH(neededAndLoadedIDs, uuid, ETUUID*)
	{
		[self loadObject: [parentContext loadedObjectForUUID: uuid] atRevision: revision];
	}
	
	FOREACH(unwantedIDs, uuid, ETUUID*)
	{
		[parentContext discardLoadedObjectForUUID: uuid];
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
	COStore *store = [parentContext store];
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
	[loadedIDs intersectSet: [parentContext loadedObjectUUIDs]];
	
	// Loaded objects to be unloaded
	NSMutableSet *unwantedIDs = [NSMutableSet setWithSet: loadedIDs];
	
	FOREACH(unwantedIDs, uuid, ETUUID*)
	{
		[parentContext discardLoadedObjectForUUID: uuid];
	}
	
	[parentContext discardLoadedObjectForUUID: rootObjectUUID];
}

@end