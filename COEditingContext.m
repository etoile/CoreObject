#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COError.h"
#import "COObject.h"
#import "COGroup.h"
#import "COStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COEditingContext

@synthesize deletedPersistentRoots;

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

	_uuid = [ETUUID new];
	ASSIGN(_store, store);
	_maxRevisionNumber = maxRevisionNumber;	
	_latestRevisionNumber = [_store latestRevisionNumber];
	_modelRepository = [[ETModelDescriptionRepository mainRepository] retain];
	_loadedPersistentRoots = [NSMutableDictionary new];
	_deletedPersistentRoots = [NSMutableSet new];

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

	DESTROY(_uuid);
	DESTROY(_store);
	DESTROY(_modelRepository);
	DESTROY(_loadedPersistentRoots);
	DESTROY(_deletedPersistentRoots);
	DESTROY(_error);
	[super dealloc];
}

/* Handles distributed notifications about new revisions to refresh the root 
object graphs present in memory, for which changes have been committed to the 
store by other processes. */
- (void)didMakeCommit: (NSNotification *)notif
{
	// TODO: Take in account the editing context max revision number
	ETUUID *posterUUID = [ETUUID UUIDWithString: [[notif userInfo] objectForKey: kCOEditingContextUUIDKey]];
	BOOL isOurCommit = [_uuid isEqual: posterUUID];

	if (isOurCommit)
		return;

	for (NSNumber *revNumber in [[notif userInfo] objectForKey: kCORevisionNumbersKey])
	{
		CORevision *rev = [_store revisionWithRevisionNumber: [revNumber unsignedLongLongValue]];
		ETUUID *rootObjectUUID = [rev objectUUID];
		ETUUID *persistentRootUUID = [_store persistentRootUUIDForRootObjectUUID: rootObjectUUID];
		COPersistentRoot *persistentRoot = [_loadedPersistentRoots objectForKey: persistentRootUUID];

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

- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)aUUID
{
	return [_loadedPersistentRoots objectForKey: aUUID];
}

// NOTE: Persistent root insertion or deletion are saved to the store at commit time.

- (COPersistentRoot *)makePersistentRootWithRootObject: (COObject *)aRootObject
                                    persistentRootUUID: (ETUUID *)aPersistentRootUUID
                                       commitTrackUUID: (ETUUID *)aTrackUUID
{
	COPersistentRoot *persistentRoot =
		[[COPersistentRoot alloc] initWithPersistentRootUUID: aPersistentRootUUID
		                                     commitTrackUUID: aTrackUUID
		                                       parentContext: self];
	[_loadedPersistentRoots setObject: persistentRoot
							   forKey: [persistentRoot persistentRootUUID]];
	[persistentRoot release];
	return persistentRoot;
}

- (COPersistentRoot *)makePersistentRootWithRootObject: (COObject *)aRootObject
{
	return [self makePersistentRootWithRootObject: aRootObject
	                           persistentRootUUID: [ETUUID UUID]
	                              commitTrackUUID: [ETUUID UUID]];
}

- (COPersistentRoot *)makePersistentRoot
{
	return [self makePersistentRootWithRootObject: nil];
}

- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName
{
	ETEntityDescription *desc = [[self modelRepository] descriptionForName: anEntityName];
	Class cls = [[self modelRepository] classForEntityDescription: desc];
	COObject *rootObject = [[cls alloc]
							initWithUUID: [ETUUID UUID]
							entityDescription: desc
							context: nil
							isFault: NO];
	COPersistentRoot *persistentRoot = [self makePersistentRootWithRootObject: rootObject];

	/* Will set the root object on the persistent root */
	[rootObject becomePersistentInContext: persistentRoot];

	return persistentRoot;
}

- (NSSet *)insertedPersistentRoots
{
	NSMutableSet *insertedPersistentRoots = [NSMutableSet set];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		if ([persistentRoot revision] == nil)
		{
			[insertedPersistentRoots addObject: persistentRoot];
		}
	}
	return insertedPersistentRoots;
}

- (id)insertObjectWithEntityName: (NSString *)anEntityName
{
	return [[self insertNewPersistentRootWithEntityName: anEntityName] rootObject];
}

- (COPersistentRoot *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject
{
	// FIXME: COObjectGraphDiff prevents us to detect an invalid root object...
	//NILARG_EXCEPTION_TEST(aRootObject);
	COPersistentRoot *persistentRoot = [self makePersistentRootWithRootObject: aRootObject];
	[aRootObject becomePersistentInContext: persistentRoot];
	return persistentRoot;
}

- (void)deletePersistentRootForRootObject: (COObject *)aRootObject
{
	// NOTE: Deleted persistent roots are removed from the cache on commit.
	[_deletedPersistentRoots addObject: [aRootObject editingContext]];
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

		for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
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
	COPersistentRoot *persistentRoot = [self persistentRootForUUID: persistentRootUUID];

	if (persistentRoot == nil)
	{
		ETUUID *trackUUID = [_store mainBranchUUIDForPersistentRootUUID: persistentRootUUID];

		persistentRoot = [self makePersistentRootWithRootObject: nil
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
- (void)discardLoadedObjectsForPersistentRoots: (NSSet *)removedPersistentRoots
{
	for (COObject *obj in [self loadedObjects])
	{
		if ([removedPersistentRoots containsObject: [obj editingContext]])
		{
			[[obj editingContext] discardLoadedObjectForUUID: [obj UUID]];
		}
	}
}

// NOTE: We could rewrite it using -foldWithBlock: or -leftFold (could be faster)
- (NSSet *)setByCollectingObjectsFromPersistentRootsUsingSelector: (SEL)aSelector
{
	NSMutableSet *collectedObjects = [NSMutableSet set];

	for (COPersistentRoot *context in [_loadedPersistentRoots objectEnumerator])
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
	for (COPersistentRoot *context in [_loadedPersistentRoots objectEnumerator])
	{
		if ([context hasChanges])
			return YES;
	}
	return NO;
}

- (void)discardAllChanges
{
	/* Represents persistent roots inserted since the last commit */
	NSSet *insertedPersistentRoots = [self insertedPersistentRoots];

	/* Discard changes in persistent roots and collect discarded persistent roots */
	for (ETUUID *uuid in _loadedPersistentRoots)
	{
		COPersistentRoot *persistentRoot = [_loadedPersistentRoots objectForKey: uuid];
		BOOL isInserted = ([persistentRoot revision] == nil);

		if (isInserted)
			continue;

		[persistentRoot discardAllChanges];
	}

	[self discardLoadedObjectsForPersistentRoots: insertedPersistentRoots];

	/* Release the discarded persistent roots */
	[_loadedPersistentRoots removeObjectsForKeys:
		(id)[[[insertedPersistentRoots allObjects] mappedCollection] persistentRootUUID]];

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
	notifInfos = D(revNumbers, kCORevisionNumbersKey, [_uuid stringValue], kCOEditingContextUUIDKey);

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

/* Both COPersistentRoot or COEditingContext objects are valid arguments. */
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
	restrictedToPersistentRoots: (NSArray *)persistentRoots
{
	// TODO: We could organize validation errors by persistent root. Each
	// persistent root might result in a validation error that contains a
	// suberror per inner object, then each suberror could in turn contain
	// a suberror per validation result. For now, we just aggregate errors per
	// inner object.
	if ([self validateChangedObjectsForContext: self] == NO)
		return [NSArray array];

	NSMutableArray *revisions = [NSMutableArray array];

	/* Commit persistent root changes (deleted persistent roots included) */

	// TODO: Add a batch commit UUID in the metadata
	for (COPersistentRoot *ctxt in persistentRoots)
	{
		[revisions addObject: [ctxt saveCommitWithMetadata: metadata]];
		_latestRevisionNumber = [[revisions lastObject] revisionNumber];
	}
	
	/* Record persistent root deletions at the store level */
	
	for (COPersistentRoot *persistentRoot in persistentRoots)
	{
		BOOL isDeleted = [_deletedPersistentRoots containsObject: persistentRoot];
		
		if (isDeleted == NO)
			continue;
		
		[self discardLoadedObjectsForPersistentRoots: S(persistentRoot)];
		[_loadedPersistentRoots removeObjectForKey: [persistentRoot persistentRootUUID]];
		// TODO: Save the deletion into the store
	}

 	[self postCommitNotificationsWithRevisions: revisions];
	return revisions;
}

- (NSArray *)commitWithMetadata: (NSDictionary *)metadata
{
	return [self commitWithMetadata: metadata
		restrictedToPersistentRoots: [_loadedPersistentRoots allValues]];
}

- (NSError *)error
{
	return _error;
}

@end

NSString *COEditingContextDidCommitNotification = @"COEditingContextDidCommitNotification";

NSString *kCOEditingContextUUIDKey = @"kCOEditingContextUUIDKey";
NSString *kCORevisionNumbersKey = @"kCORevisionNumbersKey";
NSString *kCORevisionsKey = @"kCORevisionsKey";
