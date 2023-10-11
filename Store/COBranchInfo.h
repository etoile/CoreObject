/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETUUID;

NS_ASSUME_NONNULL_BEGIN

@interface COBranchInfo : NSObject
{
@private
    ETUUID *uuid_;
    ETUUID *_persistentRootUUID;
    ETUUID *_headRevisionUUID;
    ETUUID *_currentRevisionUUID;
    NSDictionary *metadata_;
    BOOL deleted_;
    ETUUID *parentBranchUUID_;
}

@property (nonatomic, readwrite, copy) ETUUID *UUID;
@property (nonatomic, readwrite, copy) ETUUID *persistentRootUUID;
/**
 * The newest revision on the branch.
 *
 * Normally the same as currentRevisionID,
 * unless currentRevisionID is reverted to an older revision.
 * Upon making a commit from that state, headRevisionID would be reset to
 * equal currentRevisionID.
 *
 * The only benefit for having this is so the user can undo reverting to an
 * old revision without using the real, application-level undo command.
 * i.e. they would open the history inspector, and explicitly
 * reset the current revision to the head. If we don't care about that feature,
 * we can drop this property and require users to undo bad "revert to old revision"
 * by pressing Cmd+Z.
 *
 * It's worth noting that if they revert to an old revision and commit a change,
 * the only way to undo that is with application-level undo anyway. So this
 * property really only does anything in a very tiny use case (reverted to old
 * revision, haven't yet made a change) which suggests it should probably be
 * removed.
 */
@property (nonatomic, readwrite, copy) ETUUID *headRevisionUUID;
/**
 * The current revision of this branch.
 */
@property (nonatomic, readwrite, copy) ETUUID *currentRevisionUUID;
/**
 * Metadata, like the user-facing name of the branch.
 * Note that branches have metadata while persistent roots do not. Persistent
 * root metadata should be stored in the inner objects as versioned data.
 * (If there is a real use case for unversioned persistent root metadata,
 *  we can easily re-add it)
 */
@property (nonatomic, readwrite, copy, nullable) NSDictionary<NSString *, id> *metadata;
@property (nonatomic, readwrite, getter=isDeleted) BOOL deleted;
@property (nonatomic, readwrite, copy, nullable) ETUUID *parentBranchUUID;
/**
 * In git terminology, if the receiver is "master", returns "origin/master", or
 * nil if there is no corresponding "origin/master"
 */
@property (nonatomic, readonly, nullable) ETUUID *remoteMirror;
/**
 * In git terminology, if the receiver is "origin/master", returns the UUID
 * of the "master" branch in the remote store "origin". Otherwise, returns nil.
 */
@property (nonatomic, readonly, nullable) ETUUID *replicatedBranch;

@end

NS_ASSUME_NONNULL_END
