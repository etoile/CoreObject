#import "COCommandSetCurrentVersionForBranch.h"
#import <EtoileFoundation/Macros.h>

#import "COEditingContext.h"
#import "COEditingContext+Private.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "CORevision.h"
#import "CORevisionCache.h"

#import "COItemGraphDiff.h"
#import "COObjectGraphContext.h"
#import "COSQLiteStore.h"

static NSString * const kCOCommandBranchUUID = @"COCommandBranchUUID";
static NSString * const kCOCommandOldRevisionID = @"COCommandOldRevisionID";
static NSString * const kCOCommandNewRevisionID = @"COCommandNewRevisionID";
static NSString * const kCOCommandOldHeadRevisionID = @"COCommandOldHeadRevisionID";
static NSString * const kCOCommandNewHeadRevisionID = @"COCommandNewHeadRevisionID";


@implementation COCommandSetCurrentVersionForBranch 

@synthesize branchUUID = _branchUUID;
@synthesize oldRevisionID = _oldRevisionID;
@synthesize revisionID = _newRevisionID;

@synthesize oldHeadRevisionID = _oldHeadRevisionID;
@synthesize headRevisionID = _newHeadRevisionID;


- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandBranchUUID]];
    self.oldRevisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOCommandOldRevisionID]];
    self.revisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOCommandNewRevisionID]];
	self.oldHeadRevisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOCommandOldHeadRevisionID]];
    self.headRevisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOCommandNewHeadRevisionID]];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    [result setObject: [_branchUUID stringValue] forKey: kCOCommandBranchUUID];
    [result setObject: [_oldRevisionID plist] forKey:kCOCommandOldRevisionID];
    [result setObject: [_newRevisionID plist] forKey: kCOCommandNewRevisionID];
	[result setObject: [_oldHeadRevisionID plist] forKey:kCOCommandOldHeadRevisionID];
    [result setObject: [_newHeadRevisionID plist] forKey: kCOCommandNewHeadRevisionID];
    return result;
}

- (COCommand *) inverse
{
    COCommandSetCurrentVersionForBranch *inverse = [[COCommandSetCurrentVersionForBranch alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    
    inverse.branchUUID = _branchUUID;
    inverse.oldRevisionID = _newRevisionID;
    inverse.revisionID = _oldRevisionID;
	inverse.oldHeadRevisionID = _newHeadRevisionID;
    inverse.headRevisionID = _oldHeadRevisionID;
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
	NILARG_EXCEPTION_TEST(aContext);
    // FIXME: Recalculates merge, wasteful
    
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
	ETAssert(branch != nil);

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
	NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
	ETAssert(branch != nil);

    if ([[[branch currentRevision] revisionID] isEqual: _oldRevisionID])
    {
        [branch setCurrentRevision:
            [aContext revisionForRevisionID: _newRevisionID]];
		
		[branch setNewestRevision:
			[aContext revisionForRevisionID: _newHeadRevisionID]];
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
        
		// FIXME: Handle cross-persistent root relationship constraint violations,
		// if we introduce those
        [[branch objectGraphContext] insertOrUpdateItems: items];
		
		// N.B. newHeadRevisionID is intentionally ignored here, it only applies
		// if we were able to do a non-selective undo.
    }
}

- (CORevision *)oldRevision
{
	return [CORevisionCache revisionForRevisionID: _oldRevisionID
	                                    storeUUID: [self storeUUID]];
}

- (CORevision *)revision
{
	return [CORevisionCache revisionForRevisionID: _newRevisionID
	                                    storeUUID: [self storeUUID]];
}

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)UUID
{
	return [_newRevisionID revisionUUID];
}

- (ETUUID *)branchUUID
{
	return _branchUUID;
}

- (NSDictionary *)metadata
{
	return [[self revision] metadata];
}

- (NSString *)localizedTypeDescription
{
	return [[self revision] localizedTypeDescription];
}

- (NSString *)localizedShortDescription;
{
	return [[self revision] localizedShortDescription];
}

@end
