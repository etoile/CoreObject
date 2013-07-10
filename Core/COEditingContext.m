#import "COEditingContext.h"
#import "COLibrary.h"
#import "COPersistentRoot.h"
#import "COError.h"
#import "COObject.h"
#import "COGroup.h"
#import "COSQLiteStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COEditingContext

@synthesize deletedPersistentRoots = _deletedPersistentRoots;

+ (COEditingContext *)contextWithURL: (NSURL *)aURL
{
	// TODO: Look up the store class based on the URL scheme and path extension
	COEditingContext *ctx = [[self alloc] initWithStore:
		[[[NSClassFromString(@"COSQLiteStore") alloc] initWithURL: aURL] autorelease]];
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

- (void)registerAdditionalEntityDescriptions
{
	NSSet *entityDescriptions = [COLibrary additionalEntityDescriptions];

	for (ETEntityDescription *entity in entityDescriptions)
	{
		if ([[self modelRepository] descriptionForName: [entity fullName]] != nil)
			continue;
			
		[[self modelRepository] addUnresolvedDescription: entity];
	}
	[[self modelRepository] resolveNamedObjectReferences];
}

- (id)initWithStore: (COSQLiteStore *)store
{
	SUPERINIT;

	_uuid = [ETUUID new];
	ASSIGN(_store, store);
	_modelRepository = [[ETModelDescriptionRepository mainRepository] retain];
	_loadedPersistentRoots = [NSMutableDictionary new];
	_deletedPersistentRoots = [NSMutableSet new];

	[self registerAdditionalEntityDescriptions];

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

- (NSString *)description
{
	NSMutableDictionary *changeSummary = [NSMutableDictionary dictionary];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		if ([persistentRoot hasChanges] == NO)
			continue;
		
		[changeSummary setObject: [persistentRoot description]
		                  forKey: [persistentRoot persistentRootUUID]];
	}

	/* For Mac OS X, see http://www.cocoabuilder.com/archive/cocoa/197297-who-broke-nslog-on-leopard.html */
	NSString *desc = [changeSummary description];
	desc = [desc stringByReplacingOccurrencesOfString: @"\\n" withString: @"\n"];
	desc = [desc stringByReplacingOccurrencesOfString: @"\\\"" withString: @""];
	return desc;
}

- (BOOL)isEditingContext
{
	return YES;
}

- (COEditingContext *)editingContext
{
	return self;
}

/* Handles distributed notifications about new revisions to refresh the root 
object graphs present in memory, for which changes have been committed to the 
store by other processes. */
- (void)didMakeCommit: (NSNotification *)notif
{
    // FIXME: Re-enable
#if 0
	// TODO: Write a test to ensure other store notifications are not handled
	BOOL isOtherStore = ([[[_store UUID] stringValue] isEqual: [notif object]] == NO);

	if (isOtherStore)
		return;

	// TODO: Take in account the editing context max revision number
	ETUUID *posterUUID = [ETUUID UUIDWithString: [[notif userInfo] objectForKey: kCOEditingContextUUIDKey]];
	BOOL isOurCommit = [_uuid isEqual: posterUUID];

	if (isOurCommit)
		return;

	for (NSNumber *revNumber in [[notif userInfo] objectForKey: kCORevisionNumbersKey])
	{
		CORevision *rev = [_store revisionWithRevisionNumber: [revNumber unsignedLongLongValue]];
		// TODO: We should get the persistent root UUID from the notification
		ETUUID *persistentRootUUID = [_store persistentRootUUIDForRootObjectUUID: [rev objectUUID]];
		COPersistentRoot *persistentRoot = [_loadedPersistentRoots objectForKey: persistentRootUUID];

		[persistentRoot reloadAtRevision: rev];
	}
#endif
}

- (COSmartGroup *)mainGroup
{
    return nil; // FIXME: Rewrite
#if 0
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
#endif
}

- (COGroup *)libraryGroup
{
    return nil; // FIXME: Rewrite
#if 0
	NSString *UUIDString = [[_store metadata] objectForKey: @"kCOLibraryGroupUUID"];

	if (UUIDString == nil)
	{
		COGroup *newGroup = [[self insertNewPersistentRootWithEntityName: @"Anonymous.COGroup"] rootObject];
		NSMutableDictionary *metadata = AUTORELEASE([[_store metadata] mutableCopy]);

		[newGroup setName: _(@"Libraries")];
		[metadata setObject: [[newGroup UUID] stringValue] 
		             forKey: @"kCOLibraryGroupUUID"];
		[_store setMetadata: metadata];
		
		[newGroup addObjects: A([self tagLibrary], [self bookmarkLibrary],
			[self noteLibrary], [self photoLibrary], [self musicLibrary])];
	
		return newGroup;
	}

	return (id)[self objectWithUUID: [ETUUID UUIDWithString: UUIDString]];
#endif
}

- (COSQLiteStore *)store
{
	return _store;
}

- (ETModelDescriptionRepository *)modelRepository
{
	return _modelRepository; 
}

- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)persistentRootUUID
{
	return [self persistentRootForUUID: persistentRootUUID atRevision: nil];
}

// FIXME: Ugly semantics; ignores revision if the persistent root is already
// loaded
- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)persistentRootUUID
                                 atRevision: (CORevision *)revision
{
	COPersistentRoot *persistentRoot = [_loadedPersistentRoots objectForKey: persistentRootUUID];
	
	if (persistentRoot != nil)
		return persistentRoot;

    COPersistentRootInfo *info = [_store persistentRootWithUUID: persistentRootUUID];
        
	BOOL persistentRootFound = (info != nil);

	if (persistentRootFound == NO)
		return nil;

	persistentRoot = [self makePersistentRootWithInfo: info];

	return persistentRoot;
}

// NOTE: Persistent root insertion or deletion are saved to the store at commit time.

- (COPersistentRoot *)makePersistentRootWithInfo: (COPersistentRootInfo *)info
{
    if (info != nil)
    {
        NSParameterAssert(nil == [_loadedPersistentRoots objectForKey: [info UUID]]);
    }
    
	COPersistentRoot *persistentRoot = [[COPersistentRoot alloc] initWithInfo: info
                                                                parentContext: self];
	[_loadedPersistentRoots setObject: persistentRoot
							   forKey: [persistentRoot persistentRootUUID]];
	[persistentRoot release];
	return persistentRoot;
}

- (COPersistentRoot *)makePersistentRoot
{
    return [self makePersistentRootWithInfo: nil];
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
	COPersistentRoot *persistentRoot = [self makePersistentRoot];

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
	COPersistentRoot *persistentRoot = [self makePersistentRootWithInfo: nil];
	[aRootObject becomePersistentInContext: persistentRoot];
	return persistentRoot;
}

- (void)deletePersistentRootForRootObject: (COObject *)aRootObject
{
	// NOTE: Deleted persistent roots are removed from the cache on commit.
	[_deletedPersistentRoots addObject: [aRootObject persistentRoot]];
}

- (NSSet *)loadedObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(loadedObjects)];
}

- (NSSet *)loadedRootObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(loadedRootObjects)];
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

	/* Remove from the cache all the objects that belong to discarded persistent roots */
	[(COPersistentRoot *)[insertedPersistentRoots mappedCollection] unload];

	/* Release the discarded persistent roots */
	[_loadedPersistentRoots removeObjectsForKeys:
		(id)[[[insertedPersistentRoots allObjects] mappedCollection] persistentRootUUID]];

	assert([self hasChanges] == NO);
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
    // FIXME: Re-enable
#if 0
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
#endif
}

- (void)didCommitRevision: (CORevision *)aRevision
{
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
		[self didCommitRevision: [revisions lastObject]];
	}
	
	/* Record persistent root deletions at the store level */
	
	for (COPersistentRoot *persistentRoot in persistentRoots)
	{
		BOOL isDeleted = [_deletedPersistentRoots containsObject: persistentRoot];
		
		if (isDeleted == NO)
			continue;
		
		ETUUID *uuid = [persistentRoot persistentRootUUID];
		[_store deletePersistentRoot: uuid];

		[persistentRoot unload];
		[_loadedPersistentRoots removeObjectForKey: uuid];
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
