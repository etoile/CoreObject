/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETUUID, COBranchInfo;

NS_ASSUME_NONNULL_BEGIN

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
    NSMutableDictionary<ETUUID *, COBranchInfo *> *branchForUUID_;
    BOOL _deleted;
    int64_t _transactionID;
    NSDictionary<NSString *, id> *_metadata;
}

@property (nonatomic, readonly) NSSet<ETUUID *> *branchUUIDs;
@property (nonatomic, readonly) NSArray<COBranchInfo *> *branches;

- (nullable COBranchInfo *)branchInfoForUUID: (ETUUID *)aUUID;

@property (nonatomic, readonly, strong) COBranchInfo *currentBranchInfo;
/**
 * Convenience method that returns the current branch's current revision ID
 */
@property (nonatomic, readonly) ETUUID *currentRevisionUUID;
@property (nonatomic, readwrite, copy) ETUUID *UUID;
@property (nonatomic, readwrite, copy) ETUUID *currentBranchUUID;
@property (nonatomic, readwrite, copy) NSDictionary<ETUUID *, COBranchInfo *> *branchForUUID;
@property (nonatomic, readwrite, getter=isDeleted) BOOL deleted;
@property (nonatomic, readwrite, assign) int64_t transactionID;
@property (nonatomic, readwrite, copy, nullable) NSDictionary<NSString *, id> *metadata;

- (NSArray<COBranchInfo *> *)branchInfosWithMetadataValue: (id)aValue forKey: (NSString *)aKey;

@end

NS_ASSUME_NONNULL_END
