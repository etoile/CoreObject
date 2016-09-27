/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "COPersistentRootInfo.h"
#import "COBranchInfo.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COPersistentRootInfo

@synthesize UUID = uuid_;
@synthesize currentBranchUUID = currentBranch_;
@synthesize branchForUUID = branchForUUID_;
@synthesize deleted = _deleted;
@synthesize transactionID = _transactionID;
@synthesize metadata = _metadata;

- (NSSet *) branchUUIDs
{
    return [NSSet setWithArray: branchForUUID_.allKeys];
}

- (NSArray *) branches
{
    return branchForUUID_.allValues;
}

- (COBranchInfo *)branchInfoForUUID: (ETUUID *)aUUID
{
    return branchForUUID_[aUUID];
}
- (COBranchInfo *)currentBranchInfo
{
    return [self branchInfoForUUID: self.currentBranchUUID];
}
- (ETUUID *)currentRevisionUUID
{
    return self.currentBranchInfo.currentRevisionUUID;
}

- (NSArray *)branchInfosWithMetadataValue: (id)aValue forKey: (NSString *)aKey
{
    NSMutableArray *result = [NSMutableArray array];
    for (COBranchInfo *info in branchForUUID_.allValues)
    {
        if ([info.metadata[aKey] isEqual: aValue])
        {
            [result addObject: info];
        }
    }
    return result;
}

@end
