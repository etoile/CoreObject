#import "COPersistentRootInfo.h"
#import "COBranchInfo.h"

@implementation COPersistentRootInfo

@synthesize UUID = uuid_;
@synthesize currentBranchUUID = currentBranch_;
@synthesize branchForUUID = branchForUUID_;
@synthesize changeCount = _changeCount;
@synthesize deleted = _deleted;

- (void) dealloc
{
    [uuid_ release];
    [branchForUUID_ release];
    [currentBranch_ release];
    [super dealloc];
}

- (NSSet *) branchUUIDs
{
    return [NSSet setWithArray: [branchForUUID_ allKeys]];
}

- (NSArray *) branches
{
    return [branchForUUID_ allValues];
}

- (COBranchInfo *)branchInfoForUUID: (ETUUID *)aUUID
{
    return [branchForUUID_ objectForKey: aUUID];
}
- (COBranchInfo *)currentBranchInfo
{
    return [self branchInfoForUUID: [self currentBranchUUID]];
}
- (CORevisionID *)currentRevisionID
{
    return [[self currentBranchInfo] currentRevisionID];
}

- (NSArray *)branchInfosWithMetadataValue: (id)aValue forKey: (NSString *)aKey
{
    NSMutableArray *result = [NSMutableArray array];
    for (COBranchInfo *info in [branchForUUID_ allValues])
    {
        if ([[[info metadata] objectForKey: aKey] isEqual: aValue])
        {
            [result addObject: info];
        }
    }
    return result;
}

@end