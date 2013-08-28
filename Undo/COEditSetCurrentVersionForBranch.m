#import "COEditSetCurrentVersionForBranch.h"
#import <EtoileFoundation/Macros.h>

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"

#import "COItemGraphDiff.h"
#import "COObjectGraphContext.h"

static NSString * const kCOEditBranchUUID = @"COEditBranchUUID";
static NSString * const kCOEditOldRevisionID = @"COEditOldRevisionID";
static NSString * const kCOEditNewRevisionID = @"COEditNewRevisionID";

@implementation COEditSetCurrentVersionForBranch 

@synthesize branchUUID = _branchUUID;
@synthesize oldRevisionID = _oldRevisionID;
@synthesize revisionID = _newRevisionID;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOEditBranchUUID]];
    self.oldRevisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOEditOldRevisionID]];
    self.revisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOEditNewRevisionID]];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    [result setObject: [_branchUUID stringValue] forKey: kCOEditBranchUUID];
    [result setObject: [_oldRevisionID plist] forKey:kCOEditOldRevisionID];
    [result setObject: [_newRevisionID plist] forKey: kCOEditNewRevisionID];
    return result;
}

- (COEdit *) inverse
{
    COEditSetCurrentVersionForBranch *inverse = [[[COEditSetCurrentVersionForBranch alloc] init] autorelease];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    
    inverse.branchUUID = _branchUUID;
    inverse.oldRevisionID = _newRevisionID;
    inverse.revisionID = _oldRevisionID;
    return inverse;
}

- (COItemGraphDiff *) diffToSelectivelyApplyToContext: (COEditingContext *)aContext
{
    // Current state of the branch
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    
    COItemGraph *currentGraph = [[proot store] itemGraphForRevisionID:
                                 [[branch currentRevision] revisionID]];
    
    COItemGraph *oldGraph = [[proot store] itemGraphForRevisionID: _oldRevisionID];
    COItemGraph *newGraph = [[proot store] itemGraphForRevisionID: _newRevisionID];
    
    COItemGraphDiff *diff1 = [COItemGraphDiff diffItemTree: oldGraph withItemTree: newGraph sourceIdentifier: @"diff1"];
    COItemGraphDiff *diff2 = [COItemGraphDiff diffItemTree: oldGraph withItemTree: currentGraph sourceIdentifier: @"diff2"];
    
    COItemGraphDiff *merged = [diff1 itemTreeDiffByMergingWithDiff: diff2];
    return merged;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    // FIXME: Recalculates merge, wasteful
    
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    
    COBranch *branch = [proot branchForUUID: _branchUUID];
    if ([[[branch currentRevision] revisionID] isEqual: _oldRevisionID])
    {
        return YES;
    }
    else
    {
        COItemGraphDiff *merged = [self diffToSelectivelyApplyToContext: aContext];
        
        return ![merged hasConflicts];
    }
}

- (void) applyToContext: (COEditingContext *)aContext
{
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    
    COBranch *branch = [proot branchForUUID: _branchUUID];
    if ([[[branch currentRevision] revisionID] isEqual: _oldRevisionID])
    {
        [branch setCurrentRevision: [CORevision revisionWithStore: [proot store]
                                                       revisionID: _newRevisionID]];
    }
    else
    {
        COItemGraphDiff *merged = [self diffToSelectivelyApplyToContext: aContext];
        COItemGraph *oldGraph = [[proot store] itemGraphForRevisionID: _oldRevisionID];
        
        id<COItemGraph> result = [merged itemTreeWithDiffAppliedToItemGraph: oldGraph];
        
        // FIXME: Works, but an ugly API mismatch when setting object graph context contents
        NSMutableArray *items = [NSMutableArray array];
        for (ETUUID *uuid in [result itemUUIDs])
        {
            [items addObject: [result itemForUUID: uuid]];
        }
        
        [[branch objectGraphContext] insertOrUpdateItems: items];
    }
}

@end
