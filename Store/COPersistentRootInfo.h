/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

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
    BOOL _deleted;
    int64_t _transactionID;
    NSDictionary *_metadata;
}

@property (nonatomic, readonly) NSSet *branchUUIDs;
@property (nonatomic, readonly) NSArray *branches;

- (COBranchInfo *)branchInfoForUUID: (ETUUID *)aUUID;
@property (nonatomic, readonly, strong) COBranchInfo *currentBranchInfo;
/**
 * Convenience method that returns the current branch's current revision ID
 */
@property (nonatomic, readonly) ETUUID *currentRevisionUUID;

@property (nonatomic, readwrite, copy) ETUUID *UUID;
@property (nonatomic, readwrite, copy) ETUUID *currentBranchUUID;
@property (nonatomic, readwrite, copy) NSDictionary *branchForUUID;
@property (nonatomic, readwrite, getter=isDeleted) BOOL deleted;
@property (nonatomic, readwrite, assign) int64_t transactionID;
@property (nonatomic, readwrite, copy) NSDictionary *metadata;

- (NSArray *)branchInfosWithMetadataValue: (id)aValue forKey: (NSString *)aKey;

@end
