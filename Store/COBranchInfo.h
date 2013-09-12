#import <Foundation/Foundation.h>

@class ETUUID, CORevisionID;

@interface COBranchInfo : NSObject
{
@private
    ETUUID *uuid_;
    CORevisionID *tailRevisionId_;
    CORevisionID *currentRevisionId_;
    NSDictionary *metadata_;
    BOOL deleted_;
}

@property (readwrite, nonatomic, strong) ETUUID *UUID;

/**
 * The oldest revision on the branch. Indicates "where a feature branch was
 * forked from master"
 */
@property (readwrite, nonatomic, strong) CORevisionID *tailRevisionID;
/**
 * The current revision of this branch.
 */
@property (readwrite, nonatomic, strong) CORevisionID *currentRevisionID;
/**
 * Metadata, like the user-facing name of the branch.
 * Note that branches have metadata while persistent roots do not. Persistent
 * root metadata should be stored in the embedded objects as versioned data.
 * (If there is a real use case for unversioned persistent root metadata,
 *  we can easily re-add it)
 */
@property (readwrite, nonatomic, strong) NSDictionary *metadata;
@property (readwrite, nonatomic, getter=isDeleted, setter=setDeleted:) BOOL deleted;

/**
 * In git terminology, if the receiver is "master", returns "origin/master", or
 * nil if there is no corresponding "origin/master"
 */
- (ETUUID *) remoteMirror;

/**
 * In git terminology, if the receiver is "origin/master", returns the UUID
 * of the "master" branch in the remote store "origin". Otherwise, returns nil.
 */
- (ETUUID *) replcatedBranch;

@end