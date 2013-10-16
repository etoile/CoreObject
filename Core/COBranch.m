/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>,
	         Quentin Mathe <quentin.mathe@gmail.com>,
	         Eric Wasylishen <ewasylishen@gmail.com>
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
#import "CORevisionCache.h"

NSString * const kCOBranchLabel = @"COBranchLabel";

@implementation COBranch

@synthesize UUID = _UUID;
@synthesize persistentRoot = _persistentRoot;
@synthesize objectGraphContext = _objectGraph;
@synthesize mergingBranch;
@synthesize shouldMakeEmptyCommit;

+ (void) initialize
{
	if (self != [COBranch class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

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
          parentBranchUUID: (ETUUID *)aParentBranchUUID
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
    _parentBranchUUID = aParentBranchUUID;
    
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
        
        _currentRevisionID = parentRevisionForNewBranch;
		_newestRevisionID = parentRevisionForNewBranch;
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
    if ([[_persistentRoot branchesPendingUndeletion] containsObject: self])
        return NO;
    
    if ([[_persistentRoot branchesPendingDeletion] containsObject: self])
        return YES;

    if ([[_persistentRoot deletedBranches] containsObject: self])
        return YES;
    
    return NO;
}

- (void) setDeleted:(BOOL)deleted
{
    if (deleted)
    {
		// TODO: Use a CoreObject exception type
        if ([self isCurrentBranch])
        {
            [NSException raise: NSGenericException
			            format: @"Can't delete the current branch"];
        }
        if (self == [_persistentRoot editingBranch])
        {
            [NSException raise: NSGenericException
			            format: @"Can't delete the editing branch"];
        }
    }
    
    if (deleted)
    {
        [_persistentRoot deleteBranch: self];
    }
    else
    {
        [_persistentRoot undeleteBranch: self];
    }
}

- (CORevision *)initialRevision
{
    CORevisionID *revid = [[self branchInfo] initialRevisionID];
    
    if (revid != nil)
    {
        return [[self editingContext] revisionForRevisionID: revid];
    }
    
    return nil;
}

- (CORevision *)firstRevision
{
	COBranch *branch = self;

	while ([branch parentBranch] != nil)
	{
		branch = [branch parentBranch];
	}
	return [branch initialRevision];
}

- (CORevision *)headRevision
{
    if (_newestRevisionID != nil)
    {
        return [[self editingContext] revisionForRevisionID: _newestRevisionID];
    }
    
    return nil;
}

- (void)setHeadRevision: (CORevision *)aRevision
{
	NILARG_EXCEPTION_TEST(aRevision);

	_newestRevisionID = [aRevision revisionID];
}


- (CORevision *)currentRevision
{
    if (_currentRevisionID != nil)
    {
        return [[self editingContext] revisionForRevisionID: _currentRevisionID];
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
    return [_persistentRoot branchForUUID: _parentBranchUUID];
}

- (BOOL)hasChangesOtherThanDeletionOrUndeletion
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
    
	if (![[[self branchInfo] headRevisionID] isEqual: _newestRevisionID])
    {
        return YES;
    }
	
    if (self.shouldMakeEmptyCommit)
    {
        return YES;
    }
    
	return [[self objectGraphContext] hasChanges];
}

- (BOOL)hasChanges
{
    if ([self isDeleted] != [[self branchInfo] isDeleted])
    {
        return YES;
    }
	return [self hasChangesOtherThanDeletionOrUndeletion];
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
            [[self editingContext] revisionForRevisionID: [[self branchInfo] currentRevisionID]]];
    }

	if (![[[self branchInfo] headRevisionID] isEqual: _newestRevisionID])
    {
        [self setHeadRevision:
		 [[self editingContext] revisionForRevisionID: [[self branchInfo] headRevisionID]]];
    }
	
    if ([self isDeleted] != [[self branchInfo] isDeleted])
    {
        [self setDeleted: [[self branchInfo] isDeleted]];
    }
    
    self.shouldMakeEmptyCommit = NO;
    
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
    NILARG_EXCEPTION_TEST(aRev);
    
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
    
    return [_persistentRoot makeBranchWithLabel: aLabel atRevision: aRev parentBranch: self];
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

- (CORevision *)undoRevision
{
    if ([[self initialRevision] isEqual: [self currentRevision]])
    {
        return nil;
    }
    
    CORevision *revision = [[self currentRevision] parentRevision];
    return revision;
}

- (BOOL)canUndo
{
    return [self undoRevision] != nil;
}

- (void)undo
{
    [self setCurrentRevision: [self undoRevision]];
}

- (CORevision *)redoRevision
{
    CORevision *currentRevision = [self currentRevision];
    CORevision *revision = [self headRevision];
    
    if ([currentRevision isEqual: revision])
    {
        return nil;
    }
    
    while (revision != nil)
    {
        CORevision *revisionParent = [revision parentRevision];
        if ([revisionParent isEqual: currentRevision])
        {
            return revision;
        }
        revision = revisionParent;
    }
    return revision;
}

- (BOOL)canRedo
{
    return [self redoRevision] != nil;
}

- (void)redo
{
    [self setCurrentRevision: [self redoRevision]];
}

- (COSQLiteStore *) store
{
    return [_persistentRoot store];
}

- (void)saveCommitWithMetadata: (NSDictionary *)metadata
{
	if ([self hasChangesOtherThanDeletionOrUndeletion]
		&& [[self branchInfo] isDeleted]
		&& self.isDeleted)
	{
		[NSException raise: NSGenericException
					format: @"Attempted to commit changes to deleted branch %@", self];
	}
	
	ETAssert([[_objectGraph rootObject] isRoot]);
    ETAssert(![self isBranchPersistentRootUncommitted]);
    ETAssert(_currentRevisionID != nil);
    ETAssert(_newestRevisionID != nil);
    
	COSQLiteStore *store = [self store];
    
	if ([self isBranchUncommitted])
	{
        // N.B. - this only the case when we're adding a new branch to an existing persistent root.
        
        [store createBranchWithUUID: _UUID
                       parentBranch: _parentBranchUUID
                    initialRevision: _currentRevisionID
                  forPersistentRoot: [[self persistentRoot] UUID]
                              error: NULL];
        
        [[self editingContext] recordBranchCreation: self];
        
        _isCreated = YES;
    }
    else if (![[[self branchInfo] currentRevisionID] isEqual: _currentRevisionID]
			 || ![[[self branchInfo] headRevisionID] isEqual: _newestRevisionID] )
    {
        CORevisionID *old = [[self branchInfo] currentRevisionID];
        assert(old != nil);
		
		CORevisionID *oldHead = [[self branchInfo] headRevisionID];
        
        // This is the case when the user does [self setCurrentRevision: ], and then commits
        
        BOOL ok = [store setCurrentRevision: _currentRevisionID
							initialRevision: nil
                               headRevision: _newestRevisionID
                                  forBranch: _UUID
                           ofPersistentRoot: [[self persistentRoot] UUID]
                                      error: NULL];
        ETAssert(ok);
        

        [[self editingContext] recordBranchSetCurrentRevisionID: _currentRevisionID
                                                  oldRevisionID: old
												 headRevisionID: _newestRevisionID
											  oldHeadRevisionID: oldHead
                                                       ofBranch: self];
    }
    
    // Write metadata
    
    if (_metadataChanged)
    {
        BOOL ok = [store setMetadata: _metadata
                           forBranch: _UUID
                    ofPersistentRoot: [[self persistentRoot]    UUID]
                               error: NULL];
        ETAssert(ok);
        
        [[self editingContext] recordBranchSetMetadata: self
                                           oldMetadata: [[self branchInfo] metadata]];
        
        _metadataChanged = NO;
    }
    
    // Write a regular commit
    
    NSArray *changedItemUUIDs = [(NSSet *)[[[_objectGraph changedObjects] mappedCollection] UUID] allObjects];
    if ([changedItemUUIDs count] > 0 || self.shouldMakeEmptyCommit)
    {
        CORevisionID *mergeParent = nil;
        if (self.mergingBranch != nil)
        {
            mergeParent = [[self.mergingBranch currentRevision] revisionID];
            self.mergingBranch = nil;
        }
        
        CORevisionID *revId = [store writeRevisionWithItemGraph: [self modifiedItemsSnapshot]
                                                   revisionUUID: [ETUUID UUID]
                                                       metadata: metadata
                                               parentRevisionID: _currentRevisionID
                                          mergeParentRevisionID: mergeParent
		                                             branchUUID: _UUID
                                             persistentRootUUID: [_persistentRoot UUID]
                                                          error: NULL];        
        
        BOOL ok = [store setCurrentRevision: revId
                            initialRevision: nil
                               headRevision: revId
                                  forBranch: _UUID
                           ofPersistentRoot: [[self persistentRoot] UUID]
                                      error: NULL];
        ETAssert(ok);
        
        CORevisionID *oldRevid = _currentRevisionID;
		CORevisionID *oldHeadRevid = _newestRevisionID;
        assert(oldRevid != nil);
        assert(oldHeadRevid != nil);
        assert(revId != nil);
        _currentRevisionID = revId;
		_newestRevisionID = revId;
        self.shouldMakeEmptyCommit = NO;
        
        [[self editingContext] recordBranchSetCurrentRevisionID: _currentRevisionID
                                                  oldRevisionID: oldRevid
												 headRevisionID: _currentRevisionID
											  oldHeadRevisionID: oldHeadRevid
                                                       ofBranch: self];
    }

    // Write branch undeletion
    
    if (![self isDeleted] && [[self branchInfo] isDeleted])
    {
        ETAssert([store undeleteBranch: _UUID
                      ofPersistentRoot: [[self persistentRoot] UUID]
                                 error: NULL]);
        [[self editingContext] recordBranchUndeletion: self];
    }
    
	[_objectGraph clearChangeTracking];
}

- (void)saveDeletion
{
    COSQLiteStore *store = [self store];
    
    // Write branch deletion
    
    if ([self isDeleted] && ![[self branchInfo] isDeleted])
    {
        ETAssert([store deleteBranch: _UUID
                    ofPersistentRoot: [[self persistentRoot] UUID]
                               error: NULL]);
        [[self editingContext] recordBranchDeletion: self];
    }    
}

- (void)didMakeInitialCommitWithRevisionID: (CORevisionID *)aRevisionID
{
    assert(aRevisionID != nil);
    
    // Write metadata
    // FIXME: Copied-n-pasted from above
    if (_metadataChanged)
    {
        BOOL ok = [[_persistentRoot store] setMetadata: _metadata
                                             forBranch: _UUID
                                      ofPersistentRoot: [[self persistentRoot] UUID]
                                                 error: NULL];
        ETAssert(ok);
        
        [[self editingContext] recordBranchSetMetadata: self
                                           oldMetadata: [[self branchInfo] metadata]];
        
        _metadataChanged = NO;
    }
    
    ETAssert(_isCreated == NO);
    
    _currentRevisionID =  aRevisionID;
	_newestRevisionID = aRevisionID;
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
    CORevision *oldest = [self initialRevision];
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
    result.mergeSourceRevision = [[self editingContext] revisionForRevisionID: mergeRevisionID];
    result.baseRevision = [[self editingContext] revisionForRevisionID: aBaseRevisionID];
    result.diff = merged;
    return result;
}

- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (void)updateRevisions
{
	CORevision *currentRev = [[self editingContext] revisionForRevisionID: _currentRevisionID];

	if ([currentRev isEqual: [_revisions lastObject]] || _revisions == nil)
		return;

	BOOL isNewCommit = [[currentRev parentRevision] isEqual: [_revisions lastObject]];

	if (isNewCommit)
	{
		[_revisions addObject: currentRev];
	}
	else
	{
		// TODO: Optimize to reload just the new nodes
		[self reloadRevisions];
	}
	[self didUpdate];
}

- (void) updateWithBranchInfo: (COBranchInfo *)branchInfo
{
    ETAssert(branchInfo != nil);
    
    _currentRevisionID =  [branchInfo currentRevisionID];
	_newestRevisionID = [branchInfo headRevisionID];
    _metadata =  [NSMutableDictionary dictionaryWithDictionary:[branchInfo metadata]];
    _isCreated = YES;
    
    id<COItemGraph> aGraph = [[_persistentRoot store] itemGraphForRevisionID: _currentRevisionID];
    [_objectGraph setItemGraph: aGraph];
	
	[self updateRevisions];
}

- (id) rootObject
{
    return [_objectGraph rootObject];
}

- (COItemGraph *) modifiedItemsSnapshot
{
    NSSet *objects;
    
    if (_currentRevisionID == nil)
    {
        objects = [_objectGraph loadedObjects];
    }
    else
    {
        objects = [_objectGraph changedObjects];
    }
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    for (COObject *obj in objects)
    {
        COItem *item = [_objectGraph itemForUUID: [obj UUID]];
        [dict setObject: item forKey: [obj UUID]];
    }
    
    return [[COItemGraph alloc] initWithItemForUUID: dict rootItemUUID: [[self objectGraphContext] rootItemUUID]];
}

- (NSMutableArray *)revisionsWithOptions: (COBranchRevisionReadingOptions)options
{
	NSArray *revInfos = [[self store] revisionInfosForBranchUUID: [self UUID]
	                                                     options: options];
	NSMutableArray *revs = [NSMutableArray array];
	CORevisionCache *cache =
		[CORevisionCache cacheForStoreUUID: [[[self editingContext] store] UUID]];

	for (CORevisionInfo *revInfo in revInfos)
	{
		[revs addObject: [[CORevision alloc] initWithCache: cache
		                                      revisionInfo: revInfo]];
	}
	return revs;
}

- (void)reloadRevisions
{
	_revisions = [self revisionsWithOptions: COBranchRevisionReadingParentBranches];
}

- (NSArray *)nodes
{
	if (_revisions == nil)
	{
		[self reloadRevisions];
	}
	return [_revisions copy];
}

- (id)nextNodeOnTrackFrom: (id <COTrackNode>)aNode backwards: (BOOL)back
{
	NSInteger nodeIndex = [[self nodes] indexOfObject: aNode];
	
	if (nodeIndex == NSNotFound)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Node %@ must belong to the track %@ to retrieve the previous or next node", aNode, self];
	}
	if (back)
	{
		nodeIndex--;
	}
	else
	{
		nodeIndex++;
	}
	
	BOOL hasNoPreviousOrNextNode = (nodeIndex < 0 || nodeIndex >= [[self nodes] count]);
	
	if (hasNoPreviousOrNextNode)
	{
		return nil;
	}
	return [[self nodes] objectAtIndex: nodeIndex];
}

- (id <COTrackNode>)currentNode
{
	return [self currentRevision];
}

- (void)setCurrentNode: (id <COTrackNode>)node
{
	INVALIDARG_EXCEPTION_TEST(node, [node isKindOfClass: [CORevision class]]);
	[self setCurrentRevision: (CORevision *)node];
	[self didUpdate];
}

- (void)undoNode: (id <COTrackNode>)aNode
{
	// TODO: Implement Selective Undo
}

- (BOOL)isOrdered
{
	return YES;
}

- (id)content
{
	return [self nodes];
}

- (NSArray *)contentArray
{
	return [NSArray arrayWithArray: [self nodes]];
}

@end
