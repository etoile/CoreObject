/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import "COCommandSetCurrentVersionForBranch.h"
#import <EtoileFoundation/Macros.h>

#import "COEditingContext.h"
#import "COEditingContext+Private.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "CORevision.h"
#import "CORevisionCache.h"
#import "COItem.h"

#import "COLeastCommonAncestor.h"
#import "CODiffManager.h"
#import "COObjectGraphContext.h"
#import "COSQLiteStore.h"
#import "COUndoTrack.h"

static NSString * const kCOCommandBranchUUID = @"COCommandBranchUUID";
static NSString * const kCOCommandOldRevisionID = @"COCommandOldRevisionID";
static NSString * const kCOCommandNewRevisionID = @"COCommandNewRevisionID";
static NSString * const kCOCommandOldHeadRevisionID = @"COCommandOldHeadRevisionID";
static NSString * const kCOCommandNewHeadRevisionID = @"COCommandNewHeadRevisionID";


@implementation COCommandSetCurrentVersionForBranch 

@synthesize branchUUID = _branchUUID;
@synthesize oldRevisionUUID = _oldRevisionUUID;
@synthesize revisionUUID = _newRevisionUUID;

@synthesize oldHeadRevisionUUID = _oldHeadRevisionUUID;
@synthesize headRevisionUUID = _newHeadRevisionUUID;


- (id) initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.branchUUID = [ETUUID UUIDWithString: plist[kCOCommandBranchUUID]];
    self.oldRevisionUUID = [ETUUID UUIDWithString: plist[kCOCommandOldRevisionID]];
    self.revisionUUID = [ETUUID UUIDWithString: plist[kCOCommandNewRevisionID]];
	self.oldHeadRevisionUUID = [ETUUID UUIDWithString: plist[kCOCommandOldHeadRevisionID]];
    self.headRevisionUUID = [ETUUID UUIDWithString: plist[kCOCommandNewHeadRevisionID]];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
    [result setObject: [_branchUUID stringValue] forKey: kCOCommandBranchUUID];
    [result setObject: [_oldRevisionUUID stringValue] forKey:kCOCommandOldRevisionID];
    [result setObject: [_newRevisionUUID stringValue] forKey: kCOCommandNewRevisionID];
	[result setObject: [_oldHeadRevisionUUID stringValue] forKey:kCOCommandOldHeadRevisionID];
    [result setObject: [_newHeadRevisionUUID stringValue] forKey: kCOCommandNewHeadRevisionID];
    return result;
}

- (COCommand *) inverse
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

- (CODiffManager *) diffToSelectivelyApplyToContext: (COEditingContext *)aContext
{
    // Current state of the branch
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    
    COItemGraph *currentGraph = [[proot store] itemGraphForRevisionUUID: [[branch currentRevision] UUID]
														 persistentRoot: _persistentRootUUID];
    
    COItemGraph *oldGraph = [[proot store] itemGraphForRevisionUUID: _oldRevisionUUID persistentRoot: _persistentRootUUID];
    COItemGraph *newGraph = [[proot store] itemGraphForRevisionUUID: _newRevisionUUID persistentRoot: _persistentRootUUID];
    
    CODiffManager *diff1 = [CODiffManager diffItemGraph: oldGraph
										  withItemGraph: newGraph
							 modelDescriptionRepository: [aContext modelDescriptionRepository]
									   sourceIdentifier: @"diff1"];
    CODiffManager *diff2 = [CODiffManager diffItemGraph: oldGraph
										  withItemGraph: currentGraph
							 modelDescriptionRepository: [aContext modelDescriptionRepository]
									   sourceIdentifier: @"diff2"];
    
    CODiffManager *merged = [diff1 diffByMergingWithDiff: diff2];
	
	if([merged hasConflicts])
	{
		NSLog(@"Attempting to auto-resolve conflicts favouring the diff1...");
		[merged resolveConflictsFavoringSourceIdentifier: @"diff1"];
	}
	
    return merged;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
	return YES;
//	NILARG_EXCEPTION_TEST(aContext);
//    // FIXME: Recalculates merge, wasteful
//    
//    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
//    COBranch *branch = [proot branchForUUID: _branchUUID];
//	ETAssert(branch != nil);
//
//    if ([[[branch currentRevision] UUID] isEqual: _oldRevisionUUID])
//    {
//        return YES;
//    }
//    else
//    {
//        COItemGraphDiff *merged = [self diffToSelectivelyApplyToContext: aContext];
//        
//        return ![merged hasConflicts];
//    }
}

- (void) applyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
	ETAssert(branch != nil);

    if ([[[branch currentRevision] UUID] isEqual: _oldRevisionUUID]
		&& branch.supportsRevert)
    {
        [branch setCurrentRevision:
            [aContext revisionForRevisionUUID: _newRevisionUUID persistentRootUUID: _persistentRootUUID]];
	
		if (![COLeastCommonAncestor isRevision: _newHeadRevisionUUID
					 equalToOrParentOfRevision: _oldHeadRevisionUUID
								persistentRoot: _persistentRootUUID
										 store: [aContext store]])
		{
			[branch setHeadRevision:
				[aContext revisionForRevisionUUID: _newHeadRevisionUUID persistentRootUUID: _persistentRootUUID]];
		}
    }
    else
    {
		_currentRevisionBeforeSelectiveApply = [[branch currentRevision] UUID];
		
        CODiffManager *merged = [self diffToSelectivelyApplyToContext: aContext];
        COItemGraph *oldGraph = [[proot store] itemGraphForRevisionUUID: _oldRevisionUUID persistentRoot: _persistentRootUUID];
        
        id<COItemGraph> result = [[COItemGraph alloc] initWithItemGraph: oldGraph];
		[merged applyTo: result];
        
        // FIXME: Works, but an ugly API mismatch when setting object graph context contents
        NSMutableArray *items = [NSMutableArray array];
        for (ETUUID *uuid in [result itemUUIDs])
        {
			COItem *replacementItem = [result itemForUUID: uuid];
			COItem *existingItem = [[branch objectGraphContext] itemForUUID: uuid];
			if (existingItem == nil
				|| ![existingItem isEqual: replacementItem])
			{
				[items addObject: replacementItem];
			}
        }
        
		// FIXME: Handle cross-persistent root relationship constraint violations,
		// if we introduce those
        [[branch objectGraphContext] insertOrUpdateItems: items];
		
		// N.B. newHeadRevisionID is intentionally ignored here, it only applies
		// if we were able to do a non-selective undo.
    }
}

- (COCommandSetCurrentVersionForBranch *) rewrittenCommandAfterCommitInContext: (COEditingContext *)aContext
{
	if (_currentRevisionBeforeSelectiveApply != nil)
	{
		NILARG_EXCEPTION_TEST(aContext);
		
		COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
		COBranch *branch = [proot branchForUUID: _branchUUID];
		ETAssert(branch != nil);
	
		
		COCommandSetCurrentVersionForBranch *rewritten = [[COCommandSetCurrentVersionForBranch alloc] init];
		rewritten.storeUUID = _storeUUID;
		rewritten.persistentRootUUID = _persistentRootUUID;
		
		rewritten.branchUUID = _branchUUID;
		
		rewritten.oldRevisionUUID = _currentRevisionBeforeSelectiveApply;
		rewritten.revisionUUID = [[branch currentRevision] UUID];
		rewritten.oldHeadRevisionUUID = _currentRevisionBeforeSelectiveApply;
		rewritten.headRevisionUUID = [[branch currentRevision] UUID];
		return rewritten;
	}
	else
	{
		return self;
	}

}

- (NSString *)kind
{
	return _(@"Branch Version Change");
}

- (CORevision *)oldRevision
{
	ETAssert(_parentUndoTrack != nil);
	return [_parentUndoTrack.editingContext revisionForRevisionUUID: _oldRevisionUUID
												 persistentRootUUID: _persistentRootUUID];
}

- (CORevision *)revision
{
	ETAssert(_parentUndoTrack != nil);
	return [_parentUndoTrack.editingContext revisionForRevisionUUID: _newRevisionUUID
												 persistentRootUUID: _persistentRootUUID];
}

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)UUID
{
	return [[self revision] UUID];
}

- (ETUUID *)branchUUID
{
	return _branchUUID;
}

- (NSDictionary *)metadata
{
	return [[self revision] metadata];
}

- (NSDate *)date
{
	return [[self revision] date];
}

- (NSString *)localizedShortDescription
{
	return [[self revision] localizedShortDescription];
}

@end
