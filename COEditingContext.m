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
		COGroup *newGroup = [[self insertNewPersistentRootWithEntityName: @"Anonymous.COGroup"] rootObject];
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

- (COPersistentRootEditingContext *)contextForPersistentRootUUID: (ETUUID *)aUUID
{
	return [_persistentRootContexts objectForKey: aUUID];
}

// NOTE: Persistent root insertion or deletion are saved to the store at commit time.

- (COPersistentRootEditingContext *)makePersistentRootContextWithRootObject: (COObject *)aRootObject
{
	COPersistentRootEditingContext *ctxt =
		[[COPersistentRootEditingContext alloc] initWithPersistentRootUUID: [ETUUID UUID]
														   commitTrackUUID: [ETUUID UUID]
																rootObject: aRootObject
															 parentContext: self];
	[_persistentRootContexts setObject: ctxt forKey: [ctxt persistentRootUUID]];
	[ctxt release];
	return ctxt;
}

- (COPersistentRootEditingContext *)makePersistentRootContext
{
	return [self makePersistentRootContextWithRootObject: nil];
}

- (COPersistentRootEditingContext *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName
{
	COPersistentRootEditingContext *context = [self makePersistentRootContextWithRootObject: nil];
	ETEntityDescription *desc = [[self modelRepository] descriptionForName: anEntityName];
	Class cls = [self classForEntityDescription: desc];
	COObject *rootObject = [[cls alloc]
			  initWithUUID: [ETUUID UUID]
			  entityDescription: desc
			  rootObject: nil
			  context: (id)context
			  isFault: NO];

	/* Will set the root object on the persistent root context */
	[rootObject becomePersistentInContext: context];

	return context;
}

- (id)insertObjectWithEntityName: (NSString *)anEntityName
{
	return [[self insertNewPersistentRootWithEntityName: anEntityName] rootObject];
}

- (COPersistentRootEditingContext *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject
{
	// FIXME: COObjectGraphDiff prevents us to detect an invalid root object...
	//NILARG_EXCEPTION_TEST(aRootObject);
	COPersistentRootEditingContext *context = [self makePersistentRootContextWithRootObject: aRootObject];
	[aRootObject becomePersistentInContext: context];
	return context;
}

- (void)deletePersistentRootForRootObject: (COObject *)aRootObject
{
	COPersistentRootEditingContext *context = [aRootObject editingContext];

	[self discardLoadedObjectsForPersistentRootContexts: S(context)];
	[_persistentRootContexts removeObjectForKey: [context persistentRootUUID]];
}

- (void)registerObject: (COObject *)object
{
	NILARG_EXCEPTION_TEST(object);
	INVALIDARG_EXCEPTION_TEST(object, [_loadedObjects containsObject: object] == NO);
	[self insertNewPersistentRootWithRootObject: object];
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
		ETUUID *rootUUID = [_store rootObjectUUIDForObjectUUID: uuid];
		ETAssert(rootUUID != nil);
		BOOL isRoot = [rootUUID isEqual: uuid];
		id rootObject = nil;
		CORevision *maxRevision = nil;

		if (isRoot)
		{
			if (nil == revision)
			{
				ETUUID *persistentRootUUID = [_store persistentRootUUIDForRootObjectUUID: rootUUID];
				ETUUID *trackUUID = [_store mainBranchUUIDForPersistentRootUUID: persistentRootUUID];
				NSArray *revisionNodes = [_store revisionsForTrackUUID: trackUUID
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

- (void)cacheLoadedObject: (COObject *)object
{
	[_loadedObjects setObject: object forKey: [object UUID]];
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

- (NSArray *)commit
{
	return [self commitWithType: nil shortDescription: nil];
}

- (NSArray *)commitWithType: (NSString *)type
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

- (void)didFailValidationWithError: (COError *)anError
{
	ASSIGN(_error, anError);
}

- (BOOL)validateChangedObjectsForContext: (id)aContext
{
	NSSet *insertionErrors = (id)[[[aContext insertedObjects] mappedCollection] validateForInsert];
	NSSet *updateErrors = (id)[[[aContext updatedObjects] mappedCollection] validateForUpdate];
	NSSet *deletionErrors = (id)[[[aContext deletedObjects] mappedCollection] validateForDelete];
	NSMutableSet *validationErrors = [NSMutableSet setWithSet: insertionErrors];
	
	[validationErrors unionSet: updateErrors];
	[validationErrors unionSet: deletionErrors];

	// NOTE: We have a null value because -validateXXX returns nil on validation success
	[validationErrors removeObject: [NSNull null]];

	[aContext didFailValidationWithError: [COError errorWithErrors: validationErrors]];

	return ([aContext error] == nil);
}

- (NSArray *)commitWithMetadata: (NSDictionary *)metadata
	restrictedToPersistentRootContexts: (NSArray *)persistentRootContexts
{
	// TODO: We could organize validation errors by persistent root. Each
	// persistent root might result in a validation error that contains a
	// suberror per inner object, then each suberror could in turn contain
	// a suberror per validation result. For now, we just aggregate errors per
	// inner object.
	if ([self validateChangedObjectsForContext: self] == NO)
		return [NSArray array];

	NSMutableArray *revisions = [NSMutableArray array];

	// TODO: Add a batch commit UUID in the metadata
	for (COPersistentRootEditingContext *ctxt in persistentRootContexts)
	{
		[revisions addObject: [ctxt saveCommitWithMetadata: metadata]];
		_latestRevisionNumber = [[revisions lastObject] revisionNumber];
	}

 	[self postCommitNotificationsWithRevisions: revisions];
	return revisions;
}

- (NSArray *)commitWithMetadata: (NSDictionary *)metadata
{
	return [self commitWithMetadata: metadata
		restrictedToPersistentRootContexts: [_persistentRootContexts allValues]];
}

- (NSError *)error
{
	return _error;
}

@end

NSString *COEditingContextDidCommitNotification = @"COEditingContextDidCommitNotification";

NSString *kCORevisionNumbersKey = @"kCORevisionNumbersKey";
NSString *kCORevisionsKey = @"kCORevisionsKey";
