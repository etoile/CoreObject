/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COCommand.h"

@class CORevision;

NS_ASSUME_NONNULL_BEGIN

@interface COCommandSetCurrentVersionForBranch : COCommand
{
    ETUUID *_branchUUID;
    ETUUID *_oldRevisionUUID;
    ETUUID *_newRevisionUUID;

    ETUUID *_oldHeadRevisionUUID;
    ETUUID *_newHeadRevisionUUID;

    // Non-persistent
    ETUUID *_currentRevisionBeforeSelectiveApply;
}


/** @taskunit Basic Properties */


/**
 * The concerned branch UUID.
 */
@property (nonatomic, readwrite, copy) ETUUID *branchUUID;
@property (nonatomic, readwrite, copy) ETUUID *oldRevisionUUID;
@property (nonatomic, readwrite, copy) ETUUID *revisionUUID;

@property (nonatomic, readwrite, copy) ETUUID *oldHeadRevisionUUID;
@property (nonatomic, readwrite, copy) ETUUID *headRevisionUUID;


@property (nonatomic, readonly) CORevision *oldRevision;
@property (nonatomic, readonly) CORevision *revision;


/** @taskunit Track Node Protocol */


/** 
 * Returns the set revision UUID. 
 */
@property (nonatomic, readonly) ETUUID *UUID;
/**
 * Returns the set revision metadata.
 *
 * See -[CORevision metadata].
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *metadata;
/**
 * Returns the short description for the set revision.
 *
 * See -[CORevision localizedShortDescription].
 */
@property (nonatomic, readonly, nullable) NSString *localizedShortDescription;

@end

NS_ASSUME_NONNULL_END
