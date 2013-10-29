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
@synthesize oldRevisionUUID = _oldRevisionUUID;
@synthesize revisionUUID = _newRevisionUUID;

@synthesize oldHeadRevisionUUID = _oldHeadRevisionUUID;
@synthesize headRevisionUUID = _newHeadRevisionUUID;


- (id) initWithPropertyList: (id)plist
{
    self = [super initWithPropertyList: plist];
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
    inverse.timestamp = _timestamp;
    
    inverse.branchUUID = _branchUUID;
    inverse.oldRevisionUUID = _newRevisionUUID;
    inverse.revisionUUID = _oldRevisionUUID;
	inverse.oldHeadRevisionUUID = _newHeadRevisionUUID;
    inverse.headRevisionUUID = _oldHeadRevisionUUID;
    return inverse;
}

- (COItemGraphDiff *) diffToSelectivelyApplyToContext: (COEditingContext *)aContext
{
    // Current state of the branch
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    
    COItemGraph *currentGraph = [[proot store] itemGraphForRevisionUUID: [[branch currentRevision] UUID]
														 persistentRoot: _persistentRootUUID];
    
    COItemGraph *oldGraph = [[proot store] itemGraphForRevisionUUID: _oldRevisionUUID persistentRoot: _persistentRootUUID];
    COItemGraph *newGraph = [[proot store] itemGraphForRevisionUUID: _newRevisionUUID persistentRoot: _persistentRootUUID];
    
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

    if ([[[branch currentRevision] UUID] isEqual: _oldRevisionUUID])
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

    if ([[[branch currentRevision] UUID] isEqual: _oldRevisionUUID])
    {
        [branch setCurrentRevision:
            [aContext revisionForRevisionUUID: _newRevisionUUID persistentRootUUID: _persistentRootUUID]];
		
		[branch setHeadRevision:
			[aContext revisionForRevisionUUID: _newHeadRevisionUUID persistentRootUUID: _persistentRootUUID]];
    }
    else
    {
        COItemGraphDiff *merged = [self diffToSelectivelyApplyToContext: aContext];
        COItemGraph *oldGraph = [[proot store] itemGraphForRevisionUUID: _oldRevisionUUID persistentRoot: _persistentRootUUID];
        
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

- (NSString *)kind
{
	return _(@"Branch Version Change");
}

- (CORevision *)oldRevision
{
	return [CORevisionCache revisionForRevisionUUID: _oldRevisionUUID
								 persistentRootUUID: _persistentRootUUID
										  storeUUID: [self storeUUID]];
}

- (CORevision *)revision
{
	return [CORevisionCache revisionForRevisionUUID: _newRevisionUUID
								 persistentRootUUID: _persistentRootUUID
										  storeUUID: [self storeUUID]];
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

- (NSString *)localizedShortDescription
{
	return [[self revision] localizedShortDescription];
}

@end
