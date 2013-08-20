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
@synthesize newRevisionID = _newRevisionID;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOEditBranchUUID]];
    self.oldRevisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOEditOldRevisionID]];
    self.newRevisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOEditNewRevisionID]];
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
    inverse.displayName = _displayName;
    
    inverse.branchUUID = _branchUUID;
    inverse.oldRevisionID = _newRevisionID;
    inverse.newRevisionID = _oldRevisionID;
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    // FIXME: Actual logic here..
    return YES;
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
        // Selectively apply the _oldRevisionID -> _newRevisionID change
     
        // FIXME: Error handling
        
        COItemGraph *oldGraph = [[proot store] itemGraphForRevisionID: _oldRevisionID];
        COItemGraph *newGraph = [[proot store] itemGraphForRevisionID: _newRevisionID];
        
        // Current state of the branch
        
        COItemGraph *currentGraph = [[proot store] itemGraphForRevisionID:
                                     [[branch currentRevision] revisionID]];
        
        COItemGraphDiff *diff1 = [COItemGraphDiff diffItemTree: oldGraph withItemTree: newGraph sourceIdentifier: @"diff1"];
        COItemGraphDiff *diff2 = [COItemGraphDiff diffItemTree: oldGraph withItemTree: currentGraph sourceIdentifier: @"diff2"];
        
        COItemGraphDiff *merged = [diff1 itemTreeDiffByMergingWithDiff: diff2];
        
        id<COItemGraph> result = [merged itemTreeWithDiffAppliedToItemGraph: oldGraph];
        
        [[branch objectGraphContext] setItemGraph: result];
    }
}

@end
