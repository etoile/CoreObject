/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COCommandSetCurrentVersionForBranch.h"

#import "COEditingContext.h"
#import "COEditingContext+Private.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "COItem.h"

#import "COLeastCommonAncestor.h"
#import "CODiffManager.h"
#import "COObjectGraphContext.h"
#import "COUndoTrack.h"
#import "COStoreTransaction.h"

static NSString *const kCOCommandBranchUUID = @"COCommandBranchUUID";
static NSString *const kCOCommandOldRevisionID = @"COCommandOldRevisionID";
static NSString *const kCOCommandNewRevisionID = @"COCommandNewRevisionID";
static NSString *const kCOCommandOldHeadRevisionID = @"COCommandOldHeadRevisionID";
static NSString *const kCOCommandNewHeadRevisionID = @"COCommandNewHeadRevisionID";


@implementation COCommandSetCurrentVersionForBranch

@synthesize branchUUID = _branchUUID;
@synthesize oldRevisionUUID = _oldRevisionUUID;
@synthesize revisionUUID = _newRevisionUUID;

@synthesize oldHeadRevisionUUID = _oldHeadRevisionUUID;
@synthesize headRevisionUUID = _newHeadRevisionUUID;

- (instancetype)initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.branchUUID = [ETUUID UUIDWithString: plist[kCOCommandBranchUUID]];
    self.oldRevisionUUID = [ETUUID UUIDWithString: plist[kCOCommandOldRevisionID]];
    self.revisionUUID = [ETUUID UUIDWithString: plist[kCOCommandNewRevisionID]];
    self.oldHeadRevisionUUID = [ETUUID UUIDWithString: plist[kCOCommandOldHeadRevisionID]];
    self.headRevisionUUID = [ETUUID UUIDWithString: plist[kCOCommandNewHeadRevisionID]];
    return self;
}

- (id)propertyList
{
    NSMutableDictionary *result = super.propertyList;
    result[kCOCommandBranchUUID] = [_branchUUID stringValue];
    result[kCOCommandOldRevisionID] = [_oldRevisionUUID stringValue];
    result[kCOCommandNewRevisionID] = [_newRevisionUUID stringValue];
    result[kCOCommandOldHeadRevisionID] = [_oldHeadRevisionUUID stringValue];
    result[kCOCommandNewHeadRevisionID] = [_newHeadRevisionUUID stringValue];
    return result;
}

- (COCommand *)inverse
{
    COCommandSetCurrentVersionForBranch *inverse = [[COCommandSetCurrentVersionForBranch alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;

    inverse.branchUUID = _branchUUID;
    inverse.oldRevisionUUID = _newRevisionUUID;
    inverse.revisionUUID = _oldRevisionUUID;
    inverse.oldHeadRevisionUUID = _newHeadRevisionUUID;
    inverse.headRevisionUUID = _oldHeadRevisionUUID;
    return inverse;
}

- (CODiffManager *)diffToSelectivelyApplyToBranchCurrentRevision: (ETUUID *)currentRevisionUUID
                                          assumingEditingContext: (COEditingContext *)aContext
{
    COItemGraph *currentGraph = [aContext.store itemGraphForRevisionUUID: currentRevisionUUID
                                                          persistentRoot: _persistentRootUUID];

    COItemGraph *oldGraph = [aContext.store itemGraphForRevisionUUID: _oldRevisionUUID
                                                      persistentRoot: _persistentRootUUID];
    COItemGraph *newGraph = [aContext.store itemGraphForRevisionUUID: _newRevisionUUID
                                                      persistentRoot: _persistentRootUUID];

    CODiffManager *diff1 = [CODiffManager diffItemGraph: oldGraph
                                          withItemGraph: newGraph
                             modelDescriptionRepository: aContext.modelDescriptionRepository
                                       sourceIdentifier: @"diff1"];
    CODiffManager *diff2 = [CODiffManager diffItemGraph: oldGraph
                                          withItemGraph: currentGraph
                             modelDescriptionRepository: aContext.modelDescriptionRepository
                                       sourceIdentifier: @"diff2"];

    CODiffManager *merged = [diff1 diffByMergingWithDiff: diff2];

    if (merged.hasConflicts)
    {
        NSLog(@"Attempting to auto-resolve conflicts favouring the diff1...");
        [merged resolveConflictsFavoringSourceIdentifier: @"diff1"];
    }

    return merged;
}

- (BOOL)canApplyToContext: (COEditingContext *)aContext
{
    return YES;
//  NILARG_EXCEPTION_TEST(aContext);
//    // FIXME: Recalculates merge, wasteful
//    
//    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
//    COBranch *branch = [proot branchForUUID: _branchUUID];
//  ETAssert(branch != nil);
//
//    if (branch.currentRevision.UUID isEqual: _oldRevisionUUID])
//    {
//        return YES;
//    }
//    else
//    {
//        COItemGraphDiff *merged = [self diffToSelectivelyApplyToContext: aContext];
//        
//        return !merged.hasConflicts;
//    }
}

- (void)applyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    ETAssert(branch != nil);

    if ([branch.currentRevision.UUID isEqual: _oldRevisionUUID]
        && branch.supportsRevert)
    {
        branch.currentRevision = [aContext revisionForRevisionUUID: _newRevisionUUID
                                                persistentRootUUID: _persistentRootUUID];

        if (!CORevisionUUIDEqualToOrParent(_newHeadRevisionUUID,
                                           _oldHeadRevisionUUID,
                                           _persistentRootUUID,
                                           aContext))
        {
            branch.headRevision = [aContext revisionForRevisionUUID: _newHeadRevisionUUID
                                                 persistentRootUUID: _persistentRootUUID];
        }
    }
    else
    {
        _currentRevisionBeforeSelectiveApply = branch.currentRevision.UUID;

        CODiffManager *merged = [self diffToSelectivelyApplyToBranchCurrentRevision: _currentRevisionBeforeSelectiveApply
                                                             assumingEditingContext: aContext];
        COItemGraph *oldGraph = [proot.store itemGraphForRevisionUUID: _oldRevisionUUID
                                                       persistentRoot: _persistentRootUUID];

        id <COItemGraph> result = [[COItemGraph alloc] initWithItemGraph: oldGraph];
        [merged applyTo: result];

        // FIXME: Works, but an ugly API mismatch when setting object graph context contents
        NSMutableArray *items = [NSMutableArray array];
        for (ETUUID *uuid in result.itemUUIDs)
        {
            COItem *replacementItem = [result itemForUUID: uuid];
            COItem *existingItem = [branch.objectGraphContext itemForUUID: uuid];
            if (existingItem == nil
                || ![existingItem isEqual: replacementItem])
            {
                [items addObject: replacementItem];
            }
        }

        // FIXME: Handle cross-persistent root relationship constraint violations,
        // if we introduce those
        [branch.objectGraphContext insertOrUpdateItems: items];

        // N.B. newHeadRevisionID is intentionally ignored here, it only applies
        // if we were able to do a non-selective undo.
    }
}

+ (ETUUID *)currentRevisionUUIDForBranch: (COBranch *)branch
           withChangesInStoreTransaction: (COStoreTransaction *)txn
{
    NILARG_EXCEPTION_TEST(branch);
    NILARG_EXCEPTION_TEST(txn);

    ETUUID *valueFromEditingContext = branch.currentRevision.UUID;
    ETUUID *valueFromTransaction = [txn lastSetCurrentRevisionInTransactionForBranch: branch.UUID
                                                                    ofPersistentRoot: branch.persistentRoot.UUID];

    if (valueFromTransaction != nil)
        return valueFromTransaction;

    ETAssert(valueFromEditingContext != nil);
    return valueFromEditingContext;
}

- (void)addToStoreTransaction: (COStoreTransaction *)txn
         withRevisionMetadata: (NSDictionary *)metadata
  assumingEditingContextState: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    ETAssert(branch != nil);

    // N.B.: We must be very careful here, anywhere that we read state from aContext, we have
    // to assume all of the changes in txn have been applied

    ETUUID *branchCurrentRevisionUUID = [[self class] currentRevisionUUIDForBranch: branch
                                                     withChangesInStoreTransaction: txn];

    if ([branchCurrentRevisionUUID isEqual: _oldRevisionUUID] && branch.supportsRevert)
    {
        if (!CORevisionUUIDEqualToOrParent(_newHeadRevisionUUID,
                                           _oldHeadRevisionUUID,
                                           _persistentRootUUID,
                                           aContext))
        {
            [txn setCurrentRevision: _newRevisionUUID
                       headRevision: _newHeadRevisionUUID
                          forBranch: _branchUUID
                   ofPersistentRoot: _persistentRootUUID];
        }
        else
        {
            [txn setCurrentRevision: _newRevisionUUID
                       headRevision: nil
                          forBranch: _branchUUID
                   ofPersistentRoot: _persistentRootUUID];
        }
    }
    else
    {
        _currentRevisionBeforeSelectiveApply = branchCurrentRevisionUUID;

        CODiffManager *merged = [self diffToSelectivelyApplyToBranchCurrentRevision: branchCurrentRevisionUUID
                                                             assumingEditingContext: aContext];
        COItemGraph *oldGraph = [proot.store itemGraphForRevisionUUID: _oldRevisionUUID
                                                       persistentRoot: _persistentRootUUID];

        COItemGraph *result = [[COItemGraph alloc] initWithItemGraph: oldGraph];
        [merged applyTo: result];

        ETUUID *newRevisionUUID = [ETUUID UUID];

        // Filter out unmodified items
        // FIXME: Ugly

        COItemGraph *branchCurrentGraph = [aContext.store itemGraphForRevisionUUID: branchCurrentRevisionUUID
                                                                    persistentRoot: _persistentRootUUID];
        NSMutableArray *necessaryItems = [NSMutableArray array];
        for (ETUUID *uuid in result.itemUUIDs)
        {
            COItem *replacementItem = [result itemForUUID: uuid];
            COItem *existingItem = [branchCurrentGraph itemForUUID: uuid];
            if (existingItem == nil
                || ![existingItem isEqual: replacementItem])
            {
                [necessaryItems addObject: replacementItem];
            }
        }

        // Replace result with just the necessary items
        result = [[COItemGraph alloc] initWithItems: necessaryItems
                                       rootItemUUID: result.rootItemUUID];

        [txn writeRevisionWithModifiedItems: result
                               revisionUUID: newRevisionUUID
                                   metadata: metadata
                           parentRevisionID: branchCurrentRevisionUUID
                      mergeParentRevisionID: nil
                         persistentRootUUID: _persistentRootUUID
                                 branchUUID: _branchUUID];

        // N.B. newHeadRevisionID is intentionally ignored here, it only applies
        // if we were able to do a non-selective undo.

        [txn setCurrentRevision: newRevisionUUID
                   headRevision: newRevisionUUID
                      forBranch: _branchUUID
               ofPersistentRoot: _persistentRootUUID];
    }
}


- (NSString *)kind
{
    return _(@"Branch Version Change");
}

- (CORevision *)oldRevision
{
    ETAssert(_parentUndoTrack != nil);
    return [_parentUndoTrack.context revisionForRevisionUUID: _oldRevisionUUID
                                          persistentRootUUID: _persistentRootUUID];
}

- (CORevision *)revision
{
    ETAssert(_parentUndoTrack != nil);
    return [_parentUndoTrack.context revisionForRevisionUUID: _newRevisionUUID
                                          persistentRootUUID: _persistentRootUUID];
}

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)UUID
{
    return self.revision.UUID;
}

- (ETUUID *)branchUUID
{
    return _branchUUID;
}

- (NSDictionary *)metadata
{
    return self.revision.metadata;
}

- (NSDate *)date
{
    return self.revision.date;
}

- (NSString *)localizedShortDescription
{
    return self.revision.localizedShortDescription;
}

- (id)copyWithZone: (NSZone *)zone
{
    COCommandSetCurrentVersionForBranch *aCopy = [super copyWithZone: zone];
    aCopy->_branchUUID = _branchUUID;
    aCopy->_oldRevisionUUID = _oldRevisionUUID;
    aCopy->_newRevisionUUID = _newRevisionUUID;
    aCopy->_oldHeadRevisionUUID = _oldHeadRevisionUUID;
    aCopy->_newHeadRevisionUUID = _newHeadRevisionUUID;
    return aCopy;
}

@end
