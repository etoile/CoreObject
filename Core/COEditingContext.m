/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COEditingContext.h"
#import "COLibrary.h"
#import "COPersistentRoot.h"
#import "COPersistentRoot+Private.h"
#import "COError.h"
#import "COObject.h"
#import "COGroup.h"
#import "COSQLiteStore.h"
#import "CORevision.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "COPath.h"
#import "COObjectGraphContext.h"
#import "COCrossPersistentRootReferenceCache.h"
#import "COUndoStackStore.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "CORevisionCache.h"

@implementation COEditingContext

@synthesize store = _store, modelRepository = _modelRepository;
@synthesize persistentRootsPendingDeletion = _persistentRootsPendingDeletion;
@synthesize persistentRootsPendingUndeletion = _persistentRootsPendingUndeletion;
@synthesize isRecordingUndo = _isRecordingUndo;

+ (COEditingContext *)contextWithURL: (NSURL *)aURL
{
	// TODO: Look up the store class based on the URL scheme and path extension
	return [[self alloc] initWithStore: [[COSQLiteStore alloc] initWithURL: aURL]];
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

	_store =  store;
	_modelRepository = [ETModelDescriptionRepository mainRepository];
	_loadedPersistentRoots = [NSMutableDictionary new];
	_persistentRootsPendingDeletion = [NSMutableSet new];
    _persistentRootsPendingUndeletion = [NSMutableSet new];
    _crossRefCache = [[COCrossPersistentRootReferenceCache alloc] init];
    _isRecordingUndo = YES;

	[CORevisionCache prepareCacheForStore: store];
	[self registerAdditionalEntityDescriptions];


    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootDidChange:)
                                                 name: COStorePersistentRootDidChangeNotification
                                               object: _store];

	[[NSDistributedNotificationCenter defaultCenter] addObserver: self
	                                                    selector: @selector(distributedStorePersistentRootDidChange:)
	                                                        name: COStorePersistentRootDidChangeNotification
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
    [[NSNotificationCenter defaultCenter] removeObserver: self];
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

- (COCrossPersistentRootReferenceCache *) crossReferenceCache
{
    return _crossRefCache;
}

- (NSSet *)persistentRoots
{
	// TODO: Revisit once we introduce persistent root faulting. Assumes all persistent roots are loaded.
    NSMutableSet *persistentRoots = [NSMutableSet set];

    for (ETUUID *uuid in [_store persistentRootUUIDs])
    {
        [persistentRoots addObject: [self persistentRootForUUID: uuid]];
    }
	[persistentRoots unionSet: [self persistentRootsPendingInsertion]];
    [persistentRoots unionSet: _persistentRootsPendingUndeletion];
	[persistentRoots minusSet: _persistentRootsPendingDeletion];
    
    return persistentRoots;
}

- (NSSet *)deletedPersistentRoots
{
    NSMutableSet *result = [NSMutableSet set];
    
    for (ETUUID *uuid in [_store deletedPersistentRootUUIDs])
    {
        [result addObject: [self persistentRootForUUID: uuid]];
    }

    [result minusSet: _persistentRootsPendingUndeletion];
    
    return result;
}

- (COPersistentRoot *)persistentRootForUUID: (ETUUID *)persistentRootUUID
{
	COPersistentRoot *persistentRoot = [_loadedPersistentRoots objectForKey: persistentRootUUID];
	
	if (persistentRoot != nil)
		return persistentRoot;

    COPersistentRootInfo *info = [_store persistentRootInfoForUUID: persistentRootUUID];
        
	BOOL persistentRootFound = (info != nil);

	if (persistentRootFound == NO)
		return nil;

	persistentRoot = [self makePersistentRootWithInfo: info objectGraphContext: nil];

	return persistentRoot;
}

// NOTE: Persistent root insertion or deletion are saved to the store at commit time.

- (COPersistentRoot *)makePersistentRootWithInfo: (COPersistentRootInfo *)info
                              objectGraphContext: (COObjectGraphContext *)anObjectGrapContext
{
    if (info != nil)
    {
        NSParameterAssert(nil == [_loadedPersistentRoots objectForKey: [info UUID]]);
    }
    
    COPersistentRoot *persistentRoot = [[COPersistentRoot alloc] initWithInfo: info
                                                          cheapCopyRevisionID: nil
	                                                       objectGraphContext: anObjectGrapContext
                                                                parentContext: self];
	[_loadedPersistentRoots setObject: persistentRoot
							   forKey: [persistentRoot persistentRootUUID]];
	return persistentRoot;
}

- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName
{
	ETEntityDescription *desc = [[self modelRepository] descriptionForName: anEntityName];
    
    COObjectGraphContext *graph = [COObjectGraphContext objectGraphContext];
    
	Class cls = [[self modelRepository] classForEntityDescription: desc];
	COObject *rootObject = [[cls alloc] initWithUUID: [ETUUID UUID]
                                    entityDescription: desc
                                   objectGraphContext: graph];
	COPersistentRoot *persistentRoot = [self makePersistentRootWithInfo: nil
	                                                 objectGraphContext: [rootObject objectGraphContext]];

	[[rootObject objectGraphContext] setRootObject: rootObject];
    
    ETAssert([[persistentRoot rootObject] isRoot]);
	
    return persistentRoot;
}

- (COPersistentRoot *)insertNewPersistentRootWithRevisionID: (CORevisionID *)aRevid
{
    COPersistentRoot *persistentRoot = [[COPersistentRoot alloc] initWithInfo: nil
                                                          cheapCopyRevisionID: aRevid
	                                                       objectGraphContext: nil 
                                                                parentContext: self];
	[_loadedPersistentRoots setObject: persistentRoot
							   forKey: [persistentRoot persistentRootUUID]];

    return persistentRoot;
}

- (NSSet *)persistentRootsPendingInsertion
{
	NSMutableSet *insertedPersistentRoots = [NSMutableSet set];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		if ([persistentRoot isPersistentRootUncommitted])
		{
			[insertedPersistentRoots addObject: persistentRoot];
		}
	}
	return insertedPersistentRoots;
}

- (NSSet *)persistentRootsPendingUpdate
{
	NSMutableSet *updatedPersistentRoots = [NSMutableSet set];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		if ([persistentRoot hasChanges])
		{
			[updatedPersistentRoots addObject: persistentRoot];
		}
	}
	return updatedPersistentRoots;
}

- (COPersistentRoot *)insertNewPersistentRootWithRootObject: (COObject *)aRootObject
{
	COObjectGraphContext *objectGraphContext = [aRootObject objectGraphContext];

	INVALIDARG_EXCEPTION_TEST(objectGraphContext, [objectGraphContext persistentRoot] == nil);
	INVALIDARG_EXCEPTION_TEST(objectGraphContext,
		[objectGraphContext rootObject] == nil || [objectGraphContext rootObject] == aRootObject);

	COPersistentRoot *persistentRoot = [self makePersistentRootWithInfo: nil
	                                                 objectGraphContext: objectGraphContext];

	[objectGraphContext setRootObject: aRootObject];

	return persistentRoot;
}

- (void)deletePersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    if ([aPersistentRoot isPersistentRootUncommitted])
    {
        [self unloadPersistentRoot: aPersistentRoot];
    }
    else if ([_persistentRootsPendingUndeletion containsObject: aPersistentRoot])
    {
        [_persistentRootsPendingUndeletion removeObject: aPersistentRoot];
    }
    else
    {
        // NOTE: Deleted persistent roots are removed from the cache on commit.
        [_persistentRootsPendingDeletion addObject: aPersistentRoot];
    }
    
    [aPersistentRoot updateCrossPersistentRootReferences];
}

- (void)undeletePersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    if ([_persistentRootsPendingDeletion containsObject: aPersistentRoot])
    {
        [_persistentRootsPendingDeletion removeObject: aPersistentRoot];
    }
    else
    {
        [_persistentRootsPendingUndeletion addObject: aPersistentRoot];
    }
    
    [aPersistentRoot updateCrossPersistentRootReferences];
}

- (BOOL)hasChanges
{
    if ([_persistentRootsPendingDeletion count] > 0)
        return YES;
    
    if ([_persistentRootsPendingUndeletion count] > 0)
        return YES;
    
	for (COPersistentRoot *context in [_loadedPersistentRoots objectEnumerator])
	{
        if ([context isPersistentRootUncommitted])
            return YES;
        
		if ([context hasChanges])
			return YES;
	}
	return NO;
}

- (void)discardAllChanges
{
	/* Discard changes in persistent roots */

	for (ETUUID *uuid in _loadedPersistentRoots)
	{
		COPersistentRoot *persistentRoot = [_loadedPersistentRoots objectForKey: uuid];
		BOOL isInserted = ([persistentRoot revision] == nil);

		if (isInserted)
			continue;

		[persistentRoot discardAllChanges];
	}

	/* Clear persistent roots pending insertion */

	NSArray *persistentRootsPendingInsertion = [[self persistentRootsPendingInsertion] allObjects];

	[_loadedPersistentRoots removeObjectsForKeys:
		(id)[[persistentRootsPendingInsertion mappedCollection] persistentRootUUID]];
	ETAssert([[self persistentRootsPendingInsertion] isEmpty]);
	
	/* Clear other pending changes */

	[_persistentRootsPendingDeletion removeAllObjects];
	[_persistentRootsPendingUndeletion removeAllObjects];

	ETAssert([self hasChanges] == NO);
}

#pragma Validation

- (void)didFailValidationWithError: (COError *)anError
{
	_error =  anError;
}

/* Both COPersistentRoot or COEditingContext objects are valid arguments. */
- (BOOL)validateChangedObjectsForContext: (id)aContext
{
#if 0
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
#endif
    return YES;
}

#pragma mark Committing Changes
#pragma mark -

- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
                  undoTracks: (NSArray *)undoTracks
                       error: (NSError **)anError
{
	NILARG_EXCEPTION_TEST(aCommitDescriptorId);

	return [self commitWithMetadata: D(aCommitDescriptorId, kCOCommitMetadataIdentifier)
		restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
	                 withUndoTracks: undoTracks
	                          error: anError];
}

- (BOOL)commit
{
	return [self commitWithType: nil shortDescription: nil];
}

- (BOOL)commitWithType: (NSString *)type
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

// FIXME: This was moved here because Typewriter expects changes to be
// committed to store when it receives the notification. Decide if that
// is valid or not, and add a test case.
- (void)didCommitWithCommand: (COCommand *)command
             persistentRoots: (NSArray *)persistentRoots
{
	for (COPersistentRoot *ctxt in persistentRoots)
	{
		[ctxt didMakeNewCommit];
	}
    
    for (COPersistentRoot *ctxt in persistentRoots)
	{
		[ctxt sendChangeNotification];
	}

	NSDictionary *userInfo =
		(command != nil ? D(command, kCOCommandKey) : [NSDictionary dictionary]);

	[[NSNotificationCenter defaultCenter]
		postNotificationName: COEditingContextDidCommitNotification
		              object: self
		            userInfo: userInfo];
}

- (BOOL)commitWithMetadata: (NSDictionary *)metadata
	restrictedToPersistentRoots: (NSArray *)persistentRoots
	             withUndoTracks: (NSArray *)tracks
                          error: (NSError **)anError
{
	// TODO: We could organize validation errors by persistent root. Each
	// persistent root might result in a validation error that contains a
	// suberror per inner object, then each suberror could in turn contain
	// a suberror per validation result. For now, we just aggregate errors per
	// inner object.
	if ([self validateChangedObjectsForContext: self] == NO)
		return NO;

	/* Commit persistent root changes (deleted persistent roots included) */

    [_store beginTransactionWithError: NULL];
    [self recordBeginUndoGroup];
    
	// TODO: Add a batch commit UUID in the metadata
	for (COPersistentRoot *ctxt in persistentRoots)
	{
		[ctxt saveCommitWithMetadata: metadata transactionUUID: _store.transactionUUID];
	}
	
	/* Record persistent root deletions at the store level */
	
	for (COPersistentRoot *persistentRoot in persistentRoots)
	{
        ETUUID *uuid = [persistentRoot persistentRootUUID];
        
		if ([_persistentRootsPendingDeletion containsObject: persistentRoot])
        {
            ETAssert([_store deletePersistentRoot: uuid error: NULL]);
            [self recordPersistentRootDeletion: persistentRoot];
            
            [_persistentRootsPendingDeletion removeObject: persistentRoot];
            
            [self unloadPersistentRoot: persistentRoot];
        }
        else if ([_persistentRootsPendingUndeletion containsObject: persistentRoot])
        {
            ETAssert([_store undeletePersistentRoot: uuid error: NULL]);
            [self recordPersistentRootUndeletion: persistentRoot];
            
            [_persistentRootsPendingUndeletion removeObject: persistentRoot];
        }
    }

    ETAssert([_store commitTransactionWithUUID: _store.transactionUUID withError: NULL]);
	COCommand *command = [self recordEndUndoGroupWithUndoTracks: tracks];
    
	/* For a commit triggered by undo/redo on a COUndoTrack, the command is nil */
	[self didCommitWithCommand: command persistentRoots: persistentRoots];
    
	return YES;
}

- (BOOL)commitWithUndoTrack: (COUndoTrack *)aTrack
{
    return [self commitWithMetadata: nil
        restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
	                 withUndoTracks: A(aTrack)
	                          error: NULL];
}

- (BOOL)commitWithMetadata: (NSDictionary *)metadata
{
	return [self commitWithMetadata: metadata
		restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
                     withUndoTracks: nil
	                          error: NULL];
}

- (void) unloadPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    // FIXME: Implement. For now, since we don't support faulting persistent
    // roots, only release a persistent root if it's uncommitted.
    
    if ([aPersistentRoot isPersistentRootUncommitted])
    {
        [_loadedPersistentRoots removeObjectForKey:
            [aPersistentRoot persistentRootUUID]];
    }
}

- (id)crossPersistentRootReferenceWithPath: (COPath *)aPath
{
    ETUUID *persistentRootUUID = [aPath persistentRoot];
    ETAssert(persistentRootUUID != nil);
    
    ETUUID *branchUUID = [aPath branch];
    
    /* Specifying an embedded object is unsupported and will be removed from COPath */
    ETAssert([aPath embeddedObject] == nil);
    
    COPersistentRoot *persistentRoot = [self persistentRootForUUID: persistentRootUUID];
    ETAssert(persistentRoot != nil);
    
    COBranch *branch;
    if (branchUUID != nil)
    {
        branch = [persistentRoot branchForUUID: branchUUID];
    }
    else
    {
        branch = [persistentRoot currentBranch];
    }
    
    if ([branch isDeleted])
    {
        return nil;
    }
    
    COObjectGraphContext *objectGraphContext = [branch objectGraphContext];
    return [objectGraphContext rootObject];
}

// Notification handling

/* Handles distributed notifications about new revisions to refresh the root
 object graphs present in memory, for which changes have been committed to the
 store by other processes. */
- (void)distributedStorePersistentRootDidChange: (NSNotification *)notif
{
    // TODO: Write a test to ensure other store notifications are not handled
    NSDictionary *userInfo = [notif userInfo];
    NSString *storeURL = [userInfo objectForKey: kCOStoreURL];
    NSString *storeUUID = [userInfo objectForKey: kCOStoreUUID];
    
    if ([[[_store UUID] stringValue] isEqual: storeUUID]
        && [[[_store URL] absoluteString] isEqual: storeURL])
    {
        [self storePersistentRootDidChange: notif isDistributed: YES];
    }
}

- (void)storePersistentRootDidChange: (NSNotification *)notif
{
    [self storePersistentRootDidChange: notif isDistributed: NO];
}

- (void)storePersistentRootDidChange: (NSNotification *)notif isDistributed: (BOOL)isDistributed
{
    NSDictionary *userInfo = [notif userInfo];
    ETUUID *persistentRootUUID = [ETUUID UUIDWithString: [userInfo objectForKey: kCOPersistentRootUUID]];
    
    //NSLog(@"%@: Got change notif for persistent root: %@", self, persistentRootUUID);
    
    COPersistentRoot *loaded = [_loadedPersistentRoots objectForKey: persistentRootUUID];
    if (loaded != nil)
    {
        [loaded storePersistentRootDidChange: notif isDistributed: isDistributed];
    }
}

- (CORevision *) revisionForRevisionID: (CORevisionID *)aRevid
{
    return [CORevisionCache revisionForRevisionID: aRevid storeUUID: [_store UUID]];
}

@end


@implementation COEditingContext (Debugging)

- (NSSet *)loadedObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(loadedObjects)];
}

- (NSSet *)loadedRootObjects
{
	NSMutableSet *collectedObjects = [NSMutableSet set];
	
	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		for (COBranch *branch in [persistentRoot branches])
		{
			[collectedObjects addObject: [[branch objectGraphContext] rootObject]];
		}
	}
	return collectedObjects;
}

// NOTE: We could rewrite it using -foldWithBlock: or -leftFold (could be faster)
- (NSSet *)setByCollectingObjectsFromPersistentRootsUsingSelector: (SEL)aSelector
{
	NSMutableSet *collectedObjects = [NSMutableSet set];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		for (COBranch *branch in [persistentRoot branches])
		{
			[collectedObjects unionSet: [[branch objectGraphContext] performSelector: aSelector]];
		}
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

- (NSSet *)changedObjects
{
	return [self setByCollectingObjectsFromPersistentRootsUsingSelector: @selector(changedObjects)];
}

@end

NSString * const COEditingContextDidCommitNotification =
	@"COEditingContextDidCommitNotification";
NSString * const kCOCommandKey = @"kCOCommandKey";
