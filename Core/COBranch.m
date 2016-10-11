/*
    Copyright (C) 2011 Eric Wasylishen, Quentin Mathe, Christopher Armstrong

    Date:  September 2011
    License:  MIT  (see COPYING)
 */

#import "COBranch.h"
#import "COBranch+Private.h"
#import "COEditingContext.h"
#import "COEditingContext+Private.h"
#import "COPersistentRoot.h"
#import "COPersistentRoot+Private.h"
#import "COPersistentRootInfo.h"
#import "COObject.h"
#import "COObject+Private.h"
#import "CORevisionInfo.h"
#import "COBranchInfo.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COEditingContext+Undo.h"
#import "COLeastCommonAncestor.h"
#import "CODiffManager.h"
#import "COMergeInfo.h"
#import "COStoreTransaction.h"

/**
 * Expensive, paranoid validation for debugging
 */
//#define VALIDATE_ITEM_GRAPHS 1

NSString *const kCOBranchLabel = @"COBranchLabel";


@implementation COBranch

@synthesize UUID = _UUID, persistentRoot = _persistentRoot;
@synthesize shouldMakeEmptyCommit = _shouldMakeEmptyCommit, supportsRevert = _supportsRevert;
@synthesize mergingBranch = _mergingBranch;
@synthesize mergingRevision = _mergingRevision;

+ (void)initialize
{
    if (self != [COBranch class])
        return;

    [self applyTraitFromClass: [ETCollectionTrait class]];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (instancetype)init
{
    return [self initWithUUID: nil
               persistentRoot: nil
             parentBranchUUID: nil
   parentRevisionForNewBranch: nil];
}

#pragma clang diagnostic pop

/**
 * Both root object and revision are lazily retrieved by the persistent root.
 * Until the loaded revision is known, it is useless to cache track nodes. 
 */
- (instancetype)initWithUUID: (ETUUID *)aUUID
              persistentRoot: (COPersistentRoot *)aContext
            parentBranchUUID: (ETUUID *)aParentBranchUUID
  parentRevisionForNewBranch: (ETUUID *)parentRevisionForNewBranch
{
    NILARG_EXCEPTION_TEST(aUUID);
    NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
    NILARG_EXCEPTION_TEST(aContext);

    if (aContext.editingContext.store == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Cannot load commit track for %@ which does not "
                                "have a store or editing context", aContext];
    }

    SUPERINIT;

    _supportsRevert = YES;
    _UUID = aUUID;
    _persistentRoot = aContext;
    _parentBranchUUID = aParentBranchUUID;
    _objectGraph = nil;

    if (_persistentRoot.persistentRootInfo != nil
        && parentRevisionForNewBranch == nil)
    {
        // Loading an existing branch

        [self updateWithBranchInfo: self.branchInfo compacted: NO];
    }
    else
    {
        // Creating a new branch

        _currentRevisionUUID = parentRevisionForNewBranch;
        _headRevisionUUID = parentRevisionForNewBranch;
        _isCreated = NO;

        // If _parentRevisionID is nil, we're a new branch for a new persistent root
        // Otherwise, we're a new branch for an existing (committed) persistent root

        _metadata = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (void)updateWithBranchInfo: (COBranchInfo *)branchInfo
                   compacted: (BOOL)wasCompacted
{
    NSParameterAssert(branchInfo != nil);

    _currentRevisionUUID = branchInfo.currentRevisionUUID;
    _headRevisionUUID = branchInfo.headRevisionUUID;
    _metadata = [NSMutableDictionary dictionaryWithDictionary: branchInfo.metadata];
    _isCreated = YES;
    _parentBranchUUID = branchInfo.parentBranchUUID;

    if (_objectGraph != nil)
    {
        id <COItemGraph> aGraph =
            [_persistentRoot.store itemGraphForRevisionUUID: _currentRevisionUUID
                                             persistentRoot: self.persistentRoot.UUID];
        [_objectGraph setItemGraph: aGraph];
        [_objectGraph removeUnreachableObjects];
    }

    [self updateRevisions: wasCompacted];
}

- (NSString *)description
{
    if (self.isZombie)
        return @"<zombie branch>";

    return [NSString stringWithFormat: @"<%@ %p - %@ (%@) - revision: %@>", NSStringFromClass([self class]),
                                       self, _UUID, self.label, self.currentRevision.UUID];
}

- (NSString *)detailedDescription
{
    NSArray *properties = @[@"persistentRoot", @"rootObject",
                            @"deleted", @"currentRevision.UUID", @"headRevision.UUID",
                            @"initialRevision.UUID", @"firstRevision.UUID", @"parentBranch",
                            @"isCurrentBranch", @"isTrunkBranch", @"isCopy", @"supportsRevert",
                            @"hasChanges"];
    NSMutableDictionary *options =
        [@{kETDescriptionOptionValuesForKeyPaths: properties,
           kETDescriptionOptionPropertyIndent: @"\t"} mutableCopy];

    return [self descriptionWithOptions: options];
}

#pragma mark - Branch Kind

- (BOOL)isBranchUncommitted
{
    return !_isCreated;
}

- (BOOL)isBranchPersistentRootUncommitted
{
    return _currentRevisionUUID == nil && !_isCreated;
}

- (BOOL)isCopy
{
    // FIXME: Implement
    return NO;
}

- (BOOL)isCurrentBranch
{
    return self == _persistentRoot.currentBranch;
}

- (BOOL)isTrunkBranch
{
    // FIXME: Implement by reading from our metadata dictionary
    return NO;
}

#pragma mark Zombie Status -

- (BOOL)isZombie
{
    return (_persistentRoot == nil);
}

#pragma mark Basic Properties -

- (COBranchInfo *)branchInfo
{
    COPersistentRootInfo *persistentRootInfo = self.persistentRoot.persistentRootInfo;
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
    return _metadata[kCOBranchLabel];
}

- (void)setLabel: (NSString *)aLabel
{
    _metadata[kCOBranchLabel] = aLabel;
    _metadataChanged = YES;
}

- (NSString *)displayName
{
    NSString *label = self.label;
    NSString *displayName = self.persistentRoot.displayName;

    if (label != nil && ![label isEqual: @""])
    {
        displayName = [displayName stringByAppendingFormat: @" (%@)", label];
    }
    else
    {
        displayName = [displayName stringByAppendingFormat: @" (%@)", self.initialRevision.date];
    }
    return displayName;
}

- (BOOL)isDeletedInStore
{
    if (self.branchUncommitted)
        return NO;

    COBranchInfo *info = self.branchInfo;

    if (info == nil)
        return YES;

    return info.deleted;
}

- (BOOL)isDeleted
{
    if ([_persistentRoot.branchesPendingUndeletion containsObject: self])
        return NO;

    if ([_persistentRoot.branchesPendingDeletion containsObject: self])
        return YES;

    return self.deletedInStore;
}

- (void)setDeleted: (BOOL)deleted
{
    if (deleted && self.isCurrentBranch)
    {
        [NSException raise: NSGenericException
                    format: @"Can't delete the current branch"];
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

#pragma mark History -

- (CORevision *)initialRevision
{
    CORevision *rev = self.headRevision;
    while (rev.parentRevision != nil)
    {
        CORevision *revParent = rev.parentRevision;

        if (![revParent.branchUUID isEqual: self.UUID])
            break;

        rev = revParent;
    }
    return rev;
}

- (CORevision *)firstRevision
{
    CORevision *rev = self.currentRevision;
    while (rev.parentRevision != nil)
    {
        rev = rev.parentRevision;
    }
    return rev;
}

- (CORevision *)headRevision
{
    if (_headRevisionUUID != nil)
    {
        return [self.editingContext revisionForRevisionUUID: _headRevisionUUID
                                         persistentRootUUID: self.persistentRoot.UUID];
    }
    ETAssert(self.branchUncommitted);
    return nil;
}

- (void)setHeadRevision: (CORevision *)aRevision
{
    NILARG_EXCEPTION_TEST(aRevision);
    _headRevisionUUID = aRevision.UUID;
}

- (CORevision *)currentRevision
{
    if (_currentRevisionUUID != nil)
    {
        return [self.editingContext revisionForRevisionUUID: _currentRevisionUUID
                                         persistentRootUUID: self.persistentRoot.UUID];
    }
    ETAssert(self.branchUncommitted);
    return nil;
}

- (void)setCurrentRevisionSkipSupportsRevertCheck: (CORevision *)newCurrentRevision
{
    NILARG_EXCEPTION_TEST(newCurrentRevision);

    if (![newCurrentRevision isEqualToOrAncestorOfRevision: self.headRevision])
    {
        _headRevisionUUID = newCurrentRevision.UUID;
    }
    _currentRevisionUUID = newCurrentRevision.UUID;

    [self reloadAtRevision: newCurrentRevision];
    [self didUpdate];
}

- (void)setCurrentRevision: (CORevision *)newCurrentRevision
{
    if (!self.supportsRevert && ![self.currentRevision isEqualToOrAncestorOfRevision: newCurrentRevision])
    {
        [NSException raise: NSGenericException
                    format: @"%@: self.supportsRevert is NO, but -setCurrentRevision: was called "
                                "with a revision %@ that is not a descendent of the current revision, %@",
                            self, newCurrentRevision, self.currentRevision];
    }
    [self setCurrentRevisionSkipSupportsRevertCheck: newCurrentRevision];
}

- (COBranch *)parentBranch
{
    return [self.editingContext branchForUUID: _parentBranchUUID];
}


#pragma mark Persistent Root and Object Graph -

- (COEditingContext *)editingContext
{
    return _persistentRoot.editingContext;
}

/**
 * For the interaction with cross persistent root references, see
 * -[COPersistentRoot setCurrentBranchObjectGraphToRevisionUUID:persistentRootUUID:]
 * whose discussion applies this method unfaulting logic in the same way.
 */
- (COObjectGraphContext *)objectGraphContext
{
    if (_objectGraph == nil)
    {
        //NSLog(@"%@: unfaulting object graph context", self);

        _objectGraph = [[COObjectGraphContext alloc] initWithBranch: self];

        if (_currentRevisionUUID != nil
            && !self.persistentRoot.persistentRootUncommitted)
        {
            id <COItemGraph> aGraph = [_persistentRoot.store itemGraphForRevisionUUID: _currentRevisionUUID
                                                                       persistentRoot: self.persistentRoot.UUID];
            ETAssert(aGraph != nil);

            [_objectGraph setItemGraph: aGraph];
        }
        else
        {
            [_objectGraph setItemGraph: self.persistentRoot.objectGraphContext];
        }
        ETAssert(!_objectGraph.hasChanges);

        // Lazy loading support
        [self.editingContext updateCrossPersistentRootReferencesToPersistentRoot: self.persistentRoot
                                                                          branch: self
                                                                         isFault: self.deleted || self.persistentRoot.deleted];
    }
    return _objectGraph;
}

- (COObjectGraphContext *)objectGraphContextWithoutUnfaulting
{
    return _objectGraph;
}

- (BOOL)objectGraphContextHasChanges
{
    return _objectGraph != nil ? _objectGraph.hasChanges : NO;
}

- (id)rootObject
{
    return self.objectGraphContext.rootObject;
}

#pragma mark Pending Changes -

- (BOOL)hasChangesOtherThanDeletionOrUndeletion
{
    if (self.branchUncommitted)
        return YES;

    if (_metadataChanged)
        return YES;

    if (![self.branchInfo.currentRevisionUUID isEqual: _currentRevisionUUID])
        return YES;

    if (![self.branchInfo.headRevisionUUID isEqual: _headRevisionUUID])
        return YES;

    if (self.shouldMakeEmptyCommit)
        return YES;

    if (_objectGraph != nil)
        return _objectGraph.hasChanges;

    return NO;
}

- (BOOL)hasChanges
{
    if (self.deleted != self.deletedInStore)
        return YES;

    return [self hasChangesOtherThanDeletionOrUndeletion];
}

- (void)discardAllChanges
{
    if (self.branchUncommitted)
    {
        [NSException raise: NSGenericException
                    format: @"Uncommitted branches do not support -discardAllChanges"];
    }

    if (_metadataChanged)
    {
        if (self.branchUncommitted)
        {
            [_metadata removeAllObjects];
        }
        else
        {
            _metadata = [NSMutableDictionary dictionaryWithDictionary: self.branchInfo.metadata];
        }
        _metadataChanged = NO;
    }

    if (![self.branchInfo.currentRevisionUUID isEqual: _currentRevisionUUID])
    {
        self.currentRevision = [self.editingContext revisionForRevisionUUID: self.branchInfo.currentRevisionUUID
                                                         persistentRootUUID: self.persistentRoot.UUID];
    }
    if (![self.branchInfo.headRevisionUUID isEqual: _headRevisionUUID])
    {
        self.headRevision = [self.editingContext revisionForRevisionUUID: self.branchInfo.headRevisionUUID
                                                      persistentRootUUID: self.persistentRoot.UUID];
    }
    if (self.deleted != self.deletedInStore)
    {
        self.deleted = self.deletedInStore;
    }

    self.shouldMakeEmptyCommit = NO;

    [_objectGraph discardAllChanges];
}

#pragma mark Creating Branches and Cheap copies -

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel
{
    if (self.branchUncommitted)
    {
        [NSException raise: NSGenericException
                    format: @"Uncommitted branches do not support -makeBranchWithLabel:"];
    }
    return [self makeBranchWithLabel: aLabel atRevision: self.currentRevision];
}

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev
{
    NILARG_EXCEPTION_TEST(aLabel);
    NILARG_EXCEPTION_TEST(aRev);
    INVALIDARG_EXCEPTION_TEST(aRev, [aRev isEqualToOrAncestorOfRevision: [self headRevision]]);

    if (self.branchUncommitted)
    {
        /* Explanation for this restriction: 
           we could in theory support creating an arbitrary tree of uncommitted branches, or 
           branches on an uncommitted persistent root, and commit them all in one batch.
         
           The reason for not supporting it is it would just make the commit logic more complex, 
           doing a graph DFS on the branches and making a commit (if needed) as it visits each branch. */
        [NSException raise: NSGenericException
                    format: @"Uncommitted branches do not support -makeBranchWithLabel:atRevision:"];
    }
    return [_persistentRoot makeBranchWithLabel: aLabel atRevision: aRev parentBranch: self];
}

- (COPersistentRoot *)makePersistentRootCopyFromRevision: (CORevision *)aRev
{
    NILARG_EXCEPTION_TEST(aRev);
    INVALIDARG_EXCEPTION_TEST(aRev, [aRev isEqualToOrAncestorOfRevision: [self headRevision]]);

    if (self.branchUncommitted)
    {
        /* See -makeBranchWithLabel:atRevision: exception explanation */
        [NSException raise: NSGenericException
                    format: @"Uncommitted branches do not support -makeCopyFromRevision:"];
    }
    return [self.persistentRoot.editingContext insertNewPersistentRootWithRevisionUUID: aRev.UUID
                                                                          parentBranch: self];
}

- (COPersistentRoot *)makePersistentRootCopy
{
    return [self makePersistentRootCopyFromRevision: self.currentRevision];
}

#pragma mark Undo / Redo -

- (CORevision *)undoRevision
{
    // Quentin argued you should be able to "step back"
    // in a cheap copy to before the copy was made. I'm disabling this
    // block to get that behaviour.
#if 0
    if ([self.initialRevision isEqual: self.currentRevision])
    {
        return nil;
    }
#endif

    CORevision *revision = self.currentRevision.parentRevision;
    return revision;
}

- (BOOL)canUndo
{
    return self.supportsRevert && [self undoRevision] != nil;
}

- (void)undo
{
    self.currentRevision = [self undoRevision];
}

- (CORevision *)redoRevision
{
    CORevision *currentRevision = self.currentRevision;
    CORevision *revision = self.headRevision;

    if ([currentRevision isEqual: revision])
        return nil;

    while (revision != nil)
    {
        CORevision *revisionParent = revision.parentRevision;

        if ([revisionParent isEqual: currentRevision])
            return revision;

        revision = revisionParent;
    }
    return revision;
}

- (BOOL)canRedo
{
    return self.supportsRevert && [self redoRevision] != nil;
}

- (void)redo
{
    self.currentRevision = [self redoRevision];
}

#pragma mark Committing Changes -

- (void)writeMetadataWithTransaction: (COStoreTransaction *)txn
{
    if (!_metadataChanged)
        return;

    [txn setMetadata: _metadata
           forBranch: _UUID
    ofPersistentRoot: self.persistentRoot.UUID];

    [self.editingContext recordBranchSetMetadata: self
                                     oldMetadata: self.branchInfo.metadata];

    _metadataChanged = NO;
}

- (void)saveCommitWithMetadata: (NSDictionary *)metadata transaction: (COStoreTransaction *)txn
{
    if ([self hasChangesOtherThanDeletionOrUndeletion] && self.deletedInStore && self.deleted)
    {
        [NSException raise: NSGenericException
                    format: @"Attempted to commit changes to deleted branch %@", self];
    }
    ETAssert(!self.branchPersistentRootUncommitted);
    ETAssert(_currentRevisionUUID != nil);
    ETAssert(_headRevisionUUID != nil);

    if (self.branchUncommitted)
    {
        // N.B. - this only the case when we're adding a new branch to an existing persistent root.

        [txn createBranchWithUUID: _UUID
                     parentBranch: _parentBranchUUID
                  initialRevision: _currentRevisionUUID
                forPersistentRoot: self.persistentRoot.UUID];

        [self.editingContext recordBranchCreation: self];

        _isCreated = YES;
    }
    else if (![self.branchInfo.currentRevisionUUID isEqual: _currentRevisionUUID]
             || ![self.branchInfo.headRevisionUUID isEqual: _headRevisionUUID])
    {
        ETUUID *oldRevUUID = self.branchInfo.currentRevisionUUID;
        ETAssert(oldRevUUID != nil);
        ETUUID *oldHeadRevUUID = self.branchInfo.headRevisionUUID;

        // This is the case when the user does [self setCurrentRevision: ], and then commits

        [txn setCurrentRevision: _currentRevisionUUID
                   headRevision: _headRevisionUUID
                      forBranch: _UUID
               ofPersistentRoot: self.persistentRoot.UUID];

        [self.editingContext recordBranchSetCurrentRevisionUUID: _currentRevisionUUID
                                                oldRevisionUUID: oldRevUUID
                                               headRevisionUUID: _headRevisionUUID
                                            oldHeadRevisionUUID: oldHeadRevUUID
                                                       ofBranch: self];
    }

    [self writeMetadataWithTransaction: txn];

    // Write a regular commit

    COObjectGraphContext *modifiedItemsSource = [self modifiedItemsSource];

    if (modifiedItemsSource != nil || self.shouldMakeEmptyCommit)
    {
        COItemGraph *modifiedItems = [self modifiedItemsSnapshot];
        if (modifiedItems.itemUUIDs.count > 0 || self.shouldMakeEmptyCommit)
        {
            ETUUID *mergeParent = nil;
            ETAssert(self.mergingBranch == nil || self.mergingRevision == nil);

            if (self.mergingBranch != nil)
            {
                mergeParent = self.mergingBranch.currentRevision.UUID;
                self.mergingBranch = nil;
            }
            else if (self.mergingRevision != nil)
            {
                mergeParent = self.mergingRevision.UUID;
                self.mergingRevision = nil;
            }

            ETUUID *revUUID = [ETUUID UUID];

            [txn writeRevisionWithModifiedItems: modifiedItems
                                   revisionUUID: revUUID
                                       metadata: metadata
                               parentRevisionID: _currentRevisionUUID
                          mergeParentRevisionID: mergeParent
                             persistentRootUUID: _persistentRoot.UUID
                                     branchUUID: _UUID];

            [txn setCurrentRevision: revUUID
                       headRevision: revUUID
                          forBranch: _UUID
                   ofPersistentRoot: self.persistentRoot.UUID];

            ETUUID *oldRevUUID = _currentRevisionUUID;
            ETUUID *oldHeadRevUUID = _headRevisionUUID;
            ETAssert(oldRevUUID != nil);
            ETAssert(oldHeadRevUUID != nil);
            ETAssert(revUUID != nil);

            _currentRevisionUUID = revUUID;
            _headRevisionUUID = revUUID;
            self.shouldMakeEmptyCommit = NO;

            [self.editingContext recordBranchSetCurrentRevisionUUID: _currentRevisionUUID
                                                    oldRevisionUUID: oldRevUUID
                                                   headRevisionUUID: _currentRevisionUUID
                                                oldHeadRevisionUUID: oldHeadRevUUID
                                                           ofBranch: self];
            if (modifiedItemsSource == _objectGraph
                && _objectGraph != nil)
            {
                [_objectGraph acceptAllChanges];

                if (self == self.persistentRoot.currentBranch)
                {
                    [self.persistentRoot.objectGraphContext setItemGraph: _objectGraph];
                }
            }
            else if (modifiedItemsSource != nil)
            {
                ETAssert(modifiedItemsSource == _persistentRoot.objectGraphContext);
                [_persistentRoot.objectGraphContext acceptAllChanges];

                if (_objectGraph != nil)
                {
                    [_objectGraph setItemGraph: _persistentRoot.objectGraphContext];
                }
            }
        }
    }

    // Write branch undeletion

    if (!self.deleted && self.deletedInStore)
    {
        [txn undeleteBranch: _UUID
           ofPersistentRoot: self.persistentRoot.UUID];

        [self.editingContext recordBranchUndeletion: self];
    }
}

- (void)saveDeletionWithTransaction: (COStoreTransaction *)txn
{
    if (self.deleted && !self.deletedInStore)
    {
        [txn deleteBranch: _UUID ofPersistentRoot: self.persistentRoot.UUID];
        [self.editingContext recordBranchDeletion: self];
    }
}

- (void)didMakeInitialCommitWithRevisionUUID: (ETUUID *)aRevisionUUID
                                 transaction: (COStoreTransaction *)txn
{
    NSParameterAssert(aRevisionUUID != nil);

    [self writeMetadataWithTransaction: txn];
    ETAssert(!_isCreated);

    _currentRevisionUUID = aRevisionUUID;
    _headRevisionUUID = aRevisionUUID;
    _isCreated = YES;

    if (_objectGraph != nil)
    {
        [_objectGraph acceptAllChanges];
        ETAssert(!_objectGraph.hasChanges);
    }
}

/**
 * Returns either nil, _objectGraph, or _persistentRoot.objectGraphContext
 */
- (COObjectGraphContext *)modifiedItemsSource
{
    if (self == _persistentRoot.currentBranch && _persistentRoot.objectGraphContext.hasChanges)
    {
        COObjectGraphContext *graph = _persistentRoot.objectGraphContext;

        if (_objectGraph.hasChanges)
        {
            [NSException raise: NSGenericException
                        format: @"You appear to have modified both persistentRoot.objectGraphContext "
                                     "and persistentRoot.currentBranch.objectGraphContext"];
        }
        return graph;
    }
    return _objectGraph;
}

- (COItemGraph *)modifiedItemsSnapshot
{
    NSSet *objectUUIDs = nil;
    COObjectGraphContext *graph = [self modifiedItemsSource];

    if (graph == nil)
    {
        return [[COItemGraph alloc] initWithItemForUUID: @{}
                                           rootItemUUID: [self.persistentRoot.rootObject UUID]];
    }
    [graph doPreCommitChecks];

    if (_currentRevisionUUID == nil)
    {
        objectUUIDs = [NSSet setWithArray: graph.itemUUIDs];
    }
    else
    {
        objectUUIDs = graph.changedObjectUUIDs;
    }

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    for (ETUUID *uuid in objectUUIDs)
    {
        COObject *obj = [graph loadedObjectForUUID: uuid];
        COItem *item = [graph itemForUUID: uuid];

        dict[uuid] = item;

        // FIXME: Doing this here is wrong.. -changedObjectUUIDs should include
        // all items needed to generate the new object graph state from the old state.
        for (ETUUID *itemUUID in [obj.additionalStoreItemUUIDs objectEnumerator])
        {
            dict[itemUUID] = [obj additionalStoreItemForUUID: itemUUID];
        }
    }

    COItemGraph *modifiedItems = [[COItemGraph alloc] initWithItemForUUID: dict
                                                             rootItemUUID: graph.rootItemUUID];

#if VALIDATE_ITEM_GRAPHS
    if (_currentRevisionUUID == nil)
    {
        // On the first commit, validate the graph on its own
        COValidateItemGraph(modifiedItems);
    }
    else
    {
        // On subsequent commits, modifiedItems will be a delta. Load the parent graph, which
        // should be valid itself.
        COItemGraph *parentGraph = [self.store itemGraphForRevisionUUID: _currentRevisionUUID persistentRoot: self.persistentRoot.UUID];
        COValidateItemGraph(parentGraph);
        
        // Apply the delta, this should be valid too.
        [parentGraph addItemGraph: modifiedItems];
        COValidateItemGraph(parentGraph);
    }
#endif
    return modifiedItems;
}

#pragma mark Merging Between Branches -

- (COSQLiteStore *)store
{
    return _persistentRoot.store;
}

- (COMergeInfo *)mergeInfoForMergingBranch: (COBranch *)aBranch
{
    NILARG_EXCEPTION_TEST(aBranch);
    ETUUID *lca = [self.editingContext commonAncestorForCommit: aBranch.currentRevision.UUID
                                                     andCommit: self.currentRevision.UUID
                                                persistentRoot: self.persistentRoot.UUID];
    id <COItemGraph> baseGraph = [self.store itemGraphForRevisionUUID: lca
                                                       persistentRoot: self.persistentRoot.UUID];

    return [self diffForMergingGraphWithSelf: aBranch.objectGraphContext
                                revisionUUID: aBranch.currentRevision.UUID
                                   baseGraph: baseGraph
                              baseRevisionID: lca];
}

- (COMergeInfo *)mergeInfoForMergingRevision: (CORevision *)aRevision
{
    NILARG_EXCEPTION_TEST(aRevision);
    ETUUID *lca = [self.editingContext commonAncestorForCommit: aRevision.UUID
                                                     andCommit: self.currentRevision.UUID
                                                persistentRoot: self.persistentRoot.UUID];
    id <COItemGraph> baseGraph = [self.store itemGraphForRevisionUUID: lca
                                                       persistentRoot: self.persistentRoot.UUID];
    id <COItemGraph> mergeGraph = [self.store itemGraphForRevisionUUID: aRevision.UUID
                                                        persistentRoot: self.persistentRoot.UUID];

    return [self diffForMergingGraphWithSelf: mergeGraph
                                revisionUUID: aRevision.UUID
                                   baseGraph: baseGraph
                              baseRevisionID: lca];
}

- (COMergeInfo *)diffForMergingGraphWithSelf: (id <COItemGraph>)mergeGraph
                                revisionUUID: (ETUUID *)mergeRevisionUUID
                                   baseGraph: (id <COItemGraph>)baseGraph
                              baseRevisionID: (ETUUID *)aBaseRevisionID
{
    CODiffManager *mergingBranchDiff = [CODiffManager diffItemGraph: baseGraph
                                                      withItemGraph: mergeGraph
                                         modelDescriptionRepository: self.editingContext.modelDescriptionRepository
                                                   sourceIdentifier: @"merged"];
    CODiffManager *selfDiff = [CODiffManager diffItemGraph: baseGraph
                                             withItemGraph: self.objectGraphContext
                                modelDescriptionRepository: self.editingContext.modelDescriptionRepository
                                          sourceIdentifier: @"self"];
    CODiffManager *merged = [selfDiff diffByMergingWithDiff: mergingBranchDiff];

    COMergeInfo *result = [[COMergeInfo alloc] init];

    result.mergeDestinationRevision = self.currentRevision;
    result.mergeSourceRevision = [self.editingContext revisionForRevisionUUID: mergeRevisionUUID
                                                           persistentRootUUID: self.persistentRoot.UUID];
    result.baseRevision = [self.editingContext revisionForRevisionUUID: aBaseRevisionID
                                                    persistentRootUUID: self.persistentRoot.UUID];
    result.diff = merged;

    return result;
}

#pragma mark Revisions -

- (void)reloadAtRevision: (CORevision *)revision
{
    NSParameterAssert(revision != nil);
    // TODO: Use optimized method on the store to get a delta for more performance
    id <COItemGraph> aGraph = [self.store itemGraphForRevisionUUID: revision.UUID
                                                    persistentRoot: self.persistentRoot.UUID];

    if (_objectGraph != nil)
    {
        [_objectGraph setItemGraph: aGraph];
        [_objectGraph removeUnreachableObjects];
    }

    if (self == self.persistentRoot.currentBranch)
    {
        [self.persistentRoot.objectGraphContext setItemGraph: aGraph];
        [self.persistentRoot.objectGraphContext removeUnreachableObjects];
    }
}

/**
 * When compacted or rebased, we discard all revisions, the next time -revisions 
 * is called, the latest revisions will be reloaded.
 */
- (void)updateRevisions: (BOOL)wasCompactedOrRebased
{
    if (_revisions == nil)
        return;

    CORevision *currentRev = [self.editingContext revisionForRevisionUUID: _currentRevisionUUID
                                                       persistentRootUUID: self.persistentRoot.UUID];
    const BOOL isUpToDate = [currentRev isEqual: _revisions.lastObject] && !wasCompactedOrRebased;

    if (isUpToDate)
        return;

    const BOOL isNewCommit = [currentRev.parentRevision isEqual: _revisions.lastObject] && !wasCompactedOrRebased;

    if (isNewCommit)
    {
        [_revisions addObject: currentRev];
    }
    else
    {
        _revisions = nil;
    }
    [self didUpdate];
}

- (NSMutableArray *)revisionsWithOptions: (COBranchRevisionReadingOptions)options
{
    NSArray *revInfos = [self.store revisionInfosForBranchUUID: self.UUID
                                                       options: options];
    NSMutableArray *revs = [NSMutableArray array];

    for (CORevisionInfo *revInfo in revInfos)
    {
        [revs addObject: [self.editingContext revisionForRevisionUUID: revInfo.revisionUUID
                                                   persistentRootUUID: revInfo.persistentRootUUID]];
    }
    return revs;
}

- (void)reloadRevisions
{
    _revisions = [self revisionsWithOptions: COBranchRevisionReadingParentBranches];
}

#pragma mark Track Protocol -

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
    NSInteger nodeIndex = [self.nodes indexOfObject: aNode];

    if (nodeIndex == NSNotFound)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Node %@ must belong to the track %@ to retrieve the previous or next node",
                            aNode, self];
    }
    if (back)
    {
        nodeIndex--;
    }
    else
    {
        nodeIndex++;
    }

    const BOOL hasNoPreviousOrNextNode = (nodeIndex < 0 || nodeIndex >= self.nodes.count);

    if (hasNoPreviousOrNextNode)
        return nil;

    return self.nodes[nodeIndex];
}

- (id <COTrackNode>)currentNode
{
    return self.currentRevision;
}

- (BOOL)setCurrentNode: (id <COTrackNode>)node
{
    INVALIDARG_EXCEPTION_TEST(node, [node isKindOfClass: [CORevision class]]);
    self.currentRevision = (CORevision *)node;

    // TODO: Should return NO if self.supportsRevert is NO and this is a revert
    return YES;
}

- (void)undoNode: (id <COTrackNode>)aNode
{
    [self selectiveApplyFromRevision: (CORevision *)aNode
                          toRevision: ((CORevision *)aNode).parentRevision];
}

- (void)redoNode: (id <COTrackNode>)aNode
{
    [self selectiveApplyFromRevision: ((CORevision *)aNode).parentRevision
                          toRevision: (CORevision *)aNode];
}

#pragma mark Selective Undo / Redo -

- (CODiffManager *)diffToSelectivelyApplyChangesFromRevision: (CORevision *)start
                                                  toRevision: (CORevision *)end
{
    COItemGraph *currentGraph = [self.store itemGraphForRevisionUUID: self.currentRevision.UUID
                                                      persistentRoot: self.persistentRoot.UUID];
    COItemGraph *oldGraph = [self.store itemGraphForRevisionUUID: start.UUID
                                                  persistentRoot: self.persistentRoot.UUID];
    COItemGraph *newGraph = [self.store itemGraphForRevisionUUID: end.UUID
                                                  persistentRoot: self.persistentRoot.UUID];

    CODiffManager *diff1 = [CODiffManager diffItemGraph: oldGraph
                                          withItemGraph: newGraph
                             modelDescriptionRepository: self.editingContext.modelDescriptionRepository
                                       sourceIdentifier: @"diff1"];
    CODiffManager *diff2 = [CODiffManager diffItemGraph: oldGraph
                                          withItemGraph: currentGraph
                             modelDescriptionRepository: self.editingContext.modelDescriptionRepository
                                       sourceIdentifier: @"diff2"];

    return [diff1 diffByMergingWithDiff: diff2];
}

- (void)selectiveApplyFromRevision: (CORevision *)start
                        toRevision: (CORevision *)end
{
    CODiffManager *merged = [self diffToSelectivelyApplyChangesFromRevision: start
                                                                 toRevision: end];
    COItemGraph *oldGraph = [self.store itemGraphForRevisionUUID: start.UUID
                                                  persistentRoot: self.persistentRoot.UUID];
    id <COItemGraph> result = [[COItemGraph alloc] initWithItemGraph: oldGraph];

    [merged applyTo: result];

    // FIXME: Works, but an ugly API mismatch when setting object graph context contents
    NSMutableArray *items = [NSMutableArray array];

    for (ETUUID *uuid in result.itemUUIDs)
    {
        [items addObject: [result itemForUUID: uuid]];
    }

    // FIXME: Handle cross-persistent root relationship constraint violations, if we introduce those
    [self.objectGraphContext insertOrUpdateItems: items];
}

#pragma mark Collection Protocol -

- (void)didUpdate
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (BOOL)isOrdered
{
    return YES;
}

- (id)content
{
    return self.nodes;
}

- (NSArray *)contentArray
{
    return [NSArray arrayWithArray: self.nodes];
}

@end
