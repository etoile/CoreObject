/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COPersistentRoot+Private.h"
#import "COError.h"
#import "COObject.h"
#import "COObject+Private.h"
#import "COMetamodel.h"
#import "COSQLiteStore.h"
#import "CORevision.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "COPath.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "COCrossPersistentRootDeadRelationshipCache.h"
#import "CORevisionCache.h"
#import "COStoreTransaction.h"
#import "COUndoTrackStore.h"
#if TARGET_OS_IPHONE
#import "NSDistributedNotificationCenter.h"
#endif

@implementation COEditingContext

@synthesize store = _store, modelDescriptionRepository = _modelDescriptionRepository;
@synthesize migrationDriverClass = _migrationDriverClass;
@synthesize unloadingBehavior = _unloadingBehavior;
@synthesize persistentRootsPendingDeletion = _persistentRootsPendingDeletion;
@synthesize persistentRootsPendingUndeletion = _persistentRootsPendingUndeletion;
@synthesize deadRelationshipCache = _deadRelationshipCache;
@synthesize undoTrackStore = _undoTrackStore, isRecordingUndo = _isRecordingUndo;

#pragma mark Creating a New Context -

+ (COEditingContext *)contextWithURL: (NSURL *)aURL
{
	// TODO: Look up the store class based on the URL scheme and path extension
	return [[self alloc] initWithStore: [[COSQLiteStore alloc] initWithURL: aURL]];
}

- (instancetype)initWithStore: (COSQLiteStore *)store
   modelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
         migrationDriverClass: (Class)aDriverClass
               undoTrackStore: (COUndoTrackStore *)anUndoTrackStore
{
	NILARG_EXCEPTION_TEST(store);
	NILARG_EXCEPTION_TEST(aRepo);
	INVALIDARG_EXCEPTION_TEST(aRepo, [aRepo entityDescriptionForClass: [COObject class]] != nil);
	INVALIDARG_EXCEPTION_TEST(aDriverClass, [aDriverClass isSubclassOfClass: [COSchemaMigrationDriver class]]);
	NILARG_EXCEPTION_TEST(anUndoTrackStore);


	SUPERINIT;

	_store =  store;
	_modelDescriptionRepository = aRepo;
	_migrationDriverClass = aDriverClass;
	_loadedPersistentRoots = [NSMutableDictionary new];
	_unloadingBehavior = COEditingContextUnloadingBehaviorOnDeletion;
	_persistentRootsPendingDeletion = [NSMutableSet new];
    _persistentRootsPendingUndeletion = [NSMutableSet new];
	_deadRelationshipCache = [COCrossPersistentRootDeadRelationshipCache new];
	_undoTrackStore = anUndoTrackStore;
    _isRecordingUndo = YES;
	_revisionCache = [[CORevisionCache alloc] initWithParentEditingContext: self];
	_internalTransientObjectGraphContext = [[COObjectGraphContext alloc]
		initWithModelDescriptionRepository: aRepo
		              migrationDriverClass: aDriverClass];
	_lastTransactionIDForPersistentRootUUID = [NSMutableDictionary new];
	CORegisterCoreObjectMetamodel(_modelDescriptionRepository);

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootsDidChange:)
                                                 name: COStorePersistentRootsDidChangeNotification
                                               object: _store];

	[[NSDistributedNotificationCenter defaultCenter]
		addObserver: self
	       selector: @selector(distributedStorePersistentRootsDidChange:)
		       name: COStorePersistentRootsDidChangeNotification
		     object: nil];
	
	return self;
}

- (instancetype)initWithStore: (COSQLiteStore *)store
   modelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
{
	return [self initWithStore: store
	modelDescriptionRepository: aRepo
	      migrationDriverClass: [COSchemaMigrationDriver class]
	            undoTrackStore: [COUndoTrackStore defaultStore]];
}

- (instancetype)initWithStore: (COSQLiteStore *)store
{
	return [self initWithStore: store
	           modelDescriptionRepository: [ETModelDescriptionRepository mainRepository]];
}

- (instancetype)init
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
	return [NSString stringWithFormat: @"<%@ %p - store: %@ (%@)>",
		NSStringFromClass([self class]), self, [_store UUID], [_store URL]];
}

- (NSString *)detailedDescription
{
	NSArray *properties = A(@"modelDescriptionRepository", @"hasChanges", 
		@"persistentRootsPendingInsertion", @"persistentRootsPendingUpdate",
		@"persistentRootsPendingDeletion", @"persistentRootsPendingUndeletion",
		@"persistentRoots");
	NSMutableDictionary *options =
		[D(properties, kETDescriptionOptionValuesForKeyPaths,
		@"\t", kETDescriptionOptionPropertyIndent) mutableCopy];

	return [self descriptionWithOptions: options];
}

- (NSString *)changeDescription
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

#pragma mark Accessing All Persistent Roots -

- (void)loadAllPersistentRootsIfNeeded
{
	if (!_hasLoadedPersistentRootUUIDs)
	{
		for (ETUUID *uuid in [_store persistentRootUUIDs])
		{
			[self persistentRootForUUID: uuid];
		}
		
		_hasLoadedPersistentRootUUIDs = YES;
	}
}

- (NSSet *)persistentRoots
{
	[self loadAllPersistentRootsIfNeeded];
	
	return [NSSet setWithArray: [[_loadedPersistentRoots allValues] filteredCollectionWithBlock: ^(id obj) {
		return (BOOL) !((COPersistentRoot *)obj).deleted;
	}]];
}

- (NSSet *)deletedPersistentRoots
{
	[self loadAllPersistentRootsIfNeeded];
	
	/* Force deleted persistent roots to be reloaded (see -unloadPersistentRoot:) */
	for (ETUUID *persistentRootUUID in [self.store deletedPersistentRootUUIDs])
	{
		 [self persistentRootForUUID: persistentRootUUID];
	}

	return [NSSet setWithArray: [[_loadedPersistentRoots allValues] filteredCollectionWithBlock: ^(id obj) {
		return ((COPersistentRoot *)obj).deleted;
	}]];
}

- (NSSet *)loadedPersistentRoots
{
	return [NSSet setWithArray: _loadedPersistentRoots.allValues];
}

#pragma mark Managing Persistent Roots -

/**
 * We don't need to update cross persistent references when loading a persistent 
 * root, see -[COPersistentRoot setCurrentBranchObjectGraphToRevisionUUID:persistentRootUUID:].
 *
 * There is one exception to this rule, it's when we reload due to an external 
 * change as covered in -storePersistentRootsDidChange:isDistributed:.
 */
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

- (COPersistentRoot *)loadedPersistentRootForUUID: (ETUUID *)aUUID
{
    return _loadedPersistentRoots[aUUID];
}

- (COPersistentRoot *)makePersistentRootWithInfo: (COPersistentRootInfo *)info
                              objectGraphContext: (COObjectGraphContext *)anObjectGrapContext
{
	NSParameterAssert(info == nil || nil == [_loadedPersistentRoots objectForKey: [info UUID]]);
    
    COPersistentRoot *persistentRoot = [[COPersistentRoot alloc] initWithInfo: info
                                                        cheapCopyRevisionUUID: nil
												  cheapCopyPersistentRootUUID: nil
															 parentBranchUUID: nil
	                                                       objectGraphContext: anObjectGrapContext
                                                                parentContext: self];
	[_loadedPersistentRoots setObject: persistentRoot
							   forKey: [persistentRoot UUID]];
	
	// Lazy loading support:
	// Cause any faulted references to this newly loaded persistet root to be unfaulted
	[self updateCrossPersistentRootReferencesToPersistentRoot: persistentRoot
													   branch: nil
													isDeleted: persistentRoot.deleted];
	return persistentRoot;
}

- (COPersistentRoot *)insertNewPersistentRootWithEntityName: (NSString *)anEntityName
{
	ETEntityDescription *desc = [[self modelDescriptionRepository] descriptionForName: anEntityName];
	if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Found not entity %@ in %@",
		                    anEntityName, self.modelDescriptionRepository];
	}
    COObjectGraphContext *graph = [COObjectGraphContext
		objectGraphContextWithModelDescriptionRepository: self.modelDescriptionRepository];

	// TODO: For a nil class, fall back on COObject or some other class as we do in COObjectGraphContext
	Class cls = [[self modelDescriptionRepository] classForEntityDescription: desc];
	COObject *rootObject = [[cls alloc] initWithEntityDescription: desc
                                               objectGraphContext: graph];
	[graph setRootObject: rootObject];

	COPersistentRoot *persistentRoot = [self makePersistentRootWithInfo: nil
	                                                 objectGraphContext: graph];

	ETAssert([rootObject objectGraphContext] == persistentRoot.objectGraphContext);
    ETAssert([[persistentRoot rootObject] isRoot]);
	
    return persistentRoot;
}

- (COPersistentRoot *)insertNewPersistentRootWithRevisionUUID: (ETUUID *)aRevid
											   parentBranch: (COBranch *)aParentBranch
{
	ETUUID *copiedPersistentRootUUID = [[aParentBranch persistentRoot] UUID];
    COPersistentRoot *persistentRoot = [[COPersistentRoot alloc] initWithInfo: nil
														cheapCopyRevisionUUID: aRevid
												  cheapCopyPersistentRootUUID: copiedPersistentRootUUID
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
	INVALIDARG_EXCEPTION_TEST(objectGraphContext,
		[objectGraphContext modelDescriptionRepository] == _modelDescriptionRepository)

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

	[self updateCrossPersistentRootReferencesToPersistentRoot: aPersistentRoot
	                                                   branch: nil
	                                                isDeleted: YES];
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

	[self updateCrossPersistentRootReferencesToPersistentRoot: aPersistentRoot
	                                                   branch: nil
	                                                isDeleted: NO];
}

/**
 * When isDeleted is YES, turns live references to the given persistent root 
 * into dead ones in referring persistent roots.
 *
 * When isDeleted is NO, turns dead references to the given persistent root
 * into live ones in referring persistent roots.
 *
 * When isDeleted is YES and branch is nil, this means the persistent root 
 * itself is deleted. In this case, we consider the branches to be all 
 * transively deleted for this method logic, although there aren't marked as 
 * deleted.
 *
 * The implementation must take in account deletion/undeletion can be:
 *
 * <list>
 * <item>explicit with COPersistentRoot and COBranch API</item>
 * <item>implicit deletion/undeletion when reloading persistent roots or branches 
 * (e.g. isTargetDeletion comment).</item>
 * </list>
 *
 * IMPORTANT: This method must never result in new changes to be committed, 
 * since it replaces object references in memory, but doesn't change any item
 * graphs (the references inside each COItem remain identical). Requiring no 
 * commits means the references can be fixed in both tracking and current branches.
 *
 * See also -[COPersistentRoot setCurrentBranchObjectGraphToRevisionUUID:persistentRootUUID:].
 */
- (void)updateCrossPersistentRootReferencesToPersistentRoot: (COPersistentRoot *)aPersistentRoot
                                                     branch: (COBranch *)aBranch
                                                  isDeleted: (BOOL)isDeletion
{
	NSParameterAssert(aPersistentRoot != nil);
	
	// See documentation above
	if (isDeletion)
	{
		// TODO: For an uncommitted persistent root and branch, could be better if
		// -deletePersistentRoot/Branch: marked it temporarily as pending deletion.
		ETAssert(aPersistentRoot.deleted || aPersistentRoot.isPersistentRootUncommitted
			|| (aBranch != nil && (aBranch.deleted || aBranch.isBranchUncommitted)));
	}
	else
	{
		ETAssert(!aPersistentRoot.deleted && (aBranch == nil || !aBranch.deleted));
	}

	/* Fix references pointing to any branch that belong to the deleted
	 persistent root (the relationship target) */
	NSSet *targetObjectGraphs = nil;
	
	if (aBranch != nil)
	{
		targetObjectGraphs = [NSSet setWithObject: aBranch.objectGraphContext];
	}
	else
	{
		targetObjectGraphs = [aPersistentRoot allObjectGraphContexts];
	}
	
	for (COObjectGraphContext *target in targetObjectGraphs)
	{
		/* When we are not deleting a persistent root or branch explicitly,
		 but reloading persistent roots, we must take in account that
		 branches can become deleted when their persistent root doesn't
		 (isDeletion is NO) */
		BOOL isTargetDeletion = isDeletion || target.branch.deleted;
		/* Fix references in all branches that belong to persistent roots
		 referencing the deleted persistent root (those are relationship sources) */
		NSMutableSet *sourceObjectGraphs = [NSMutableSet new];
		
		// Quickly lookup the COObjects that have currently dead references that
		// should point at `target`.
		
		// TODO: Factor out this object graph context -> COPath conversion.
		COPath *targetPath;
		if (target == aPersistentRoot.objectGraphContext)
		{
			targetPath = [COPath pathWithPersistentRoot: target.persistentRoot.UUID];
		}
		else
		{
			targetPath = [COPath pathWithPersistentRoot: target.persistentRoot.UUID branch: target.branch.UUID];
		}
		
		NSHashTable *referrersWithDeadReferences = [_deadRelationshipCache referringObjectsForPath: targetPath];
		for (COObject *sourceObject in referrersWithDeadReferences)
		{
			[sourceObjectGraphs addObject: sourceObject.objectGraphContext];
		}
		
		// Quickly lookup COObjects with live references to `target`
		NSSet *referrersWithLiveReferences = [target.rootObject referringObjects];
		for (COObject *sourceObject in referrersWithLiveReferences)
		{
			[sourceObjectGraphs addObject: sourceObject.objectGraphContext];
		}
		
		// Fix up the references
		for (COObjectGraphContext *source in sourceObjectGraphs)
		{
			if (source.persistentRoot == aPersistentRoot)
				continue;
			
			// TODO: We could easily skip traversing all inner objects, since
			// we already know which ones need fixing up.
			[source replaceObject: (isTargetDeletion ? target.rootObject : nil)
					   withObject: (isTargetDeletion ? nil : target.rootObject)];
		}
	}
}

- (void)unloadPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
	if (_unloadingBehavior == COEditingContextUnloadingBehaviorNever
		&& ![aPersistentRoot isPersistentRootUncommitted])
	{
		return;
	}

    // FIXME: Implement. For now, since we don't support faulting persistent
    // roots, only release a persistent root if it's deleted.
	COPersistentRoot *unloadedPersistentRoot = aPersistentRoot;

    [_loadedPersistentRoots removeObjectForKey: [aPersistentRoot UUID]];

	[[NSNotificationCenter defaultCenter]
		postNotificationName: COEditingContextDidUnloadPersistentRootsNotification
		              object: self
		            userInfo: @{ kCOUnloadedPersistentRootsKey : S(unloadedPersistentRoot) }];
}

#pragma mark Referencing Other Persistent Roots -

- (id)crossPersistentRootReferenceWithPath: (COPath *)aPath shouldLoad: (BOOL)shouldLoad
{
    ETUUID *persistentRootUUID = [aPath persistentRoot];
    ETAssert(persistentRootUUID != nil);

	ETUUID *branchUUID = [aPath branch];

	COPersistentRoot *persistentRoot;
	if (shouldLoad)
	{
		persistentRoot = [self persistentRootForUUID: persistentRootUUID];
	}
	else
	{
		persistentRoot = [self loadedPersistentRootForUUID: persistentRootUUID];
	}
	
    if (persistentRoot == nil)
    {
        return nil;
    }
	if (persistentRoot.deleted)
	{
		return nil;
	}
		
    
	if (branchUUID != nil)
	{
		COBranch *branch = [persistentRoot branchForUUID: branchUUID];
		
		if (branch.deleted)
		{
			return nil;
		}
		return [branch rootObject];
	}
	else
	{
		return [persistentRoot rootObject];
	}
}

#pragma mark Pending Changes -

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

#pragma mark Validation -

/* Both COPersistentRoot or COEditingContext objects are valid arguments. */
- (BOOL)validateChangedObjectsForContext: (id)aContext error: (COError **)error
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

#pragma mark Committing Changes -

- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
				   undoTrack: (COUndoTrack *)undoTrack
                       error: (COError **)anError
{
	return [self commitWithIdentifier: aCommitDescriptorId
	                         metadata: nil
							undoTrack: undoTrack
	                            error: anError];
}

- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
					metadata: (NSDictionary *)additionalMetadata
				   undoTrack: (COUndoTrack *)undoTrack
                       error: (COError **)anError
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
                     error: (COError **)anError
{
	return [self commitWithMetadata: metadata
	    restrictedToPersistentRoots: [_loadedPersistentRoots allValues]
					  withUndoTrack: undoTrack
	                          error: anError];
}

- (BOOL)commit
{
	return [self commitWithMetadata: [NSDictionary dictionary]];
}

- (void)didCommitWithCommand: (COCommandGroup *)command
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

	// NOTE: COEditingContextDidChangeNotification needs more testing.
	// In particular, test that the changes are already committed (which they are)
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
					 error: (COError **)anError
{
	if (_inCommit)
	{
		[NSException raise: NSGenericException
					format: @"%@ called recursively", NSStringFromSelector(_cmd)];
	}
		
	@try
	{
		_inCommit = YES;
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

			persistentRoot.lastTransactionID = [transaction setOldTransactionID: persistentRoot.lastTransactionID
															  forPersistentRoot: uuid];
		}
		
		/* Update persistent roots and branches pending deletion and undeletion, 
		   and unload persistent roots */
		
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
			[persistentRoot clearBranchesPendingDeletionAndUndeletion];
		}

		ETAssert([_store commitStoreTransaction: transaction]);
		COCommandGroup *command = [self recordEndUndoGroupWithUndoTrack: track];
		
		/* For a commit triggered by undo/redo on a COUndoTrack, the command is nil */
		[self didCommitWithCommand: command persistentRoots: persistentRoots];

		if (anError != NULL)
		{
			*anError = nil;
		}
	}
	@finally
	{
		_inCommit = NO;
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

#pragma mark Notification Handling -

/**
 * Handles distributed notifications about new revisions to refresh the root
 * object graphs present in memory, for which changes have been committed to the
 * store by other processes. 
 */
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

/**
 * Reloads changed persistent roots, except the ones that got deleted (either 
 * with an explicit commit in the current context or from some other editing 
 * context).
 *
 * Deleted persistent roots are unloaded right before executing the commit 
 * transaction.
 *
 * The transaction IDs protect us against lost distributed commit notifications,
 * that can result in state mismatches between the store and the editing context.
 */
- (void)storePersistentRootsDidChange: (NSNotification *)notif isDistributed: (BOOL)isDistributed
{
	NSDictionary *transactionIDs = notif.userInfo[kCOStorePersistentRootTransactionIDs];
    NSArray *persistentRootUUIDs = [[transactionIDs allKeys] mappedCollectionWithBlock: ^ (id uuidString) {
		return [ETUUID UUIDWithString: uuidString];
	}];
	NSArray *deletedPersistentRootUUIDs = [notif.userInfo[kCOStoreDeletedPersistentRoots] mappedCollectionWithBlock: ^ (id uuidString) {
		return [ETUUID UUIDWithString: uuidString];
	}];
	NSArray *compactedPersistentRootUUIDs = [notif.userInfo[kCOStoreCompactedPersistentRoots] mappedCollectionWithBlock: ^ (id uuidString) {
		return [ETUUID UUIDWithString: uuidString];
	}];
	NSArray *finalizedPersistentRootUUIDs = [notif.userInfo[kCOStoreFinalizedPersistentRoots] mappedCollectionWithBlock: ^ (id uuidString) {
		return [ETUUID UUIDWithString: uuidString];
	}];
	
	ETAssert(transactionIDs.isEmpty || (finalizedPersistentRootUUIDs.isEmpty && compactedPersistentRootUUIDs.isEmpty));

    //NSLog(@"%@: Got change notif for persistent root: %@", self, persistentRootUUID);
    
	BOOL hadChanges = NO;
	
	for (ETUUID *persistentRootUUID in persistentRootUUIDs)
	{
		COPersistentRoot *loaded = [_loadedPersistentRoots objectForKey: persistentRootUUID];

		if (loaded != nil)
		{
			NSNumber *notifTransactionObj = transactionIDs[loaded.UUID.stringValue];
			
			if (notifTransactionObj == nil)
			{
				NSLog(@"Warning, invalid nil transaction id");
				return;
			}
			
			int64_t notifTransaction = [notifTransactionObj longLongValue];

			/* When we have committed the changes explicitly, we send
			   COPersistentRootDidChangeNotification later with 
			   -didCommitWithCommand:persistentRoots: and not now. */
			if (notifTransaction > loaded.lastTransactionID)
			{
				hadChanges = YES;
				/* Will reload every branch info and ensure each one reports 
				   a correct deletion status (critical to update the cross
				   persistent root references). Between 
				   -clearBranchesPendingDeletionAndUndeletion and this point, 
				   COBranch.isDeleted is always NO. */
				[loaded storePersistentRootDidChange: notif isDistributed: isDistributed];
				/* When -[COUndoTrack setCurrentNode:] is used or we receive 
				   another application commit notification, we must update other
				   persistent root references pointing to the loaded one.
				   However when we have committed the changes explicitly, the
				   cross persistent root references have already been updated at
				   commit time, so we have nothing to do (i.e. 
				   notifTransaction > loaded.lastTransactionID is NO). */
				[self updateCrossPersistentRootReferencesToPersistentRoot: loaded
			                                                       branch: nil
			                                                    isDeleted: loaded.isDeleted];
				// TODO: Unload the persistent root when deleted (this represents
				// an external deletion)
			}
		}
		else if (![deletedPersistentRootUUIDs containsObject: persistentRootUUID])
		{
			// The persistent root is not loaded, but it changed in the store.
			// Clear out any stored transaction ID.
			[_lastTransactionIDForPersistentRootUUID removeObjectForKey: persistentRootUUID];
		}
	}
	
	for (ETUUID *persistentRootUUID in compactedPersistentRootUUIDs)
	{
		COPersistentRoot *loaded = [_loadedPersistentRoots objectForKey: persistentRootUUID];
		
		[loaded storePersistentRootDidChange: notif isDistributed: isDistributed];
		hadChanges = YES;
	}
	
	for (ETUUID *persistentRootUUID in finalizedPersistentRootUUIDs)
	{
		__unused COPersistentRoot *loaded = [_loadedPersistentRoots objectForKey: persistentRootUUID];

		// TODO: [self unloadPersistentRoot: loaded]
		// Temporary hack until we have -unloadPersistentRoot:
		[_lastTransactionIDForPersistentRootUUID removeObjectForKey: persistentRootUUID];
		
		hadChanges = YES;
	}
	
	if (hadChanges)
	{
		[[NSNotificationCenter defaultCenter]
			postNotificationName: COEditingContextDidChangeNotification
			              object: self
			            userInfo: nil];
	}
}

#pragma mark Private Conveniency -

- (CORevision *)revisionForRevisionUUID: (ETUUID *)aRevid persistentRootUUID: (ETUUID *)aPersistentRoot
{
    return [_revisionCache revisionForRevisionUUID: aRevid
								persistentRootUUID: aPersistentRoot];
}

- (COBranch *)branchForUUID: (ETUUID *)aBranch
{
	if (aBranch != nil)
	{
		ETUUID *prootUUID = [_store persistentRootUUIDForBranchUUID: aBranch];
		COPersistentRoot *proot = [self persistentRootForUUID: prootUUID];
		return [proot branchForUUID: aBranch];
	}
	return nil;
}

- (NSNumber *)lastTransactionIDForPersistentRootUUID: (ETUUID *)aUUID
{
	return _lastTransactionIDForPersistentRootUUID[aUUID];
}

- (void)setLastTransactionID: (int64_t)lastTransactionID forPersistentRootUUID: (ETUUID *)aUUID
{
	_lastTransactionIDForPersistentRootUUID[aUUID] = @(lastTransactionID);
}

@end


@implementation COEditingContext (Debugging)

- (NSArray *)loadedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(loadedObjects)];
}

- (NSArray *)loadedRootObjects
{
	NSMutableArray *collectedObjects = [NSMutableArray new];
	
	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		for (COObjectGraphContext *objectGraphContext in [persistentRoot allObjectGraphContexts])
		{
			[collectedObjects addObject: [objectGraphContext rootObject]];
		}
	}
	return collectedObjects;
}

- (NSArray *)arrayByCollectingObjectsFromPersistentRootsUsingSelector: (SEL)aSelector
{
	NSMutableArray *collectedObjects = [NSMutableArray new];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		for (COObjectGraphContext *objectGraphContext in [persistentRoot allObjectGraphContexts])
		{
			[collectedObjects addObjectsFromArray: [objectGraphContext performSelector: aSelector]];
		}
	}
	return collectedObjects;
}

- (NSArray *)insertedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(insertedObjects)];
}

- (NSArray *)updatedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(updatedObjects)];
}

- (NSArray *)changedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(changedObjects)];
}

@end

NSString * const COEditingContextDidChangeNotification =
	@"COEditingContextDidChangeNotification";
NSString * const kCOCommandKey = @"kCOCommandKey";

NSString * const COEditingContextDidUnloadPersistentRootsNotification = @"COEditingContextWillUnloadPersistentRootsNotification";
NSString * const kCOUnloadedPersistentRootsKey = @"kCOUnloadedPersistentRootsKey";
