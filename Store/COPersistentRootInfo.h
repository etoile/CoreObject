#import <Foundation/Foundation.h>

@class ETUUID, COBranchInfo;

/**
 * Simple data structure returned by -[COSQLiteStore persistentRootInfoForUUID:]
 * to describe the entire state of a persistent root. It is a lightweight object
 * that mainly stores the list of branches and the revision ID of each branch.
 */
@interface COPersistentRootInfo : NSObject
{
@private
    ETUUID *uuid_;
    ETUUID *currentBranch_;
    NSMutableDictionary *branchForUUID_; // COUUID : COBranchInfo
    int64_t _changeCount;
    BOOL _deleted;
}

- (NSSet *) branchUUIDs;

- (COBranchInfo *)branchInfoForUUID: (ETUUID *)aUUID;
- (COBranchInfo *)currentBranchInfo;

@property (readwrite, nonatomic, retain) ETUUID *UUID;
@property (readwrite, nonatomic, retain) ETUUID *currentBranchUUID;
@property (readwrite, nonatomic, retain) NSDictionary *branchForUUID;
@property (readwrite, nonatomic, assign) int64_t changeCount;
@property (readwrite, nonatomic, getter=isDeleted, setter=setDeleted:) BOOL deleted;

@end