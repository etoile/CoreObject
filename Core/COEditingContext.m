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
#import "COObject+Private.h"
#import "COGroup.h"
#import "COSQLiteStore.h"
#import "CORevision.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "COPath.h"
#import "COObjectGraphContext.h"
#import "COUndoStackStore.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "CORevisionCache.h"
#import "COStoreTransaction.h"

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
    _isRecordingUndo = YES;

	[CORevisionCache prepareCacheForStore: store];
	[self registerAdditionalEntityDescriptions];


    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootsDidChange:)
                                                 name: COStorePersistentRootsDidChangeNotification
                                               object: _store];

	[[NSDistributedNotificationCenter defaultCenter] addObserver: self
	                                                    selector: @selector(distributedStorePersistentRootsDidChange:)
	                                                        name: COStorePersistentRootsDidChangeNotification
	                                                      object: nil];

	for (ETUUID *uuid in [_store persistentRootUUIDs])
    {
        [self persistentRootForUUID: uuid];
    }
	
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
		                  forKey: [persistentRoot UUID]];
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
	return [NSSet setWithArray: [[_loadedPersistentRoots allValues] filteredCollectionWithBlock: ^(id obj) {
		return (BOOL) !((COPersistentRoot *)obj).deleted;
	}]];
}

- (NSSet *)deletedPersistentRoots
{
	return [NSSet setWithArray: [[_loadedPersistentRoots allValues] filteredCollectionWithBlock: ^(id obj) {
		return ((COPersistentRoot *)obj).deleted;
	}]];
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
                                                        cheapCopyRevisionUUID: nil
												  cheapCopyPersistentRootUUID: nil
															 parentBranchUUID: nil
	                                                       objectGraphContext: anObjectGrapContext
                                                                parentContext: self];
	[_loadedPersistentRoots setObject: persistentRoot
							   forKey: [persistentRoot UUID]];
	return persistentRoot;
}

- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName
{
	ETEntityDescription *desc = [[self modelRepository] descriptionForName: anEntityName];
    
    COObjectGraphContext *graph = [COObjectGraphContext objectGraphContext];
    
	Class cls = [[self modelRepository] classForEntityDescription: desc];
	COObject *rootObject = [[cls alloc] initWithEntityDescription: desc
                                               objectGraphContext: graph];
	[graph setRootObject: rootObject];

	COPersistentRoot *persistentRoot = [self makePersistentRootWithInfo: nil
	                                                 objectGraphContext: graph];

	ETAssert([rootObject objectGraphContext] == persistentRoot.objectGraphContext);
    
    ETAssert([[persistentRoot rootObject] isRoot]);
    ETAssert([[[persistentRoot currentBranch] rootObject] isRoot]);
	
    return persistentRoot;
}

- (COPersistentRoot *)insertNewPersistentRootWithRevisionUUID: (ETUUID *)aRevid
											   parentBranch: (COBranch *)aParentBranch
{
    COPersistentRoot *persistentRoot = [[COPersistentRoot alloc] initWithInfo: nil
														cheapCopyRevisionUUID: aRevid
												  cheapCopyPersistentRootUUID: [[aParentBranch persistentRoot] UUID]
															 parentBranchUUID: [aParentBranch UUID]
	                                                       objectGraphContext: nil 
                                                                parentContext: self];
	[_loadedPersistentRoots setObject: persistentRoot
							   forKey: [persistentRoot UUID]];

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
		BOOL isInserted = ([persistentRoot currentRevision] == nil);

		if (isInserted)
			continue;

		[persistentRoot discardAllChanges];
	}

	/* Clear persistent roots pending insertion */

	NSArray *persistentRootsPendingInsertion = [[self persistentRootsPendingInsertion] allObjects];

	[_loadedPersistentRoots removeObjectsForKeys:
		(id)[[persistentRootsPendingInsertion mappedCollection] UUID]];
	ETAssert([[self persistentRootsPendingInsertion] isEmpty]);
	
	/* Clear other pending changes */

	[_persistentRootsPendingDeletion removeAllObjects];
	[_persistentRootsPendingUndeletion removeAllObjects];

	ETAssert([self hasChanges] == NO);
}

#pragma mark Validation
#pragma mark -

/* Both COPersistentRoot or COEditingContext objects are valid arguments. */
- (BOOL)validateChangedObjectsForContext: (id)aContext error: (NSError **)error
{
	NSMutableArray *validationErrors = [NSMutableArray array];

	for (COObject *object in [aContext changedObjects])
	{
		[validationErrors addObjectsFromArray: [object validate]];
	}
	ETAssert([validationErrors containsObject: [NSNull null]] == NO);

	if (error != NULL)
	{
		*error = [COError errorWithErrors: validationErrors];
	}
    return [validationErrors isEmpty];
}

#pragma mark Committing Changes
#pragma mark -

- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
				   undoTrack: (COUndoTrack *)undoTrack
                       error: (NSError **)anError
{
	return [self commitWithIdentifier: aCommitDescriptorId
	                         metadata: nil
							undoTrack: undoTrack
	                            error: anError];
}

- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
					metadata: (NSDictionary *)additionalMetadata
				   undoTrack: (COUndoTrack *)undoTrack
                       error: (NSError **)anError
{
	NILARG_EXCEPTION_TEST(aCommitDescriptorId);
	INVALIDARG_EXCEPTION_TEST(additionalMetadata, [additionalMetadata containsKey: aCommitDescriptorId] == NO);

	NSMutableDictionary *metadata =
		[D(aCommitDescriptorId, kCOCommitMetadataIdentifier) mutableCopy];

	if (additionalMetadata != nil)
	{
		[metadata addEntriesFromDictionary: additionalMetadata];
	}
	return [self commitWithMetadata: metadata
	    restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
					  withUndoTrack: undoTrack
	                          error: anError];
}

- (BOOL)commitWithMetadata: (NSDictionary *)metadata
				 undoTrack: (COUndoTrack *)undoTrack
                     error: (NSError **)anError
{
	return [self commitWithMetadata: metadata
	    restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
					  withUndoTrack: undoTrack
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
		postNotificationName: COEditingContextDidChangeNotification
		              object: self
		            userInfo: userInfo];
}

- (void)validateMetadata: (NSDictionary *)metadata
{
	INVALIDARG_EXCEPTION_TEST(metadata, metadata == nil
		|| [NSJSONSerialization isValidJSONObject: metadata]);
	
	/* Validate short description related metadata */

	NSArray *shortDescriptionArgs =
		[metadata objectForKey: kCOCommitMetadataShortDescriptionArguments];
	BOOL containsValidArgs = YES;

	for (id obj in shortDescriptionArgs)
	{
		containsValidArgs &= [obj isString];
	}
	INVALIDARG_EXCEPTION_TEST(metadata, shortDescriptionArgs == nil
		|| ([shortDescriptionArgs isKindOfClass: [NSArray class]] && containsValidArgs));
}

- (BOOL)commitWithMetadata: (NSDictionary *)metadata
restrictedToPersistentRoots: (NSArray *)persistentRoots
			 withUndoTrack: (COUndoTrack *)track
					 error: (NSError **)anError
{
	[self validateMetadata: metadata];

	// TODO: We could organize validation errors by persistent root. Each
	// persistent root might result in a validation error that contains a
	// suberror per inner object, then each suberror could in turn contain
	// a suberror per validation result. For now, we just aggregate errors per
	// inner object.
	if ([self validateChangedObjectsForContext: self error: anError] == NO)
		return NO;

	/* Commit persistent root changes (deleted persistent roots included) */

    COStoreTransaction *transaction = [[COStoreTransaction alloc] init];
    [self recordBeginUndoGroupWithMetadata: metadata];
    
	// TODO: Add a batch commit UUID in the metadata
	for (COPersistentRoot *persistentRoot in persistentRoots)
	{
		[persistentRoot saveCommitWithMetadata: metadata transaction: transaction];
	}
	
	/* Add persistent root deletions to the transaction */
	
	for (COPersistentRoot *persistentRoot in persistentRoots)
	{
        ETUUID *uuid = [persistentRoot UUID];
        
		if ([_persistentRootsPendingDeletion containsObject: persistentRoot])
        {
            [transaction deletePersistentRoot: uuid];
            [self recordPersistentRootDeletion: persistentRoot];
        }
        else if ([_persistentRootsPendingUndeletion containsObject: persistentRoot])
        {
            [transaction undeletePersistentRoot: uuid];
            [self recordPersistentRootUndeletion: persistentRoot];
        }
    }

	/* Update transaction IDs (can't add to the transaction after this) */
	
	for (ETUUID *uuid in [transaction persistentRootUUIDs])
	{
		COPersistentRoot *persistentRoot = [self persistentRootForUUID: uuid];

		persistentRoot.lastTransactionID = [transaction setOldTransactionID: persistentRoot.lastTransactionID forPersistentRoot: uuid];
	}
	
	/* Update _persistentRootsPendingDeletion and _persistentRootsPendingUndeletion and unload
	   persistent roots. */
	
	for (COPersistentRoot *persistentRoot in persistentRoots)
	{
		if ([_persistentRootsPendingDeletion containsObject: persistentRoot])
        {
            [_persistentRootsPendingDeletion removeObject: persistentRoot];
            
            [self unloadPersistentRoot: persistentRoot];
        }
        else if ([_persistentRootsPendingUndeletion containsObject: persistentRoot])
        {
            [_persistentRootsPendingUndeletion removeObject: persistentRoot];
        }
    }
											
				
    ETAssert([_store commitStoreTransaction: transaction]);
	COCommand *command = [self recordEndUndoGroupWithUndoTrack: track];
    
	/* For a commit triggered by undo/redo on a COUndoTrack, the command is nil */
	[self didCommitWithCommand: command persistentRoots: persistentRoots];

	if (anError != NULL)
	{
		*anError = nil;
	}
	return YES;
}

- (BOOL)commitWithUndoTrack: (COUndoTrack *)aTrack
{
    return [self commitWithMetadata: nil
        restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
					  withUndoTrack: aTrack
	                          error: NULL];
}

- (BOOL)commitWithMetadata: (NSDictionary *)metadata
{
	return [self commitWithMetadata: metadata
		restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
					  withUndoTrack: nil
	                          error: NULL];
}

- (void) unloadPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    // FIXME: Implement. For now, since we don't support faulting persistent
    // roots, only release a persistent root if it's uncommitted.
    
    if ([aPersistentRoot isPersistentRootUncommitted])
    {
        [_loadedPersistentRoots removeObjectForKey:
            [aPersistentRoot UUID]];
    }
}

- (id)crossPersistentRootReferenceWithPath: (COPath *)aPath
{
    ETUUID *persistentRootUUID = [aPath persistentRoot];
    ETAssert(persistentRootUUID != nil);
    
    /* Specifying an inner object is unsupported and will be removed from COPath */
    ETAssert([aPath innerObject] == nil);
	
	ETUUID *branchUUID = [aPath branch];
	
	COPersistentRoot *persistentRoot = [self persistentRootForUUID: persistentRootUUID];
	// FIXME: We will need to handle the case where a reference points to a
	// persistent root that has been permanently deleted from the store,
	// perhaps by allocating a placeholder "broken link" persistent root.
    ETAssert(persistentRoot != nil);
	
	if (branchUUID != nil)
	{
		COBranch *branch = [persistentRoot branchForUUID: branchUUID];
		// FIXME: Again, this is a simplification, should handle broken refs.
		ETAssert(branch != nil);
		
		return [branch rootObject];
	}
	else
	{
		return [persistentRoot rootObject];
	}
}

// Notification handling

/* Handles distributed notifications about new revisions to refresh the root
 object graphs present in memory, for which changes have been committed to the
 store by other processes. */
- (void)distributedStorePersistentRootsDidChange: (NSNotification *)notif
{
    // TODO: Write a test to ensure other store notifications are not handled
    NSDictionary *userInfo = [notif userInfo];
    NSString *storeURL = [userInfo objectForKey: kCOStoreURL];
    NSString *storeUUID = [userInfo objectForKey: kCOStoreUUID];
    
    if ([[[_store UUID] stringValue] isEqual: storeUUID]
        && [[[_store URL] absoluteString] isEqual: storeURL])
    {
        [self storePersistentRootsDidChange: notif isDistributed: YES];
    }
}

- (void)storePersistentRootsDidChange: (NSNotification *)notif
{
    [self storePersistentRootsDidChange: notif isDistributed: NO];
}

- (void)storePersistentRootsDidChange: (NSNotification *)notif isDistributed: (BOOL)isDistributed
{
    NSDictionary *userInfo = [notif userInfo];
    NSArray *persistentRootUUIDs = [[userInfo[kCOStorePersistentRootTransactionIDs] allKeys] mappedCollectionWithBlock: ^(id uuidString) {
		return [ETUUID UUIDWithString: uuidString];
	}];
	
    //NSLog(@"%@: Got change notif for persistent root: %@", self, persistentRootUUID);
    
	BOOL hadChanges = NO;
	
	for (ETUUID *persistentRootUUID in persistentRootUUIDs)
	{
		COPersistentRoot *loaded = [_loadedPersistentRoots objectForKey: persistentRootUUID];
		if (loaded != nil)
		{
			NSNumber *notifTransactionObj = notif.userInfo[kCOStorePersistentRootTransactionIDs][loaded.UUID.stringValue];
			
			if (notifTransactionObj == nil)
			{
				NSLog(@"Warning, invalid nil transaction id");
				return;
			}
			
			int64_t notifTransaction = [notifTransactionObj longLongValue];
			
			if (notifTransaction > loaded.lastTransactionID)
			{
				hadChanges = YES;
				[loaded storePersistentRootDidChange: notif isDistributed: isDistributed];
			}
		}
		else
		{
			COPersistentRoot *newlyInserted = [self persistentRootForUUID: persistentRootUUID];
			if (newlyInserted != nil)
			{
				hadChanges = YES;
			}
		}
	}
	
	if (hadChanges)
	{
		[[NSNotificationCenter defaultCenter]
		 postNotificationName: COEditingContextDidChangeNotification
		 object: self
		 userInfo: nil];
	}
}

- (CORevision *) revisionForRevisionUUID: (ETUUID *)aRevid persistentRootUUID: (ETUUID *)aPersistentRoot
{
    return [CORevisionCache revisionForRevisionUUID: aRevid persistentRootUUID: aPersistentRoot storeUUID: [_store UUID]];
}

- (COBranch *) branchForUUID: (ETUUID *)aBranch
{
	if (aBranch != nil)
	{
		ETUUID *prootUUID = [_store persistentRootUUIDForBranchUUID: aBranch];
		COPersistentRoot *proot = [self persistentRootForUUID: prootUUID];
		return [proot branchForUUID: aBranch];
	}
	return nil;
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

NSString * const COEditingContextDidChangeNotification =
	@"COEditingContextDidChangeNotification";
NSString * const kCOCommandKey = @"kCOCommandKey";
