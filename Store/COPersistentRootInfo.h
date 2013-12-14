/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
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

- (NSSet *) branchUUIDs;
- (NSArray *) branches;

- (COBranchInfo *)branchInfoForUUID: (ETUUID *)aUUID;
- (COBranchInfo *)currentBranchInfo;
/**
 * Convenience method that returns the current branch's current revision ID
 */
- (ETUUID *)currentRevisionUUID;

@property (readwrite, nonatomic, strong) ETUUID *UUID;
@property (readwrite, nonatomic, strong) ETUUID *currentBranchUUID;
@property (readwrite, nonatomic, strong) NSDictionary *branchForUUID;
@property (readwrite, nonatomic, getter=isDeleted, setter=setDeleted:) BOOL deleted;
@property (readwrite, nonatomic, assign) int64_t transactionID;
@property (readwrite, nonatomic, strong) NSDictionary *metadata;

- (NSArray *)branchInfosWithMetadataValue: (id)aValue forKey: (NSString *)aKey;

@end