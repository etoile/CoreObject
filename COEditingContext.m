#import "COEditingContext.h"
#import "COPersistentRootEditingContext.h"
#import "COError.h"
#import "COObject.h"
#import "COGroup.h"
#import "COStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COEditingContext

+ (COEditingContext *)contextWithURL: (NSURL *)aURL
{
	// TODO: Look up the store class based on the URL scheme and path extension
	COEditingContext *ctx = [[self alloc] initWithStore:
		[[[NSClassFromString(@"COSQLStore") alloc] initWithURL: aURL] autorelease]];
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
	_latestRevisionNumber = [_store latestRevisionNumber];
	_modelRepository = [[ETModelDescriptionRepository mainRepository] retain];
	_persistentRootContexts = [NSMutableDictionary new];
	_loadedObjects = [NSMutableDictionary new];

	[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
	                                                    selector: @selector(didMakeCommit:) 
	                                                        name: COEditingContextDidCommitNotification 
	                                                      object: nil];

	return self;
}

- (id)init
{
	return [self initWithStore: nil];
}

- (void)dealloc
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self];

	DESTROY(_store);
	DESTROY(_modelRepository);
	DESTROY(_persistentRootContexts);
	DESTROY(_loadedObjects);
	DESTROY(_error);
	[super dealloc];
}

/* Handles distributed notifications about new revisions to refresh the root 
object graphs present in memory, for which changes have been committed to the 
store by other processes. */
- (void)didMakeCommit: (NSNotification *)notif
{
	NSNumber *revNumber = [[[notif userInfo] objectForKey: kCORevisionNumbersKey] lastObject];
	// TODO: Take in account the editing context max revision number
	BOOL isOurCommit = ([[[_store UUID] stringValue] isEqual: [notif object]]
		&& (_latestRevisionNumber == [revNumber longLongValue]));

	if (isOurCommit)
		return;

	for (NSNumber *revNumber in [[notif userInfo] objectForKey: kCORevisionNumbersKey])
	{
		CORevision *rev = [_store revisionWithRevisionNumber: [revNumber unsignedLongLongValue]];
		ETUUID *rootObjectUUID = [rev objectUUID];

		if ([self loadedObjectForUUID: rootObjectUUID] == nil)
		{
			continue;
		}

		COObject *rootObject = [self objectWithUUID: rootObjectUUID];

		[[rootObject editingContext] reloadAtRevision: rev];
	}
}

- (COSmartGroup *)mainGroup
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

- (COStore *)store
{
	return _store;
}

- (int64_t)latestRevisionNumber
{
	return _latestRevisionNumber;
}

- (void)setLatestRevisionNumber: (int64_t)revNumber
{
	_latestRevisionNumber = revNumber;
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

// NOTE: Persistent root insertion or deletion are saved to the store at commit time.

- (COPersistentRootEditingContext *)makePersistentRootContextWithRootObject: (COObject *)aRootObject
{
	COPersistentRootEditingContext *ctxt =
	[[COPersistentRootEditingContext alloc] initWithPersistentRootUUID: [ETUUID UUID]
													   commitTrackUUID: nil
															rootObject: aRootObject
														 parentContext: self];
	[_persistentRootContexts setObject: ctxt forKey: [ctxt persistentRootUUID]];
	[ctxt release];
	return ctxt;
}

- (COPersistentRootEditingContext *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName
{
	return [self insertObjectWithEntityName: anEntityName];
}

- (COPersistentRootEditingContext *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject
{
	return [self makePersistentRootContextWithRootObject: aRootObject];
}

- (void)deletePersistentRootForRootObject: (COObject *)aRootObject
{
	COPersistentRootEditingContext *context = [aRootObject editingContext];

	[self discardLoadedObjectsForPersistentRootContexts: S(context)];
	[_persistentRootContexts removeObjectForKey: [context persistentRootUUID]];
}

- (NSString *)entityNameForObjectUUID: (ETUUID *)obj
{
	int64_t maxNum = (_maxRevisionNumber > 0 ? _maxRevisionNumber : [_store latestRevisionNumber]);

	for (int64_t revNum = maxNum; revNum > 0; revNum--)
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
	// NOTE: We serialize UUIDs into strings in various places, this check 
	// helps to intercept string objects that ought to be ETUUID objects.
	NSParameterAssert([uuid isKindOfClass: [ETUUID class]]);

	COObject *result = [_loadedObjects objectForKey: uuid];

	if (result != nil && revision != nil)
	{
		CORevision *existingRevision = [result revision];
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
				NSArray *revisionNodes = [_store revisionsForTrackUUID: rootUUID
				                                      currentNodeIndex: NULL
				                                         backwardLimit: 0
				                                          forwardLimit: 0];
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
		COPersistentRootEditingContext *ctxt = (id)[rootObject editingContext];
		result = [cls alloc];
		
		if (rootObject == nil)
		{
			ctxt = [self makePersistentRootContextWithRootObject: result];
		}
		
		ETAssert(ctxt != nil);

		result = [result
			     initWithUUID: uuid
			entityDescription: desc
			       rootObject: rootObject
				  context: (id)ctxt
				  isFault: YES];
		
		if (isRoot)
		{
			[ctxt setRevision: revision];
		}
		[_loadedObjects setObject: result forKey: uuid];
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

- (void)discardLoadedObjectForUUID: (ETUUID *)aUUID
{
	[_loadedObjects removeObjectForKey: aUUID];
}

/* Remove from the cache all the objects that belong to discarded persistent roots */
- (void)discardLoadedObjectsForPersistentRootContexts: (NSSet *)removedPersistentRootContexts
{
	for (COObject *obj in [self loadedObjects])
	{
		if ([removedPersistentRootContexts containsObject: [obj editingContext]])
		{
			[self discardLoadedObjectForUUID: [obj UUID]];
		}
	}
}

// NOTE: We could rewrite it using -foldWithBlock: or -leftFold (could be faster)
- (NSSet *)setByCollectingObjectsFromPersistentRootsUsingSelector: (SEL)aSelector
{
	NSMutableSet *collectedObjects = [NSMutableSet set];

	for (COPersistentRootEditingContext *context in [_persistentRootContexts objectEnumerator])
	{
		[collectedObjects unionSet: [context performSelector: aSelector]];
	}
	return collectedObjects;
}

- (NSSet *)insertedObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(insertedObjects)];
}

- (NSSet *)updatedObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(insertedObjects)];
}

- (NSSet *)updatedObjectUUIDs
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(updatedObjectUUIDs)];
}

- (BOOL)isUpdatedObject: (COObject *)anObject
{
	return [[self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(updatedObjects)] containsObject: anObject];
}

- (NSSet *)deletedObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(deletedObjects)];
}

- (NSSet *)changedObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(changedObjects)];
}

- (BOOL)hasChanges
{
	for (COPersistentRootEditingContext *context in [_persistentRootContexts objectEnumerator])
	{
		if ([context hasChanges])
			return YES;
	}
	return NO;
}

- (void)discardAllChanges
{
	NSMutableSet *removedPersistentRootContexts = [NSMutableSet set];

	/* Discard changes in persistent roots and collect discarded persistent roots */
	for (ETUUID *uuid in _persistentRootContexts)
	{
		COPersistentRootEditingContext *context = [_persistentRootContexts objectForKey: uuid];

		if ([context revision] != nil)
		{
			[context discardAllChanges];
		}
		else
		{
			[removedPersistentRootContexts addObject: context];
		}
	}

	[self discardLoadedObjectsForPersistentRootContexts: removedPersistentRootContexts];

	/* Release the discarded persistent roots */
	[_persistentRootContexts removeObjectsForKeys:
		(id)[[[removedPersistentRootContexts allObjects] mappedCollection] persistentRootUUID]];

	assert([self hasChanges] == NO);
}

- (void)discardChangesInObject: (COObject *)object
{
	[[object editingContext] discardChangesInObject: object];
}

- (void)cacheLoadedObject: (COObject *)object
{
	[_loadedObjects setObject: object forKey: [object UUID]];
}

- (COObject *)insertObjectWithEntityName: (NSString *)aFullName 
                                    UUID: (ETUUID *)aUUID 
                              rootObject: (COObject *)rootObject
{

	ETEntityDescription *desc = [_modelRepository descriptionForName: aFullName];
	if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	
	Class cls = [self classForEntityDescription: desc];
	COPersistentRootEditingContext *ctxt = (id)[rootObject editingContext];
	COObject *result = [cls alloc];

	if (rootObject == nil)
	{
		ctxt = [self makePersistentRootContextWithRootObject: nil];
	}

	ETAssert(ctxt != nil);
	
	/* Nil root object means the new object will be a root */
	result = [result
		     initWithUUID: aUUID
		entityDescription: desc
		       rootObject: rootObject
		          context: (id)ctxt
		          isFault: NO];
	[result becomePersistentInContext: (id)ctxt rootObject: (rootObject != nil ? rootObject : result)];
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
	COPersistentRootEditingContext *sourceContext = [sourceObject editingContext];
	ETAssert(sourceContext != nil);
	/* See -[COObject becomePersistentInContext:rootObject:] */
	BOOL isBecomingPersistent = (newUUID == NO && [_persistentRootContexts containsObject: sourceContext]);

	/* Source object was not persistent until then
	   
	   So we don't want to create a new instance, but just register it */

	// FIXME: This code looks dubious. Why not use -becomePersistentInContext:rootObject:...
	if (isBecomingPersistent)
	{
		[sourceContext registerObject: sourceObject];
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

- (COPersistentRootEditingContext *)makePersistentRootContext
{
	COPersistentRootEditingContext *ctxt =
		[[COPersistentRootEditingContext alloc] initWithPersistentRootUUID: [ETUUID UUID]
														   commitTrackUUID: nil
																rootObject: nil
															 parentContext: self];
	[_persistentRootContexts setObject: ctxt forKey: [ctxt persistentRootUUID]];
	[ctxt release];
	return ctxt;
}

- (void)deleteObject: (COObject *)anObject
{
	[[anObject editingContext] deleteObject: anObject];
}

- (NSArray *)commit
{
	return [self commitWithType: nil shortDescription: nil longDescription: nil];
}

- (NSArray *)commitWithType: (NSString*)type
           shortDescription: (NSString*)shortDescription
            longDescription: (NSString*)longDescription
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
	if (longDescription == nil)
	{
		longDescription = @"";
	}
	return [self commitWithMetadata: D(shortDescription, @"shortDescription", 
		longDescription, @"longDescription", commitType, @"type")];
}

- (NSArray *)commitWithType: (NSString *)type
           shortDescription: (NSString *)shortDescription
{
	return [self commitWithType: type shortDescription: shortDescription longDescription: nil];
}

- (void)postCommitNotificationsWithRevisions: (NSArray *)revisions
{
	NSDictionary *notifInfos = D(revisions, kCORevisionsKey);

	[[NSNotificationCenter defaultCenter] postNotificationName: COEditingContextDidCommitNotification 
	                                                    object: self 
	                                                  userInfo: notifInfos];

	NSMutableArray *revNumbers = [NSMutableArray array];
	for (CORevision *rev in revisions)
	{
		[revNumbers addObject: [NSNumber numberWithUnsignedLong: [rev revisionNumber]]];
	}
	notifInfos = D(revNumbers, kCORevisionNumbersKey);

#ifndef GNUSTEP
	[(id)[NSDistributedNotificationCenter defaultCenter] postNotificationName: COEditingContextDidCommitNotification 
	                                                               object: [[[self store] UUID] stringValue]
	                                                             userInfo: notifInfos
	                                                   deliverImmediately: YES];
#endif
}

- (BOOL)validateChangedObjects
{
	NSSet *insertionErrors = (id)[[[self insertedObjects] mappedCollection] validateForInsert];
	NSSet *updateErrors = (id)[[[self updatedObjects] mappedCollection] validateForUpdate];
	NSSet *deletionErrors = (id)[[[self deletedObjects] mappedCollection] validateForDelete];
	NSMutableSet *validationErrors = [NSMutableSet setWithSet: insertionErrors];
	
	[validationErrors unionSet: updateErrors];
	[validationErrors unionSet: deletionErrors];

	// NOTE: We have a null value because -validateXXX returns nil on validation success
	[validationErrors removeObject: [NSNull null]];

	ASSIGN(_error, [COError errorWithErrors: validationErrors]);

	return (_error == nil);
}

- (NSArray *)commitWithMetadata: (NSDictionary *)metadata
{
	// TODO: Enable validation
	if ([self validateChangedObjects] == NO)
		return [NSArray array];

	NSMutableArray *revisions = [NSMutableArray array];

	// TODO: Add a batch commit UUID in the metadata
	for (COPersistentRootEditingContext *ctxt in [_persistentRootContexts objectEnumerator])
	{
		[revisions addObject: [ctxt commitWithMetadata: metadata]];
	}

 	[self postCommitNotificationsWithRevisions: revisions];
	return revisions;
}

- (NSError *)error
{
	return _error;
}

@end

NSString *COEditingContextDidCommitNotification = @"COEditingContextDidCommitNotification";

NSString *kCORevisionNumbersKey = @"kCORevisionNumbersKey";
NSString *kCORevisionsKey = @"kCORevisionsKey";
