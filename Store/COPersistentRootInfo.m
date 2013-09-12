#import "COPersistentRootInfo.h"
#import "COBranchInfo.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COPersistentRootInfo

@synthesize UUID = uuid_;
@synthesize currentBranchUUID = currentBranch_;
@synthesize branchForUUID = branchForUUID_;
@synthesize deleted = _deleted;


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