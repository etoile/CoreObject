/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>,
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COBranch.h"
#import "COEditingContext.h"
#import "COEditingContext+Private.h"
#import "COPersistentRoot.h"
#import "COPersistentRoot+Private.h"
#import "COSQLiteStore.h"
#import "COPersistentRootInfo.h"
#import "COObject.h"
#import "CORevision.h"
#import "FMDatabase.h"
#import "CORevisionInfo.h"
#import "COBranchInfo.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COEditingContext+Undo.h"
#import "COLeastCommonAncestor.h"
#import "COItemGraphDiff.h"
#import "COMergeInfo.h"
#import "CORevisionID.h"


NSString * const kCOBranchLabel = @"COBranchLabel";

@implementation COBranch

@synthesize UUID = _UUID;
@synthesize persistentRoot = _persistentRoot;
@synthesize objectGraphContext = _objectGraph;
@synthesize mergingBranch;

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

    _UUID =  aUUID;
        
	/* The persistent root retains us */
	_persistentRoot = aContext;

	if (anObjectGraphContext == nil)
	{
    	_objectGraph = [[COObjectGraphContext alloc] initWithBranch: self];
    }
	else
	{
		_objectGraph =  anObjectGraphContext;
		[anObjectGraphContext setBranch: self];
	}

    if ([_persistentRoot persistentRootInfo] != nil
        && parentRevisionForNewBranch == nil)
    {
        // Loading an existing branch
        
        [self updateWithBranchInfo: [self branchInfo]];
    }
    else
    {
        // Creating a new branch
        
        _currentRevisionID =  parentRevisionForNewBranch;
        _isCreated = NO;
        
        // If _parentRevisionID is nil, we're a new branch for a new persistent root
        // Otherwise, we're a new branch for an existing (committed) persistent root
        
        if (_currentRevisionID != nil)
        {
            id<COItemGraph> aGraph = [[_persistentRoot store] itemGraphForRevisionID: _currentRevisionID];
            [_objectGraph setItemGraph: aGraph];
            
            ETAssert(![_objectGraph hasChanges]);
        }
        
        _metadata = [[NSMutableDictionary alloc] init];
    }
    
	return self;	
}

- (COEditingContext *) editingContext
{
    return [_persistentRoot editingContext];
}

- (BOOL) isBranchUncommitted
{
    return _isCreated == NO;
}

- (BOOL) isBranchPersistentRootUncommitted
{
    return _currentRevisionID == nil && _isCreated == NO;
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
    
    [_persistentRoot setBranchDeleted: self];
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

- (CORevision *)currentRevision
{
    // WARNING: Accesses store
    CORevisionInfo *info = [self currentRevisionInfo];
    if (info != nil)
    {
        return [[CORevision alloc] initWithStore: [[self persistentRoot] store]
                                     revisionInfo: info];
    }
    return nil;
}

- (void) setCurrentRevision:(CORevision *)currentRevision
{
    NILARG_EXCEPTION_TEST(currentRevision);
    
    _currentRevisionID =  [currentRevision revisionID];
    [self reloadAtRevision: currentRevision];
}

- (COBranch *)parentBranch
{
    // FIXME: Add support for this
    return nil;
}

- (BOOL)hasChanges
{
    if ([self isBranchUncommitted])
    {
        return YES;
    }
    
    if (_metadataChanged)
    {
        return YES;
    }
    
    if (![[[self branchInfo] currentRevisionID] isEqual: _currentRevisionID])
    {
        return YES;
    }
    
    if (_deleted != [[self branchInfo] isDeleted])
    {
        return YES;
    }
    
	return [[self objectGraphContext] hasChanges];
}

- (void)discardAllChanges
{
    if ([self isBranchUncommitted])
    {
        [NSException raise: NSGenericException format: @"uncommitted branches do not support -discardAllChanges"];
    }
    
	if (_metadataChanged)
    {
        if ([self isBranchUncommitted])
        {
            [_metadata removeAllObjects];
        }
        else
        {
            _metadata = [NSMutableDictionary dictionaryWithDictionary:
                               [[self branchInfo] metadata]];
        }
        _metadataChanged = NO;
    }
    
    if (![[[self branchInfo] currentRevisionID] isEqual: _currentRevisionID])
    {
        [self setCurrentRevision:
         [CORevision revisionWithStore: [self store]
                            revisionID: [[self branchInfo] currentRevisionID]]];
    }
    
    if (_deleted != [[self branchInfo] isDeleted])
    {
        [self setDeleted: [[self branchInfo] isDeleted]];
    }
    
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

- (BOOL)needsReloadNodes: (NSArray *)currentLoadedNodes
{
	return NO;
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
    
	if ([self isBranchUncommitted])
	{
        // N.B. - this only the case when we're adding a new branch to an existing persistent root.
        
        [store createBranchWithUUID: _UUID
                    initialRevision: _currentRevisionID
                  forPersistentRoot: [[self persistentRoot] persistentRootUUID]
                              error: NULL];
        [[self editingContext] recordBranchCreation: self];
        
        _isCreated = YES;
    }
    else if (![[[self branchInfo] currentRevisionID] isEqual: _currentRevisionID])
    {
        // This is the case when the user does [self setCurrentRevision: ], and then commits
        
        BOOL ok = [store setCurrentRevision: _currentRevisionID
                               tailRevision: nil
                                  forBranch: _UUID
                           ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                                      error: NULL];
        ETAssert(ok);
        
        CORevisionID *old = [[self branchInfo] currentRevisionID];
        [[self editingContext] recordBranchSetCurrentRevision: self
                                                oldRevisionID: old];
    }
    
    // Write metadata
    
    if (_metadataChanged)
    {
        BOOL ok = [store setMetadata: _metadata
                           forBranch: _UUID
                    ofPersistentRoot: [[self persistentRoot]    persistentRootUUID]
                               error: NULL];
        ETAssert(ok);
        
        [[self editingContext] recordBranchSetMetadata: self
                                           oldMetadata: [[self branchInfo] metadata]];
        
        _metadataChanged = NO;
    }
    
    // Write a regular commit
    
    NSArray *changedItemUUIDs = [(NSSet *)[[[_objectGraph changedObjects] mappedCollection] UUID] allObjects];
    if ([changedItemUUIDs count] > 0)
    {
        CORevisionID *mergeParent = nil;
        if (self.mergingBranch != nil)
        {
            mergeParent = [[self.mergingBranch currentRevision] revisionID];
            self.mergingBranch = nil;
        }
        
        CORevisionID *revId = [store writeRevisionWithItemGraph: _objectGraph
                                                       metadata: metadata
                                               parentRevisionID: _currentRevisionID
                                          mergeParentRevisionID: mergeParent
                                                  modifiedItems: changedItemUUIDs
                                             error: NULL];        
        
        BOOL ok = [store setCurrentRevision: revId
                               tailRevision: nil
                                  forBranch: _UUID
                           ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                                      error: NULL];
        ETAssert(ok);
        
        CORevisionID *oldRevid = _currentRevisionID;
        _currentRevisionID =  revId;
        
        [[self editingContext] recordBranchSetCurrentRevision: self
                                                oldRevisionID: oldRevid];
    }

    // Write branch undeletion
    
    if (!_deleted && [[self branchInfo] isDeleted])
    {
        ETAssert([store undeleteBranch: _UUID
                      ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                                 error: NULL]);
        [[self editingContext] recordBranchUndeletion: self];
    }
    
	[_objectGraph clearChangeTracking];
}

- (void)saveDeletion
{
    COSQLiteStore *store = [self store];
    
    // Write branch deletion
    
    if (_deleted && ![[self branchInfo] isDeleted])
    {
        ETAssert([store deleteBranch: _UUID
                    ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                               error: NULL]);
        [[self editingContext] recordBranchDeletion: self];
    }    
}

- (void)didMakeInitialCommitWithRevisionID: (CORevisionID *)aRevisionID
{
    // Write metadata
    // FIXME: Copied-n-pasted from above
    if (_metadataChanged)
    {
        BOOL ok = [[_persistentRoot store] setMetadata: _metadata
                                             forBranch: _UUID
                                      ofPersistentRoot: [[self persistentRoot] persistentRootUUID]
                                                 error: NULL];
        ETAssert(ok);
        
        [[self editingContext] recordBranchSetMetadata: self
                                           oldMetadata: [[self branchInfo] metadata]];
        
        _metadataChanged = NO;
    }
    
    ETAssert(_isCreated == NO);
    
    _currentRevisionID =  aRevisionID;
    _isCreated = YES;
    
    [_objectGraph clearChangeTracking];
    
    ETAssert([[_objectGraph changedObjects] count] == 0);
}

- (void)reloadAtRevision: (CORevision *)revision
{
    NSParameterAssert(revision != nil);
    
    // TODO: Use optimized method on the store to get a delta for more performance
    
	id<COItemGraph> aGraph = [[self store] itemGraphForRevisionID: [revision revisionID]];
    
    [_objectGraph setItemGraph: aGraph];
    
    [_persistentRoot sendChangeNotification];
}

- (CORevision *) revisionWithID: (CORevisionID *)aRevisionID
{
    CORevision *oldest = [self parentRevision];
    CORevision *rev = [self currentRevision];
    do
    {
        if ([[rev revisionID] isEqual: aRevisionID])
        {
            return rev;
        }
    }
    while (![rev isEqual: oldest]);
    
    return nil;
}

- (COMergeInfo *) mergeInfoForMergingBranch: (COBranch *)aBranch
{
    CORevisionID *lca = [COLeastCommonAncestor commonAncestorForCommit: [[aBranch currentRevision] revisionID]
                                                             andCommit: [[self currentRevision] revisionID]
                                                                 store: [self store]];
    id <COItemGraph> baseGraph = [[self store] itemGraphForRevisionID: lca];
    
    return [self diffForMergingGraphWithSelf: [aBranch objectGraphContext]
                                  revisionID: [[aBranch currentRevision] revisionID]
                                   baseGraph: baseGraph
                              baseRevisionID: lca];
}

- (COMergeInfo *) mergeInfoForMergingRevision:(CORevision *)aRevision
{
    CORevisionID *lca = [COLeastCommonAncestor commonAncestorForCommit: [aRevision revisionID]
                                                             andCommit: [[self currentRevision] revisionID]
                                                                 store: [self store]];
    id <COItemGraph> baseGraph = [[self store] itemGraphForRevisionID: lca];
    id <COItemGraph> mergeGraph = [[self store] itemGraphForRevisionID: [aRevision revisionID]];

    return [self diffForMergingGraphWithSelf: mergeGraph
                                  revisionID: [aRevision revisionID]
                                   baseGraph: baseGraph
                              baseRevisionID: lca];
}

- (COMergeInfo *) diffForMergingGraphWithSelf: (id <COItemGraph>) mergeGraph
                                       revisionID: (CORevisionID *) mergeRevisionID
                                        baseGraph: (id <COItemGraph>) baseGraph
                                   baseRevisionID: (CORevisionID *)aBaseRevisionID
{
    COItemGraphDiff *mergingBranchDiff = [COItemGraphDiff diffItemTree: baseGraph withItemTree: mergeGraph sourceIdentifier: @"merged"];
    COItemGraphDiff *selfDiff = [COItemGraphDiff diffItemTree: baseGraph withItemTree: [self objectGraphContext] sourceIdentifier: @"self"];
    
    COItemGraphDiff *merged = [selfDiff itemTreeDiffByMergingWithDiff: mergingBranchDiff];

    COMergeInfo *result = [[COMergeInfo alloc] init];
    result.mergeDestinationRevision = [self currentRevision];
    result.mergeSourceRevision = [CORevision revisionWithStore: [self store] revisionID: mergeRevisionID];
    result.baseRevision =[CORevision revisionWithStore: [self store] revisionID: aBaseRevisionID];
    result.diff = merged;
    return result;
}

- (void) updateWithBranchInfo: (COBranchInfo *)branchInfo
{
    ETAssert(branchInfo != nil);
    
    _currentRevisionID =  [branchInfo currentRevisionID];
    _metadata =  [NSMutableDictionary dictionaryWithDictionary:[branchInfo metadata]];
    _isCreated = YES;
    _deleted = [branchInfo isDeleted];
    
    id<COItemGraph> aGraph = [[_persistentRoot store] itemGraphForRevisionID: _currentRevisionID];
    [_objectGraph setItemGraph: aGraph];
}

- (id) rootObject
{
    return [_objectGraph rootObject];
}

@end
