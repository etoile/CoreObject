/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe
 
    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "COPersistentRoot.h"
#import "COPersistentRoot+Private.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "COEditingContext.h"
#import "COItem.h"
#import "COObject.h"
#import "COObject+Private.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "CORevision.h"
#import "COSQLiteStore.h"
#import "COPersistentRootInfo.h"
#import "COBranchInfo.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "COStoreTransaction.h"

NSString * const COPersistentRootDidChangeNotification = @"COPersistentRootDidChangeNotification";

/**
 * Metadata dictionary key used by the `name` property.
 */
NSString * const COPersistentRootName = @"org.etoile.coreobject.name";

@implementation COPersistentRoot

@synthesize parentContext = _parentContext, UUID = _UUID;
@synthesize branchesPendingDeletion = _branchesPendingDeletion;
@synthesize branchesPendingUndeletion = _branchesPendingUndeletion;

#pragma mark Creating a New Persistent Root -

- (instancetype)init
{
    [self doesNotRecognizeSelector: _cmd];
    return nil;
}

// TODO: Could be debug only (measure how slow this check is)
- (void) validateNewObjectGraphContext: (COObjectGraphContext *)newContext
                           createdFrom: (COObjectGraphContext *)oldContext
{
    if (oldContext == nil)
        return;
    
    NSSet *newItemUUIDs = COItemGraphReachableUUIDs(newContext);
    NSSet *oldItemUUIDs = COItemGraphReachableUUIDs(oldContext);

    if ([newItemUUIDs isEqual: oldItemUUIDs])
        return;

    NSMutableSet *mismatchedItemUUIDsInNewContext = [newItemUUIDs mutableCopy];
    [mismatchedItemUUIDsInNewContext minusSet: oldItemUUIDs];
    NSMutableSet *mismatchedItemUUIDsInOldContext = [oldItemUUIDs mutableCopy];
    [mismatchedItemUUIDsInOldContext minusSet: newItemUUIDs];

    // FIXME: Unless we run GC phase in the new context, mismatches in the old
    // context will remain invisible.
    NSAssert2([mismatchedItemUUIDsInOldContext isEmpty],
        @"Mismatched item UUIDs accross identical object graph contexts, due "
         "to persistent objects, belonging to the old object graph context %@, "
         "present in a transient relationship (or several ones): \n%@", oldContext, 
        [oldContext loadedObjectsForUUIDs: [mismatchedItemUUIDsInOldContext allObjects]]);

    NSAssert2([mismatchedItemUUIDsInNewContext isEmpty],
        @"Mismatched item UUIDs accross identical object graph contexts, due "
         "to persistent objects, belonging to the new object graph context %@, "
         "present in a transient relationship (or several ones):  \n%@", newContext, 
        [newContext loadedObjectsForUUIDs: [mismatchedItemUUIDsInNewContext allObjects]]);
}

- (instancetype) initWithInfo: (COPersistentRootInfo *)info
cheapCopyRevisionUUID: (ETUUID *)cheapCopyRevisionID
cheapCopyPersistentRootUUID: (ETUUID *)cheapCopyPersistentRootID
   parentBranchUUID: (ETUUID *)aBranchUUID
 objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
      parentContext: (COEditingContext *)aCtxt
{
    if (info != nil)
    {
        INVALIDARG_EXCEPTION_TEST(anObjectGrapContext, anObjectGraphContext == nil);
    }
    if (anObjectGraphContext != nil)
    {
        INVALIDARG_EXCEPTION_TEST(info, info == nil);
        INVALIDARG_EXCEPTION_TEST(anObjectGraphContext, [anObjectGraphContext branch] == nil);
    }
    NILARG_EXCEPTION_TEST(aCtxt);

    SUPERINIT;
    
    _parentContext = aCtxt;
    _savedState =  info;
    _branchForUUID = [[NSMutableDictionary alloc] init];
    _branchesPendingDeletion = [NSMutableSet new];
    _branchesPendingUndeletion = [NSMutableSet new];
    if (anObjectGraphContext != nil)
    {
        _currentBranchObjectGraph = anObjectGraphContext;
    }
    else
    {
        _currentBranchObjectGraph = [[COObjectGraphContext alloc]
            initWithModelDescriptionRepository: aCtxt.modelDescriptionRepository
                          migrationDriverClass: aCtxt.migrationDriverClass];
    }
    [_currentBranchObjectGraph setPersistentRoot: self];
    
    if (_savedState != nil)
    {
        _UUID =  _savedState.UUID;
        
        for (COBranchInfo *branchInfo in _savedState.branchForUUID.allValues)
        {
            [self updateBranchWithBranchInfo: branchInfo
                                   compacted: NO];
        }
        
        _currentBranchUUID =  _savedState.currentBranchUUID;
        [_parentContext setLastTransactionID: _savedState.transactionID forPersistentRootUUID: _UUID];
        _metadata = _savedState.metadata;
        
        [self reloadCurrentBranchObjectGraph];
    }
    else
    {
        _UUID =  [ETUUID UUID];

        // TODO: Decide whether we should attempt to always allocate the object
        // graph context in the editing context methods rather than creating it
        // in COBranch initializer in some cases. Would make possible to write:
        //ETUUID *branchUUID = anObjectGraphContext.branchUUID;
        ETUUID *branchUUID =
            (anObjectGraphContext != nil ? anObjectGraphContext.branchUUID : [ETUUID UUID]);
        COBranch *branch = [[COBranch alloc] initWithUUID: branchUUID
                                            persistentRoot: self
                                          parentBranchUUID: aBranchUUID
                                parentRevisionForNewBranch: cheapCopyRevisionID];

        if (cheapCopyPersistentRootID != nil)
        {
            [self setCurrentBranchObjectGraphToRevisionUUID: cheapCopyRevisionID
                                         persistentRootUUID: cheapCopyPersistentRootID];
        }
        
        [self validateNewObjectGraphContext: _currentBranchObjectGraph
                                createdFrom: branch.objectGraphContextWithoutUnfaulting];

        _branchForUUID[branchUUID] = branch;
        
        _currentBranchUUID =  branchUUID;
        _cheapCopyRevisionUUID =  cheapCopyRevisionID;
        _cheapCopyPersistentRootUUID =  cheapCopyPersistentRootID;
        
        if (_cheapCopyPersistentRootUUID != nil)
        {
            // FIXME: Make a proper metadata key for this
            self.metadata = @{ @"parentPersistentRoot" : [_cheapCopyPersistentRootUUID stringValue] };
        }
    }
    
    return self;
}

- (NSString *)description
{
    if (self.isZombie)
    {
        return @"<zombie persistent root>";
    }
    return [NSString stringWithFormat: @"<%@ %p - %@ - %@>",
        NSStringFromClass([self class]), self, _UUID, [self.rootObject entityDescription].name];
}

- (NSString *)detailedDescription
{
    NSArray *properties = @[@"editingContext", @"currentBranch",
        @"branches", @"deleted", @"modificationDate", @"creationDate",
        @"parentPersistentRoot", @"isCopy", @"attributes", @"hasChanges",
        @"branchesPendingInsertion", @"branchesPendingUpdate",
        @"branchesPendingDeletion", @"branchesPendingUndeletion"];
    NSMutableDictionary *options =
        [@{ kETDescriptionOptionValuesForKeyPaths: properties,
        kETDescriptionOptionPropertyIndent: @"\t" } mutableCopy];

    return [self descriptionWithOptions: options];
}

/**
 * We don't need to update incoming cross persistent root references in this 
 * method, since the root object UUID is stable in the history and the object 
 * graph will constantly reuse the same root object instance once allocated, 
 * even while navigating the history.
 *
 * When we unfault an object graph, we never have to fix other persistent root
 * branches, since their outgoing references are always resolved at 
 * deserialization time (unfaulting all object graphs required to resolve them). 
 * This means a lazily unfaulted object graph is never referenced by an already 
 * loaded object graph.
 *
 * On -setItemGraph:, the deserialization code will also automatically check
 * which persistent roots or branches are deleted, and decide which outgoing
 * references are dead or live accordingly.
 */
- (void) setCurrentBranchObjectGraphToRevisionUUID: (ETUUID *)aRevision
                                persistentRootUUID: (ETUUID*)aPersistentRoot
{
    id <COItemGraph> aGraph = [self.store itemGraphForRevisionUUID: aRevision
                                                      persistentRoot: aPersistentRoot];
    [_currentBranchObjectGraph setItemGraph: aGraph];
    [_currentBranchObjectGraph removeUnreachableObjects];
}

- (void) reloadCurrentBranchObjectGraph
{
    [self setCurrentBranchObjectGraphToRevisionUUID: self.currentRevision.UUID
                                 persistentRootUUID: self.UUID];
}

#pragma mark Persistent Root Properties -

- (NSDictionary *)metadata
{
    return [NSDictionary dictionaryWithDictionary: _metadata];
}

- (void)setMetadata: (NSDictionary *)aMetadata
{
    _metadata = [NSDictionary dictionaryWithDictionary: aMetadata];
    _metadataChanged = YES;
}

- (BOOL)isPersistentRoot
{
    return YES;
}

- (COEditingContext *)editingContext
{
    return self.parentContext;
}

- (BOOL)isDeleted
{
    if ([_parentContext.persistentRootsPendingUndeletion containsObject: self])
        return NO;
    
    if ([_parentContext.persistentRootsPendingDeletion containsObject: self])
        return YES;
    
    return _savedState.deleted;
}

- (void)setDeleted: (BOOL)deleted
{
    [self assertNotZombie];
    if (deleted == self.deleted)
    {
        return;
    }
    
    if (deleted)
    {
        [_parentContext deletePersistentRoot: self];
    }
    else
    {
        [_parentContext undeletePersistentRoot: self];
    }
}

- (NSDate *)modificationDate
{
    NSDate *maxDate = nil;

    for (COBranch *branch in self.branches)
    {
        NSDate *date = branch.headRevision.date;

        if (maxDate != nil && [[date earlierDate: maxDate] isEqualToDate: date])
            continue;

        maxDate = date;
    }
    return maxDate;
}

- (NSDate *)creationDate
{
    return self.currentBranch.firstRevision.date;
}

- (COPersistentRoot *)parentPersistentRoot
{
    NSString *uuidString = self.metadata[@"parentPersistentRoot"];

    if (uuidString == nil)
        return nil;

    return [self.editingContext persistentRootForUUID: [ETUUID UUIDWithString: uuidString]];
}

- (BOOL)isCopy
{
    return self.metadata[@"parentPersistentRoot"] != nil;
}

- (NSDictionary *)attributes
{
    return [self.store attributesForPersistentRootWithUUID: _UUID];
}

- (NSString *) name
{
    return self.metadata[COPersistentRootName];
}

- (void) setName: (NSString *)name
{
    NSMutableDictionary *md = [[NSMutableDictionary alloc] initWithDictionary: self.metadata];
    if (name == nil)
    {
        [md removeObjectForKey: COPersistentRootName];
    }
    else
    {
        md[COPersistentRootName] = [[NSString alloc] initWithString: name];
    }
    self.metadata = md;
}

#pragma mark Accessing Branches -

- (COBranch *)currentBranch
{
    return _branchForUUID[_currentBranchUUID];
}

- (void)setCurrentBranch: (COBranch *)aBranch
{
    _currentBranchUUID = aBranch.UUID;
    _currentBranchObjectGraph.branch = aBranch;
    
    [self reloadCurrentBranchObjectGraph];
    // TODO: Update cross persistent root references
}

- (NSSet *)allBranches
{
    return [NSSet setWithArray: _branchForUUID.allValues];
}

- (NSSet *)branches
{
    return [NSSet setWithArray: [_branchForUUID.allValues filteredCollectionWithBlock: ^(COBranch *obj)
    {
        return (BOOL)!obj.deleted;
    }]];
}

- (NSSet *)deletedBranches
{
    return [NSSet setWithArray: [_branchForUUID.allValues filteredCollectionWithBlock: ^(COBranch *obj)
    {
        return (BOOL)obj.deleted;
    }]];
}

- (COBranch *)branchForUUID: (ETUUID *)aUUID
{
    return _branchForUUID[aUUID];
}

- (void)deleteBranch: (COBranch *)aBranch
{
    if ([_branchesPendingUndeletion containsObject: aBranch])
    {
        ETAssert(!aBranch.branchUncommitted);
        [_branchesPendingUndeletion removeObject: aBranch];
    }
    else
    {
        [_branchesPendingDeletion addObject: aBranch];
    }
    [self.editingContext updateCrossPersistentRootReferencesToPersistentRoot: aBranch.persistentRoot
                                                                      branch: aBranch
                                                                     isFault: YES];
    
    if (aBranch.branchUncommitted)
    {
        [_branchesPendingDeletion removeObject: aBranch];
        [_branchForUUID removeObjectForKey: aBranch.UUID];
    }
}

- (void)undeleteBranch: (COBranch *)aBranch
{
    if ([_branchesPendingDeletion containsObject: aBranch])
    {
        ETAssert(!aBranch.branchUncommitted);
        [_branchesPendingDeletion removeObject: aBranch];
    }
    else
    {
        [_branchesPendingUndeletion addObject: aBranch];
    }
    [self.editingContext updateCrossPersistentRootReferencesToPersistentRoot: aBranch.persistentRoot
                                                                      branch: aBranch
                                                                     isFault: aBranch.persistentRoot.deleted];

    if (aBranch.branchUncommitted)
    {
        [_branchesPendingUndeletion removeObject: aBranch];
    }
}

#pragma mark Pending Changes -

- (NSSet *)branchesPendingInsertion
{
    return [self.branches filteredCollectionWithBlock: ^(COBranch *obj)
    {
        return obj.branchUncommitted;
    }];
}

- (NSSet *)branchesPendingUpdate
{
    return [self.branches filteredCollectionWithBlock: ^(COBranch *obj)
    {
        return obj.hasChanges;
    }];
}

- (BOOL)hasChanges
{
    if (_branchesPendingDeletion.count > 0)
        return YES;
    
    if (_branchesPendingUndeletion.count > 0)
        return YES;
    
    if (_metadataChanged)
        return YES;

    if (_currentBranchObjectGraph.hasChanges)
        return YES;
    
    for (COBranch *branch in self.branches)
    {
        if (branch.branchUncommitted)
            return YES;

        if (branch.hasChanges)
            return YES;
    }
    return NO;
}

- (void)discardAllChanges
{
    /* Discard changes in branches */

    for (COBranch *branch in self.branches)
    {
        if (branch.branchUncommitted)
            continue;
        
        [branch discardAllChanges];
    }

    /* Clear branches pending insertion */
    
    NSArray *branchesPendingInsertion = self.branchesPendingInsertion.allObjects;
    
    [_branchForUUID removeObjectsForKeys: (id)[[branchesPendingInsertion mappedCollection] UUID]];
    ETAssert([self.branchesPendingInsertion isEmpty]);

    /* Clear other pending changes */

    [self clearBranchesPendingDeletionAndUndeletion];

    if (_metadataChanged)
    {
        _metadata = [self.persistentRootInfo.metadata copy];
        _metadataChanged = NO;
    }
    
    [_currentBranchObjectGraph discardAllChanges];
    
    ETAssert(!self.hasChanges);
}

- (BOOL) isZombie
{
    return (_parentContext == nil);
}

#pragma mark Convenience -

- (COObjectGraphContext *)objectGraphContext
{
    return _currentBranchObjectGraph;
}

- (NSSet *)allObjectGraphContexts
{
    NSMutableSet *objectGraphs = [NSMutableSet setWithCapacity: _branchForUUID.count + 1];
    [objectGraphs addObject: _currentBranchObjectGraph];

    for (COBranch *branch in _branchForUUID.objectEnumerator)
    {
        COObjectGraphContext *branchObjectGraph = branch.objectGraphContextWithoutUnfaulting;

        if (branchObjectGraph != nil)
        {
            [objectGraphs addObject: branchObjectGraph];
        }
    }
    return objectGraphs;
}

- (id)rootObject
{
    return self.objectGraphContext.rootObject;
}

- (void)setRootObject: (COObject *)aRootObject
{
    self.objectGraphContext.rootObject = aRootObject;
}

- (COObject *)loadedObjectForUUID: (ETUUID *)uuid
{
    return [self.objectGraphContext loadedObjectForUUID: uuid];
}

- (CORevision *)currentRevision
{
    return self.currentBranch.currentRevision;
}

- (void)setCurrentRevision: (CORevision *)revision
{
    self.currentBranch.currentRevision = revision;
}

- (CORevision *)headRevision
{
    return self.currentBranch.headRevision;
}

- (void)setHeadRevision: (CORevision *)revision
{
    self.currentBranch.headRevision = revision;
}

- (COSQLiteStore *)store
{
    return _parentContext.store;
}

#pragma mark Committing Changes -

- (int64_t)lastTransactionID
{
    return [_parentContext lastTransactionIDForPersistentRootUUID: _UUID].longLongValue;
}

- (void)setLastTransactionID: (int64_t) value
{
    [_parentContext setLastTransactionID: value forPersistentRootUUID: _UUID];
}

- (BOOL)commitWithIdentifier: (NSString *)aCommitDescriptorId
                    metadata: (NSDictionary *)additionalMetadata
                   undoTrack: (COUndoTrack *)undoTrack
                       error: (COError **)anError
{
    NILARG_EXCEPTION_TEST(aCommitDescriptorId);
    INVALIDARG_EXCEPTION_TEST(additionalMetadata,
        ![additionalMetadata containsKey: aCommitDescriptorId]);

    NSMutableDictionary *metadata =
        [@{ kCOCommitMetadataIdentifier: aCommitDescriptorId } mutableCopy];

    if (additionalMetadata != nil)
    {
        [metadata addEntriesFromDictionary: additionalMetadata];
    }
    return [_parentContext commitWithMetadata: metadata
                  restrictedToPersistentRoots: @[self]
                                withUndoTrack: undoTrack
                                        error: anError];
}

- (BOOL)commit
{
    return [self commitWithMetadata: @{}];
}

- (BOOL)commitWithMetadata: (NSDictionary *)metadata
{
    return [_parentContext commitWithMetadata: metadata
                  restrictedToPersistentRoots: @[self]
                                withUndoTrack: nil
                                        error: NULL];
}

- (BOOL)isPersistentRootUncommitted
{
    return _savedState == nil;
}

- (void) saveCommitWithMetadata: (NSDictionary *)metadata transaction: (COStoreTransaction *)txn
{
    if (self.hasChanges
        && self.deleted
        && self.persistentRootInfo.deleted)
    {
        [NSException raise: NSGenericException
                    format: @"Attempted to commit changes to deleted persistent root %@", self];
    }
    
    ETAssert(self.currentBranch != nil);
    ETAssert(self.rootObject != nil);
    ETAssert([self.rootObject isRoot]);
    ETAssert(self.objectGraphContext.rootObject != nil
             || self.currentBranch.objectGraphContextWithoutUnfaulting.rootObject != nil);
    
    if (self.persistentRootUncommitted)
    {
        BOOL usingCurrentBranchObjectGraph = YES;
        
        if (_cheapCopyRevisionUUID == nil)
        {
            ETAssert(!(self.currentBranch.objectGraphContextWithoutUnfaulting.hasChanges
                       && _currentBranchObjectGraph.hasChanges));
            // FIXME: Move this into -createPersistentRootWithInitialItemGraph:
            // and make that take a id<COItemGraph>

            COObjectGraphContext *graphCtx = _currentBranchObjectGraph;
            if (self.currentBranch.objectGraphContextWithoutUnfaulting.hasChanges)
            {
                usingCurrentBranchObjectGraph = NO;
                graphCtx = self.currentBranch.objectGraphContextWithoutUnfaulting;
            }
            
            [graphCtx doPreCommitChecks];
            
            // FIXME: check both _currentBranchObjectGraph and branch.objectGraphContext
            // FIXME: After, update the other graph with the contents of the one we committed
            COItemGraph *graphCopy = [[COItemGraph alloc] initWithItemGraph: graphCtx];
                        
            _savedState = [txn createPersistentRootWithInitialItemGraph: graphCopy
                                                                   UUID: self.UUID
                                                             branchUUID: self.currentBranch.UUID
                                                       revisionMetadata: metadata];
        }
        else
        {
            // Committing a cheap copy, so there must be a parent branch
            ETUUID *parentBranchUUID = self.currentBranch.parentBranch.UUID;
            ETAssert(parentBranchUUID != nil);
            ETAssert(_cheapCopyPersistentRootUUID != nil);
            
            const BOOL currentBranchObjectGraphHasChanges = _currentBranchObjectGraph.hasChanges;
            const BOOL specificBranchObjectGraphHasChanges = self.currentBranch.objectGraphContextWithoutUnfaulting.hasChanges;
            
            ETAssert(!(currentBranchObjectGraphHasChanges && specificBranchObjectGraphHasChanges));
            
            if (currentBranchObjectGraphHasChanges || specificBranchObjectGraphHasChanges)
            {
                ETUUID *newRevisionUUID = [ETUUID UUID];
                
                _savedState = [txn createPersistentRootCopyWithUUID: _UUID
                                           parentPersistentRootUUID: _cheapCopyPersistentRootUUID
                                                         branchUUID: self.currentBranch.UUID
                                                   parentBranchUUID: parentBranchUUID
                                                initialRevisionUUID: newRevisionUUID];
                
                COItemGraph *modifiedItems;
                if (currentBranchObjectGraphHasChanges)
                {
                    modifiedItems = _currentBranchObjectGraph.modifiedItemsSnapshot;
                }
                else
                {
                    modifiedItems = self.currentBranch.objectGraphContextWithoutUnfaulting.modifiedItemsSnapshot;
                    usingCurrentBranchObjectGraph = NO;
                }
                
                [txn writeRevisionWithModifiedItems: modifiedItems
                                       revisionUUID: newRevisionUUID
                                           metadata: metadata
                                   parentRevisionID: _cheapCopyRevisionUUID
                              mergeParentRevisionID: nil
                                 persistentRootUUID: _UUID
                                         branchUUID: self.currentBranch.UUID];
            }
            else
            {
                _savedState = [txn createPersistentRootCopyWithUUID: _UUID
                                           parentPersistentRootUUID: _cheapCopyPersistentRootUUID
                                                         branchUUID: self.currentBranch.UUID
                                                   parentBranchUUID: parentBranchUUID
                                                initialRevisionUUID: _cheapCopyRevisionUUID];
            }
        }
        ETAssert(_savedState != nil);
        ETUUID *initialRevID = _savedState.currentBranchInfo.currentRevisionUUID;
        ETAssert(initialRevID != nil);

        [_parentContext recordPersistentRootCreation: self
                                 atInitialRevisionID: initialRevID];
        
        // N.B., we don't call -saveCommitWithMetadata: on the branch,
        // because the store call -createPersistentRootWithInitialContents:
        // handles creating the initial branch.
        
        [self.currentBranch didMakeInitialCommitWithRevisionUUID: initialRevID transaction: txn];
        
        if (usingCurrentBranchObjectGraph)
        {
            [_currentBranchObjectGraph acceptAllChanges];
            [self.currentBranch.objectGraphContextWithoutUnfaulting setItemGraph: _currentBranchObjectGraph];
        }
        else
        {
            [self.currentBranch.objectGraphContextWithoutUnfaulting acceptAllChanges];
            [_currentBranchObjectGraph setItemGraph: self.currentBranch.objectGraphContext];
        }

        [self validateNewObjectGraphContext: _currentBranchObjectGraph
                                createdFrom: self.currentBranch.objectGraphContextWithoutUnfaulting];
    }
    else
    {
        // Commit changes in our branches
        
        // N.B. Don't use -branches because that only returns non-deleted branches
        for (COBranch *branch in _branchForUUID.allValues)
        {
            [branch saveCommitWithMetadata: metadata transaction: txn];
        }
        
        // Commit a change to the current branch, if needed.
        // Needs to be done after because the above loop may create the branch
        if (![_savedState.currentBranchUUID isEqual: _currentBranchUUID])
        {
            [txn setCurrentBranch: _currentBranchUUID
                forPersistentRoot: self.UUID];
            
            [_parentContext recordPersistentRoot: self
                                setCurrentBranch: self.currentBranch
                                       oldBranch: [self branchForUUID: _savedState.currentBranchUUID]];
        }
        
        // N.B.: Ugly, the ordering of changes needs to be carefully controlled
        for (COBranch *branch in _branchForUUID.allValues)
        {
            [branch saveDeletionWithTransaction: txn];
        }
    }
    
    if (_metadataChanged)
    {
        [txn setMetadata: _metadata forPersistentRoot: _UUID];
        
        [_parentContext recordPersistentRootSetMetadata: self
                                            oldMetadata: _savedState.metadata];
        
        _metadataChanged = NO;
    }
    
    ETAssert([self.branchesPendingInsertion isEmpty]);
}

- (void)clearBranchesPendingDeletionAndUndeletion
{
    [_branchesPendingDeletion removeAllObjects];
    [_branchesPendingUndeletion removeAllObjects];
}

- (COPersistentRootInfo *)persistentRootInfo
{
    return _savedState;
}

- (void)reloadPersistentRootInfo
{
    COPersistentRootInfo *newInfo = [self.store persistentRootInfoForUUID: self.UUID];

    if (newInfo == nil)
        return;

    _savedState = newInfo;
}

- (void)didMakeNewCommit
{
    [self reloadPersistentRootInfo];
    
    for (COBranch *branch in self.branches)
    {
        [branch updateRevisions: NO];
    }
}

#pragma mark Creating and Updating Branches -

- (COBranch *)makeBranchWithLabel: (NSString *)aLabel
                       atRevision: (CORevision *)aRev
                     parentBranch: (COBranch *)aParent
{
    COBranch *newBranch = [[COBranch alloc] initWithUUID: [ETUUID UUID]
                                          persistentRoot: self
                                        parentBranchUUID: aParent.UUID
                              parentRevisionForNewBranch: aRev.UUID];
    
    newBranch.metadata = @{ @"COBranchLabel": aLabel };
    
    _branchForUUID[newBranch.UUID] = newBranch;
    
    return newBranch;
}

- (COBranch *)makeBranchWithUUID: (ETUUID *)aUUID
                        metadata: (NSDictionary *)metadata
                      atRevision: (CORevision *)aRev
                    parentBranch: (COBranch *)aParent
{
    COBranch *newBranch = [[COBranch alloc] initWithUUID: aUUID
                                          persistentRoot: self
                                        parentBranchUUID: aParent.UUID
                              parentRevisionForNewBranch: aRev.UUID];
    
    if (metadata != nil)
    {
        newBranch.metadata = metadata;
    }

    _branchForUUID[newBranch.UUID] = newBranch;
    
    return newBranch;
}

- (void)updateBranchWithBranchInfo: (COBranchInfo *)branchInfo compacted: (BOOL)wasCompacted
{
    COBranch *branch = _branchForUUID[branchInfo.UUID];
    
    if (branch == nil)
    {
        branch = [[COBranch alloc] initWithUUID: branchInfo.UUID
                                 persistentRoot: self
                               parentBranchUUID: branchInfo.parentBranchUUID
                     parentRevisionForNewBranch: nil];
        
        _branchForUUID[branchInfo.UUID] = branch;
    }
    else
    {
        [branch updateWithBranchInfo: branchInfo
                           compacted: wasCompacted];
    }
}

#pragma mark Notifications Handling -

- (void)storePersistentRootDidChange: (NSNotification *)notif
                       isDistributed: (BOOL)isDistributed
{
//  NSLog(@"++++Not ignoring update notif %d > %d (distributed: %d)",
//        (int)notifTransaction, (int)_lastTransactionID, (int)isDistributed);
    
    COPersistentRootInfo *info =
        [self.store persistentRootInfoForUUID: self.UUID];
    
    /* If we are receiving a changed/compacted notification but the persistent
       root has been finalized in the meantime (distributed notifications are 
       delivered in LIFO order). */
    if (info == nil)
        return;

    _savedState = info;
    
    for (ETUUID *uuid in info.branchUUIDs)
    {
        COBranchInfo *branchInfo = [info branchInfoForUUID: uuid];
        BOOL wasCompacted =
            [notif.userInfo[kCOStoreCompactedPersistentRoots] containsObject: self.UUID.stringValue];
    
        [self updateBranchWithBranchInfo: branchInfo
                               compacted: wasCompacted];
    }
    
    // FIXME: Factor out like -[COBranch updateBranchWithBranchInfo:compacted:]
    // TODO: Test that _everything_ is reloaded
    
    _currentBranchUUID =  _savedState.currentBranchUUID;
    self.lastTransactionID = _savedState.transactionID;
    _metadata = _savedState.metadata;
    
    [self reloadCurrentBranchObjectGraph];
    
    [self sendChangeNotification];
}

- (void)sendChangeNotification
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName: COPersistentRootDidChangeNotification
                      object: self];
}

#pragma mark Previewing Old Revision -

- (COObjectGraphContext *)objectGraphContextForPreviewingRevision: (CORevision *)aRevision
{
    COObjectGraphContext *ctx = [[COObjectGraphContext alloc]
        initWithModelDescriptionRepository: self.editingContext.modelDescriptionRepository
                      migrationDriverClass: self.editingContext.migrationDriverClass];
    id <COItemGraph> items = [self.store itemGraphForRevisionUUID: aRevision.UUID
                                                     persistentRoot: _UUID];

    [ctx setItemGraph: items];

    return ctx;
}

- (void)assertNotZombie
{
    if (self.isZombie)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Method called on zombie COPersistentRoot"];
    }
}

- (void)makeZombie
{
    [self assertNotZombie];
    _parentContext = nil;
}

@end
