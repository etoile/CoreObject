/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>,
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COBranch.h"
#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COSQLiteStore.h"
#import "COPersistentRootInfo.h"
#import "COObject.h"
#import "CORevision.h"
#import "FMDatabase.h"
#import "CORevisionInfo.h"
#import "COBranchInfo.h"
#import "COObjectGraphContext.h"

NSString * const kCOBranchLabel = @"COBranchLabel";

@implementation COBranch

@synthesize UUID = _UUID;
@synthesize persistentRoot = _persistentRoot;
@synthesize objectGraphContext = _objectGraph;

- (id)init
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

/* Both root object and revision are lazily retrieved by the persistent root. 
   Until the loaded revision is known, it is useless to cache track nodes. */
- (id)        initWithUUID: (ETUUID *)aUUID
        objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
            persistentRoot: (COPersistentRoot *)aContext
parentRevisionForNewBranch: (CORevisionID *)parentRevisionForNewBranch
{
	NILARG_EXCEPTION_TEST(aUUID);
	NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
	NILARG_EXCEPTION_TEST(aContext);
	INVALIDARG_EXCEPTION_TEST(anObjectGraphContext,
		anObjectGraphContext == nil || [anObjectGraphContext branch] == nil);
							  
	if ([[aContext parentContext] store] == nil)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Cannot load commit track for %@ which does not have a store or editing context", aContext];
	}

	SUPERINIT;

    ASSIGN(_UUID, aUUID);
        
	/* The persistent root retains us */
	_persistentRoot = aContext;

	if (anObjectGraphContext == nil)
	{
    	_objectGraph = [[COObjectGraphContext alloc] initWithBranch: self];
    }
	else
	{
		ASSIGN(_objectGraph, anObjectGraphContext);
		[anObjectGraphContext setBranch: self];
	}

    if ([_persistentRoot persistentRootInfo] != nil
        && parentRevisionForNewBranch == nil)
    {
        // Loading an existing branch
        
        COBranchInfo *branchInfo = [self branchInfo];
        ETAssert(branchInfo != nil);
        
        ASSIGN(_currentRevisionID, [branchInfo currentRevisionID]);
        _metadata = [[NSMutableDictionary alloc] initWithDictionary:[branchInfo metadata]];
        _isCreated = YES;
        _deleted = [branchInfo isDeleted];
        
        id<COItemGraph> aGraph = [[_persistentRoot store] contentsForRevisionID: _currentRevisionID];
        [_objectGraph setItemGraph: aGraph];
    }
    else
    {
        // Creating a new branch
        
        ASSIGN(_currentRevisionID, parentRevisionForNewBranch);
        _isCreated = NO;
        
        // If _parentRevisionID is nil, we're a new branch for a new persistent root
        // Otherwise, we're a new branch for an existing (committed) persistent root
        
        if (_currentRevisionID != nil)
        {
            id<COItemGraph> aGraph = [[_persistentRoot store] contentsForRevisionID: _currentRevisionID];
            [_objectGraph setItemGraph: aGraph];
            
            ETAssert(![_objectGraph hasChanges]);
        }
        
        _metadata = [[NSMutableDictionary alloc] init];
    }
    
	return self;	
}


- (void)dealloc
{
	DESTROY(_UUID);
    DESTROY(_currentRevisionID);
    DESTROY(_metadata);
    DESTROY(_objectGraph);
	[super dealloc];
}

- (BOOL) isBranchUncommitted
{
    return _isCreated == NO;
}

- (BOOL) isBranchPersistentRootUncommitted
{
    return _currentRevisionID == nil && _isCreated == NO;
}

- (NSUInteger)hash
{
    return [_UUID hash];
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [COBranch class]])
	{
        if (_persistentRoot == [rhs persistentRoot])
        {
            return self == rhs;
        }
        
		return ([_UUID isEqual: [rhs UUID]]
			&& [[_persistentRoot persistentRootUUID] isEqual: [[rhs persistentRoot] persistentRootUUID]]);
	}
	return NO;
}

- (NSString *)displayName
{
	NSString *label = [self label];
	NSString *displayName = [[[self persistentRoot] rootObject] displayName];
	
	if (label != nil && [label isEqual: @""] == NO)
	{
		displayName = [displayName stringByAppendingFormat: @" (%@)", label];
	}
	return displayName;
}

- (BOOL)isCopy
{
    // FIXME: Implement
    return NO;
}

- (BOOL)isBranch
{
    return YES;
//	return ([self isCopy] == NO && [self parentTrack] != nil);
}

- (BOOL)isCurrentBranch
{
    return self == [_persistentRoot currentBranch];
}

- (BOOL)isTrunkBranch
{
	// FIXME: Implement by reading from our metadata dictionary
	return NO;
}

- (COBranchInfo *) branchInfo
{
    COPersistentRootInfo *persistentRootInfo = [[self persistentRoot] persistentRootInfo];
    COBranchInfo *branchInfo = [persistentRootInfo branchInfoForUUID: _UUID];
    return branchInfo;
}

- (CORevisionInfo *) currentRevisionInfo
{
    // WARNING: Accesses store
    CORevisionID *revid = _currentRevisionID;
    COSQLiteStore *store = [[self persistentRoot] store];
    
    if (revid != nil)
    {
        return [store revisionInfoForRevisionID: revid];
    }
    return nil;
}

- (NSDictionary *)metadata
{
	return [NSDictionary dictionaryWithDictionary: _metadata];
}

- (void)setMetadata: (NSDictionary *)aMetadata
{
    [_metadata setDictionary: aMetadata];
    _metadataChanged = YES;
}

- (NSString *)label
{
	return [_metadata objectForKey: kCOBranchLabel];
}

- (void)setLabel: (NSString *)aLabel
{
	[_metadata setObject: aLabel forKey: kCOBranchLabel];
    _metadataChanged = YES;
}


- (BOOL)isDeleted
{
    return _deleted;
}

- (void) setDeleted:(BOOL)deleted
{
    if (deleted)
    {
        if ([self isCurrentBranch])
        {
            [NSException raise: NSGenericException format: @"Can't delete the current branch"];
        }
        if (self == [_persistentRoot editingBranch])
        {
            [NSException raise: NSGenericException format: @"Can't delete the editing branch"];
        }
    }
    
    _deleted = deleted;
    
    [_persistentRoot updateCrossPersistentRootReferences];
}

- (CORevision *)parentRevision
{
    // WARNING: Accesses store
    CORevisionID *revid = [[self branchInfo] tailRevisionID];
    COSQLiteStore *store = [[self persistentRoot] store];
    
    if (revid != nil)
    {
        return [CORevision revisionWithStore: store revisionID: revid];
    }
    
    return nil;
}

- (CORevision *)newestRevision
{
    // WARNING: Accesses store
    CORevisionID *revid = [[self branchInfo] headRevisionID];
    COSQLiteStore *store = [[self persistentRoot] store];
    
    if (revid != nil)
    {
        return [CORevision revisionWithStore: store revisionID: revid];
    }
    
    return nil;
}

- (CORevision *)currentRevision
{
    // WARNING: Accesses store
    CORevisionInfo *info = [self currentRevisionInfo];
    if (info != nil)
    {
        return [[[CORevision alloc] initWithStore: [[self persistentRoot] store]
                                     revisionInfo: info] autorelease];
    }
    return nil;
}

- (void) setCurrentRevision:(CORevision *)currentRevision
{
    ASSIGN(_currentRevisionID, [currentRevision revisionID]);
    [self reloadAtRevision: currentRevision];
}

- (COBranch *)parentBranch
{
    // FIXME: Add support for this
    return nil;
}

- (BOOL)hasChanges
{
    if (_metadataChanged)
    {
        return YES;
    }
    
    // TODO: Take into account reverts that change _currentRevisionID
    
	return [[self objectGraphContext] hasChanges];
}

- (void)discardAllChanges
{
	// TODO: Cancel branch renaming and metadata changes
	[[self objectGraphContext] discardAllChanges];
}

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel
{
    if ([self isBranchUncommitted])
    {
        [NSException raise: NSGenericException format: @"uncommitted branches do not support -makeBranchWithLabel:"];
    }
    
	return [self makeBranchWithLabel: aLabel atRevision: [self currentRevision]];
}

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev
{
    if ([self isBranchUncommitted])
    {
        /*
         Explanation for this restriction: 
         we could in theory support creating an arbitrary tree of uncommitted branches,
         or branches on an uncommitted persistent root, and commit them all in one batch.
         
         The reason for not supporting it is it would just make the commit logic more complex, doing a
         graph DFS on the branches and making a commit (if needed) as it visits each branch.
         */
        [NSException raise: NSGenericException format: @"uncommitted branches do not support -makeBranchWithLabel:atRevision:"];
    }
    
    return [_persistentRoot makeBranchWithLabel: aLabel atRevision: aRev];
}

- (COPersistentRoot *)makeCopyFromRevision: (CORevision *)aRev
{
    return [[[self persistentRoot] editingContext] insertNewPersistentRootWithRevisionID: [aRev revisionID]];
}

- (BOOL)mergeChangesFromTrack: (COBranch *)aSourceTrack
{
	return NO;
}

- (BOOL)mergeChangesFromRevision: (CORevision *)startRev
							  to: (CORevision *)endRev
						 ofTrack: (COBranch *)aSourceTrack
{
	return NO;
}

- (BOOL)mergeChangesFromRevisionSet: (NSSet *)revs
							ofTrack: (COBranch *)aSourceTrack
{
	return NO;
}

- (BOOL)isOurStoreForNotification: (NSNotification *)notif
{
    // FIXME: Implement
    return YES;
//	NSString *storeUUIDString = [[notif userInfo] objectForKey: kCOStoreUUIDStringKey];
//	return [storeUUIDString isEqual: [[[[self persistentRoot] store] UUID] stringValue]];
}

- (BOOL)needsReloadNodes: (NSArray *)currentLoadedNodes
{
	return NO;
}

- (NSArray *)allNodesAndCurrentNodeIndex: (NSUInteger *)aNodeIndex
{
    return [NSArray array];
//	// NOTE: For a new track, -[COSQLStore isTrackUUID:] would return NO
//	
//	COStore *store = [[self persistentRoot] store];
//	return [store nodesForTrackUUID: [self UUID]
//	                    nodeBuilder: self
//	               currentNodeIndex: aNodeIndex
//	                  backwardLimit: NSUIntegerMax
//	                   forwardLimit: NSUIntegerMax];
}

- (NSArray *)provideNodesAndCurrentNodeIndex: (NSUInteger *)aNodeIndex
{
	return [self allNodesAndCurrentNodeIndex: aNodeIndex];
}

- (void)undo
{
    CORevision *revision = [[self currentRevision] parentRevision];
    if (revision == nil)
    {
        return;
    }
    [self setCurrentRevision: revision];
}

- (void)redo
{
    CORevision *currentRevision = [self currentRevision];
    CORevision *revision = [self newestRevision];
    
    if ([currentRevision isEqual: revision])
    {
        return;
    }
    
    while (revision != nil)
    {
        CORevision *revisionParent = [revision parentRevision];
        if ([revisionParent isEqual: currentRevision])
        {
            [self setCurrentRevision: revision];
            return;
        }
        revision = revisionParent;
    }
}
- (COSQLiteStore *) store
{
    return [_persistentRoot store];
}

- (void)saveCommitWithMetadata: (NSDictionary *)metadata
{
	ETAssert([[_objectGraph rootObject] isRoot]);
    ETAssert(![self isBranchPersistentRootUncommitted]);
    ETAssert(_currentRevisionID != nil);
    
	COSQLiteStore *store = [self store];
    
    int64_t changeCount = [[_persistentRoot persistentRootInfo] changeCount];
    
	if ([self isBranchUncommitted])
	{
        // N.B. - this only the case when we're adding a new branch to an existing persistent root.
        
        [store createBranchWithUUID: _UUID
                    initialRevision: _currentRevisionID
                  forPersistentRoot: [[self persistentRoot] persistentRootUUID]
                              error: NULL];
        
        _isCreated = YES;
    }
    else if (![[[self branchInfo] currentRevisionID] isEqual: _currentRevisionID])
    {
        // This is the case when the user does [self setCurrentRevision: ], and then commits
        
        BOOL ok = [store setCurrentRevision: _currentRevisionID
                               headRevision: nil /* This is the case when we're reverting, so don't update headRevision */
                               tailRevision: nil
                                  forBranch: _UUID
                           ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                         currentChangeCount: &changeCount
                                      error: NULL];
        ETAssert(ok);
    }
    
    // Write metadata
    
    if (_metadataChanged)
    {
        BOOL ok = [store setMetadata: _metadata
                           forBranch: _UUID
                    ofPersistentRoot: [[self persistentRoot]    persistentRootUUID]
                               error: NULL];
        ETAssert(ok);
        _metadataChanged = NO;
    }
    
    
    NSArray *changedItemUUIDs = [(NSSet *)[[[_objectGraph changedObjects] mappedCollection] UUID] allObjects];
    if ([changedItemUUIDs count] > 0)
    {
        CORevisionID *revId = [store writeContents: _objectGraph
                                      withMetadata: metadata
                                  parentRevisionID: _currentRevisionID
                                     modifiedItems: changedItemUUIDs
                                             error: NULL];        
        
        BOOL ok = [store setCurrentRevision: revId
                               headRevision: revId
                               tailRevision: nil
                                  forBranch: _UUID
                           ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                         currentChangeCount: &changeCount
                                      error: NULL];
        ETAssert(ok);
        
        ASSIGN(_currentRevisionID, revId);
    }
	
    if (_deleted && ![[self branchInfo] isDeleted])
    {
        ETAssert([store deleteBranch: _UUID
                    ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                               error: NULL]);
    }
    else if (!_deleted && [[self branchInfo] isDeleted])
    {
        ETAssert([store undeleteBranch: _UUID
                      ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                                 error: NULL]);
    }
    
	[_objectGraph clearChangeTracking];
}

- (void)didMakeInitialCommitWithRevisionID: (CORevisionID *)aRevisionID
{
    ETAssert(_isCreated == NO);
    
    ASSIGN(_currentRevisionID, aRevisionID);
    _isCreated = YES;
    
    [_objectGraph clearChangeTracking];
    
    ETAssert([[_objectGraph changedObjects] count] == 0);
}

- (void)reloadAtRevision: (CORevision *)revision
{
    NSParameterAssert(revision != nil);
    
    // TODO: Use optimized method on the store to get a delta for more performance
    
	id<COItemGraph> aGraph = [[self store] contentsForRevisionID: [revision revisionID]];
    
    [_objectGraph setItemGraph: aGraph];
    
    // FIXME: Reimplement or remove
    //[[self rootObject] didReload];
}

@end
