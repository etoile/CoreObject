#import "COEditingContext.h"
#import "COObject.h"
#import "COGroup.h"
#import "COStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COEditingContext

+ (COEditingContext *)contextWithURL: (NSURL *)aURL
{
	COEditingContext *ctx = [[self alloc] initWithStore: [[[COStore alloc] initWithURL: aURL] autorelease]];
	return [ctx autorelease];
}

static COEditingContext *currentCtxt = nil;

+ (COEditingContext *)currentContext
{
	return currentCtxt;
}

+ (void)setCurrentContext: (COEditingContext *)aCtxt
{
	ASSIGN(currentCtxt, aCtxt);
}

- (id)initWithStore: (COStore *)store
{
	return [self initWithStore: store maxRevisionNumber: 0];
}

- (id)initWithStore: (COStore *)store maxRevisionNumber: (int64_t)maxRevisionNumber;
{
	SUPERINIT;

	ASSIGN(_store, store);
	_maxRevisionNumber = maxRevisionNumber;	

	_modelRepository = [[ETModelDescriptionRepository mainRepository] retain];

	_rootObjectRevisions = [NSMutableDictionary new];
	_rootObjectCommitTracks = [NSMutableDictionary new];
	assert([[[_modelRepository descriptionForName: @"Anonymous.COContainer"] 
		propertyDescriptionForName: @"contents"] isComposite]);
	assert([[[[_modelRepository descriptionForName: @"Anonymous.COGroup"] 
		parent] name] isEqual: @"COObject"]);

	_instantiatedObjects = [[NSMutableDictionary alloc] init];
	_insertedObjects = [[NSMutableSet alloc] init];
	_deletedObjects = [[NSMutableSet alloc] init];
	ASSIGN(_updatedPropertiesByObject, [NSMapTable mapTableWithStrongToStrongObjects]);
	
	return self;
}

- (id)init
{
	return [self initWithStore: nil];
}

- (void) dealloc
{
	DESTROY(_store);
	DESTROY(_modelRepository);
	DESTROY(_rootObjectRevisions);
	DESTROY(_rootObjectCommitTracks);
	DESTROY(_instantiatedObjects);
	DESTROY(_insertedObjects);
	DESTROY(_deletedObjects);
	DESTROY(_updatedPropertiesByObject);
	[super dealloc];
}

// FIXME: Should this copy uncommitted changes?
- (id)copyWithZone:(NSZone *)zone
{
	id copy = [[COEditingContext alloc] initWithStore: _store];
	// FIXME:
	return copy;
}

- (COSmartGroup *) mainGroup
{
	COSmartGroup *group = AUTORELEASE([[COSmartGroup alloc] init]);
	COContentBlock block = ^() {
		NSSet *rootUUIDs = [[self store] rootObjectUUIDs];
		NSMutableArray *rootObjects = [NSMutableArray arrayWithCapacity: [rootUUIDs count]];

		for (ETUUID *uuid in rootUUIDs)
		{
			[rootObjects addObject: [self objectWithUUID: uuid]];
		}

		return rootObjects;
	};

	[group setContentBlock: block];
	[group setName: _(@"All Objects")];

	return group;
}

- (COGroup *)tagGroup
{
	NSString *UUIDString = [[_store metadata] objectForKey: @"kCOTagGroupUUID"];

	if (UUIDString == nil)
	{
		COGroup *newGroup = [self insertObjectWithEntityName: @"Anonymous.COGroup"];
		NSMutableDictionary *metadata = AUTORELEASE([[_store metadata] mutableCopy]);

		[newGroup setName: _(@"Tags")];
		[metadata setObject: [[newGroup UUID] stringValue] 
		             forKey: @"kCOTagGroupUUID"];
		[_store setMetadata: metadata];
	
		return newGroup;
	}

	return (id)[self objectWithUUID: [ETUUID UUIDWithString: UUIDString]];
}

- (COGroup *)libraryGroup
{
	NSString *UUIDString = [[_store metadata] objectForKey: @"kCOLibraryGroupUUID"];

	if (UUIDString == nil)
	{
		COGroup *newGroup = [self insertObjectWithEntityName: @"Anonymous.COGroup"];
		NSMutableDictionary *metadata = AUTORELEASE([[_store metadata] mutableCopy]);

		[newGroup setName: _(@"Libraries")];
		[metadata setObject: [[newGroup UUID] stringValue] 
		             forKey: @"kCOLibraryGroupUUID"];
		[_store setMetadata: metadata];
	
		return newGroup;
	}

	return (id)[self objectWithUUID: [ETUUID UUIDWithString: UUIDString]];
}

- (id)photoLibrary
{
	return [[self libraryGroup] groupForTagString: @"photo"];
}

- (id)musicLibrary
{
	return [[self libraryGroup] groupForTagString: @"music"];
}

- (COStore *)store
{
	return _store;
}

- (ETModelDescriptionRepository *)modelRepository
{
	return _modelRepository; 
}

- (Class)classForEntityDescription: (ETEntityDescription *)desc
{
	Class cls = [_modelRepository classForEntityDescription: desc];
	if (cls == Nil)
	{
		cls = [COObject class];
	}
	return cls;
}

- (NSString *)entityNameForObjectUUID: (ETUUID *)obj
{
	uint64_t maxNum = (_maxRevisionNumber > 0 ? _maxRevisionNumber : [_store latestRevisionNumber]);

	for (uint64_t revNum = maxNum; revNum > 0; revNum--)
	{
		CORevision *revision = [_store revisionWithRevisionNumber: revNum];
		NSString *name = [[revision valuesAndPropertiesForObjectUUID: obj] objectForKey: @"_entity"];
		if (name != nil)
		{
			return name;
		}
	}
	return nil;
}

- (COObject *)objectWithUUID: (ETUUID *)uuid entityName: (NSString *)name atRevision: (CORevision *)revision
{
	COObject *result = [_instantiatedObjects objectForKey: uuid];

	if (result != nil && revision != nil)
	{
		CORevision *existingRevision = [self revisionForObject: result];
		if (![existingRevision isEqual: revision])
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Object %@ requested at revision %@ but already loaded at revision %@",
				result, revision, existingRevision];
		}
	}
	
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
		CORevision *maxRevision = nil;

		if (isRoot)
		{
			if (nil == revision)
			{
				NSArray * revisionNodes = [_store 
					loadCommitTrackForObject: rootUUID	
						    fromRevision: nil
						    nodesForward: 0
						   nodesBackward: 0];
				revision = [revisionNodes objectAtIndex: 0];
			}
		}
		if (!isRoot)
		{
			if (nil == revision && nil != maxRevision)
			{
				revision = maxRevision;
			}
			rootObject = [self objectWithUUID: rootUUID entityName: nil atRevision: revision];
		}

		Class cls = [self classForEntityDescription: desc];
		result = [[cls alloc] 
			     initWithUUID: uuid
			entityDescription: desc
			       rootObject: rootObject
				  context: self
				  isFault: YES];
		
		if (isRoot)
		{
			[_rootObjectRevisions setObject: revision forKey: [result UUID]];
		}
		[_instantiatedObjects setObject: result forKey: uuid];
		[result release];
	}
	
	return result;
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
	return [NSSet setWithArray: [_instantiatedObjects allValues]];
}

- (NSSet *)loadedRootObjects
{
	NSMutableSet *loadedRootObjects = [NSMutableSet setWithSet: [self loadedObjects]];
	[[loadedRootObjects filter] isRoot];
	return loadedRootObjects;
}

- (id)loadedObjectForUUID: (ETUUID *)uuid
{
	return [_instantiatedObjects objectForKey: uuid];
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
	for (COObject *object in [_instantiatedObjects allValues])
	{
		[self discardChangesInObject: object];
	}
	assert([self hasChanges] == NO);
}

- (void)discardChangesInObject: (COObject *)object
{
	// FIXME: is this what we want?
	
	// Special case for objects which haven't yet been comitted
	if ([_insertedObjects containsObject: object])
	{
		[_updatedPropertiesByObject removeObjectForKey: object];
		[_insertedObjects removeObject: object];
		[_instantiatedObjects removeObjectForKey: [object UUID]];
		// lingering instances may be in a 'zombie' state now... not sure how to solve that problem
	}
	else
	{
		[self loadObject: object];
	}
}

- (void)registerObject: (COObject *)object
{
	[_instantiatedObjects setObject: object forKey: [object UUID]];
	[_insertedObjects addObject: object];
}

- (COObject *)insertObjectWithEntityName: (NSString *)aFullName 
                                    UUID: (ETUUID *)aUUID 
                              rootObject: (COObject *)rootObject
{
	COObject *result = nil;
	ETEntityDescription *desc = [_modelRepository descriptionForName: aFullName];
	if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	
	Class cls = [self classForEntityDescription: desc];
	/* Nil root object means the new object will be a root */
	result = [[cls alloc] 
		     initWithUUID: aUUID
		entityDescription: desc
		       rootObject: rootObject
		          context: self
		          isFault: NO];
	[result didCreate];
	[self registerObject: result];
	[result release];
	
	return result;
}

- (id)insertObjectWithClass: (Class)aClass rootObject: (COObject *)rootObject;
{
	return [self insertObjectWithEntityName: [[_modelRepository entityDescriptionForClass: aClass] fullName]];
}

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
	return [self insertObjectWithEntityName:aFullName UUID: [ETUUID UUID] rootObject: nil];
}

- (id)insertObjectWithEntityName: (NSString *)aFullName rootObject: (COObject *)rootObject
{
	return [self insertObjectWithEntityName: aFullName UUID: [ETUUID UUID] rootObject: rootObject];
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

- (id)insertObject: (COObject *)sourceObject withRelationshipConsistency: (BOOL)consistency  newUUID: (BOOL)newUUID
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
			copy = [self insertObjectWithEntityName: entityName UUID: [sourceObject UUID] rootObject: nil];
		}
	}
	else
	{
		copy = [self insertObjectWithEntityName: entityName UUID: [ETUUID UUID] rootObject: nil];
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

- (id)insertObject: (COObject *)sourceObject
{
	return [self insertObject: sourceObject withRelationshipConsistency: YES newUUID: NO];
}

- (id)insertObjectCopy: (COObject *)sourceObject
{
	return [self insertObject: sourceObject withRelationshipConsistency: YES newUUID: YES];
}

- (void)deleteObject: (COObject *)anObject
{
	[_deletedObjects addObject: anObject];
	[_instantiatedObjects removeObjectForKey: [anObject UUID]];
}

- (NSMapTable *)objectsByRootObjectFromObjects: (id <ETCollection>)objects
{
	NSMapTable *objectsByRootObject = [NSMapTable mapTableWithStrongToStrongObjects];

	// NOTE: For now, ETCollection doesn't include -countByEnumeratingWithState:objects:count:
	// so we use FOREACH to prevent compilation error with recent Clang.
	FOREACH(objects, obj, COObject *)
	{
		COObject *rootObject = [obj rootObject];
		NSMutableSet *innerObjects = [objectsByRootObject objectForKey: rootObject];

		if (innerObjects == nil)
		{
			innerObjects = [NSMutableSet set];
			[objectsByRootObject setObject: innerObjects forKey: rootObject];
		}
		[innerObjects addObject: obj];
	}

	return objectsByRootObject;
}

- (NSMapTable *)insertedObjectsByRootObject
{
	return [self objectsByRootObjectFromObjects: _insertedObjects];
}

- (NSMapTable *)updatedObjectsByRootObject
{
	return [self objectsByRootObjectFromObjects: [_updatedPropertiesByObject allKeys]];
}

- (void)commit
{
	[self commitWithType: nil shortDescription: nil longDescription: nil];
}

- (void)commitWithType: (NSString*)type
      shortDescription: (NSString*)shortDescription
       longDescription: (NSString*)longDescription
{
	NSString *commitType = type;

	if (type == nil)
	{
		commitType = @"Unknown";
	}
	[self commitWithMetadata: D(shortDescription, @"shortDescription", 
		longDescription, @"longDescription", commitType, @"type")];
}

- (NSMapTable *)updatedPropertySubsetForObjects: (NSArray *)keys
{
	NSMapTable *subset = [NSMapTable mapTableWithStrongToStrongObjects];

	for (COObject *obj in _updatedPropertiesByObject)
	{
		if ([keys containsObject: obj] == NO)
			continue;

		[subset setObject: [_updatedPropertiesByObject objectForKey: obj] 
		           forKey: obj];
	}

	return subset;
}

- (void)commitWithMetadata: (NSDictionary *)metadata 
                rootObject: (COObject *)rootObject
           insertedObjects: (NSSet *)insertedObjects
         updatedProperties: (NSMapTable *)updatedPropertiesByObject
{
	NSParameterAssert(rootObject != nil);
	NSParameterAssert(insertedObjects != nil);
	NSParameterAssert(updatedPropertiesByObject != nil);
	// TODO: ETAssert([rootObject isRoot]);
	// TODO: We should add the deleted object UUIDs to the set below
	NSSet *committedObjects = 
		[insertedObjects setByAddingObjectsFromArray: [updatedPropertiesByObject allKeys]];

	[_store beginCommitWithMetadata: metadata 
	                 rootObjectUUID: [rootObject UUID]
	                   baseRevision: [rootObject revision]];

	for (COObject *obj in committedObjects)
	{		
		[_store beginChangesForObjectUUID: [obj UUID]];

		NSArray *persistentProperties = [obj persistentPropertyNames];
		id <ETCollection> propertiesToCommit = nil;

		//NSLog(@"Committing changes for %@", obj);

		if ([insertedObjects containsObject: obj])
		{
			// for the first commit, commit all property values
			propertiesToCommit = persistentProperties;
			ETAssert([_insertedObjects containsObject: obj]);
		}
		else
		{
			// otherwise just damaged values
			NSArray *updatedProperties = [updatedPropertiesByObject objectForKey: obj];

			propertiesToCommit = [NSMutableSet setWithArray: updatedProperties];
			[(NSMutableSet *)propertiesToCommit intersectSet: [NSSet setWithArray: persistentProperties]];
			ETAssert([_insertedObjects containsObject: obj] == NO);
		}

		FOREACH(propertiesToCommit, prop, NSString*)
		{
			id value = [obj serializedValueForProperty: prop];
			id plist = [obj propertyListForValue: value];
			
			[_store setValue: plist
			     forProperty: prop
			        ofObject: [obj UUID]
			     shouldIndex: NO];
		}
		
		// FIXME: Hack
		NSString *name = [[obj entityDescription] fullName];

		[_store setValue: name
		     forProperty: @"_entity"
		        ofObject: [obj UUID]
		     shouldIndex: NO];
		
		[_store finishChangesForObjectUUID: [obj UUID]];
	}
	
	CORevision *rev = [_store finishCommit];
	assert(rev != nil);
	[_rootObjectRevisions setObject: rev forKey: [rootObject UUID]];
	[[_rootObjectCommitTracks objectForKey: [rootObject UUID]]
		newCommitAtRevision: rev];
	
	[_insertedObjects minusSet: insertedObjects];
	for (COObject *obj in [updatedPropertiesByObject allKeys])
	{
		[_updatedPropertiesByObject removeObjectForKey: obj];
	}
}

- (void)commitWithMetadata: (NSDictionary *)metadata
{
	NSMapTable *insertedObjectsByRoot = [self insertedObjectsByRootObject];
	NSMapTable *updatedObjectsByRoot = [self updatedObjectsByRootObject];
	NSSet *rootObjects = [NSSet setWithArray: [[[insertedObjectsByRoot keyEnumerator] allObjects] 
		arrayByAddingObjectsFromArray: [[updatedObjectsByRoot keyEnumerator] allObjects]]];

	NSMutableSet *insertedRootObjectUUIDs = [NSMutableSet setWithSet: (id)[[_insertedObjects mappedCollection] UUID]];
	[insertedRootObjectUUIDs intersectSet: (id)[[rootObjects mappedCollection] UUID]];
	[_store insertRootObjectUUIDs: insertedRootObjectUUIDs];

	// TODO: Add a batch commit UUID in the metadata
	for (COObject *rootObject in rootObjects)
	{
		NSSet *insertedObjectSubset = [insertedObjectsByRoot objectForKey: rootObject];
		NSMapTable *updatedPropertySubset = [self updatedPropertySubsetForObjects: 
			[updatedObjectsByRoot objectForKey: rootObject]];

		[self commitWithMetadata: metadata 
		              rootObject: rootObject
		         insertedObjects: (insertedObjectSubset != nil ? insertedObjectSubset : [NSSet set])
		       updatedProperties: updatedPropertySubset];
	}
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

- (CORevision *)revisionForObject: (COObject *)object
{
	COObject *rootObject = [object rootObject];
	return [_rootObjectRevisions objectForKey: [rootObject UUID]];
}

- (COCommitTrack *)commitTrackForObject: (COObject *)object
{
	ETUUID *rootObjectUUID = [[object rootObject] UUID];
	COCommitTrack *commitTrack = [_rootObjectCommitTracks objectForKey: rootObjectUUID];

	if (nil == commitTrack)
	{
		commitTrack = [COCommitTrack commitTrackForObject: [object rootObject]];
		[_rootObjectCommitTracks setObject: commitTrack 
		                            forKey: rootObjectUUID];
	}
	return commitTrack;
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
		aRevision = [self revisionForObject: obj];
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

- (void)reloadRootObjectTree: (COObject *)rootObject atRevision: (CORevision *)revision
{
	ETUUID *rootObjectUUID = [rootObject UUID];
	//CORevision *oldRevision = [_rootObjectRevisions objectForKey: rootObjectUUID];
	[_rootObjectRevisions removeObjectForKey: rootObjectUUID];
	[_rootObjectRevisions setObject: revision forKey: rootObjectUUID];

	// FIXME: Optimise for undo/redo cases (revisions next to each other)
	
	// Case 1: unrelated revisions
	// This part is somewhat tricky. We need to reload all sub-objects
	// that already exist in the context, and we ought to get rid of all
	// subobjects that are no longer in use. Objects that exist in the 
	// new revision but were not part of the old revision tree should
	// automatically be faulted in (I think).

	// All objects in all revisions
	NSSet *allIDs = [_store UUIDsForRootObjectUUID: rootObjectUUID];

	// Objects needed in this revision
	NSSet *neededIDs = [_store UUIDsForRootObjectUUID: rootObjectUUID atRevision: revision];

	// Loaded objects in editing context
	NSMutableSet *loadedIDs = [NSMutableSet setWithSet: allIDs];
	[loadedIDs intersectSet: [NSSet setWithArray: [_instantiatedObjects allKeys]]];

	// Needed and already loaded objects in editing context
	NSMutableSet *neededAndLoadedIDs = [NSMutableSet setWithSet: neededIDs];
	[neededAndLoadedIDs intersectSet: loadedIDs];

	// Loaded objects to be unloaded
	NSMutableSet *unwantedIDs = [NSMutableSet setWithSet: loadedIDs];
	[unwantedIDs minusSet: neededIDs];

	FOREACH(neededAndLoadedIDs, uuid, ETUUID*)
	{
		[self loadObject: [_instantiatedObjects objectForKey: uuid] atRevision: revision];
	}

	FOREACH(unwantedIDs, uuid, ETUUID*)
	{
		[_instantiatedObjects removeObjectForKey: uuid];
	}
	
	// As you can see, we haven't removed objects that are "dangling". There
	// might be an advantage to this, but most likely not. Its quite hard (we
	// have to search the whole object tree for references or use the store
	// to get the set of object ids in each revision and minus the sets) so
	// I couldn't be bothered right now. May in fact be easiest to dispose of
	// the editing context and reload it.

	// Case 2: [revision baseRevision] == oldRevision (redo)

	// Case 3: [oldRevision baseRevision] == revision (undo)
}

@end
