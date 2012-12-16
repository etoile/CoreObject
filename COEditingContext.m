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
		ETUUID *persistentRootUUID = [_store persistentRootUUIDForRootObjectUUID: rootObjectUUID];
		COPersistentRootEditingContext *persistentRoot = [_persistentRootContexts objectForKey: persistentRootUUID];

		if ([persistentRoot loadedObjectForUUID: rootObjectUUID] == nil)
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

- (int64_t)maxRevisionNumber
{
	return _maxRevisionNumber;
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
														 persistentRootUUID: (ETUUID *)aPersistentRootUUID
															commitTrackUUID: (ETUUID *)aTrackUUID
{
	COPersistentRootEditingContext *ctxt =
		[[COPersistentRootEditingContext alloc] initWithPersistentRootUUID: aPersistentRootUUID
														   commitTrackUUID: aTrackUUID
																rootObject: aRootObject
															 parentContext: self];
	[_persistentRootContexts setObject: ctxt forKey: [ctxt persistentRootUUID]];
	[ctxt release];
	return ctxt;
}

- (COPersistentRootEditingContext *)makePersistentRootContextWithRootObject: (COObject *)aRootObject
{
	return [self makePersistentRootContextWithRootObject: aRootObject persistentRootUUID: [ETUUID UUID] commitTrackUUID: [ETUUID UUID]];
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

- (COObject *)objectWithUUID: (ETUUID *)uuid entityName: (NSString *)name atRevision: (CORevision *)revision
{
	// NOTE: We could resolve the root object at loading time, but since 
	// it's going to should be available in memory, we rather resolve it now.
	ETUUID *rootUUID = [_store rootObjectUUIDForObjectUUID: uuid];
	BOOL isCommitted = (rootUUID != nil);
	
	// TODO: Remove
	if (isCommitted == NO)
	{
		COObject *rootObject = nil;

		for (COPersistentRootEditingContext *persistentRoot in [_persistentRootContexts objectEnumerator])
		{
			rootObject = [persistentRoot objectWithUUID: uuid entityName: name atRevision: revision];
			if (rootObject != nil)
			{
				break;
			}
		}
		return rootObject;
	}

	ETUUID *persistentRootUUID = [_store persistentRootUUIDForRootObjectUUID: rootUUID];
	COPersistentRootEditingContext *persistentRoot = [self contextForPersistentRootUUID: persistentRootUUID];

	if (persistentRoot == nil)
	{
		ETUUID *trackUUID = [_store mainBranchUUIDForPersistentRootUUID: persistentRootUUID];

		persistentRoot = [self makePersistentRootContextWithRootObject: nil
											        persistentRootUUID: persistentRootUUID
												       commitTrackUUID: trackUUID];
		[persistentRoot setRootObject: [persistentRoot objectWithUUID: uuid atRevision: revision]];
	}
	
	return [persistentRoot objectWithUUID: uuid entityName: name atRevision: revision];
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
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(loadedObjects)];
}

- (NSSet *)loadedRootObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(loadedRootObjects)];
}

/* Remove from the cache all the objects that belong to discarded persistent roots */
- (void)discardLoadedObjectsForPersistentRootContexts: (NSSet *)removedPersistentRootContexts
{
	for (COObject *obj in [self loadedObjects])
	{
		if ([removedPersistentRootContexts containsObject: [obj editingContext]])
		{
			[[obj editingContext] discardLoadedObjectForUUID: [obj UUID]];
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
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(updatedObjects)];
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
