/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

/**
 *  Info about a commit. Parent revision (maybe nil), metadata, etc.
 *  There's a 1:1 mapping between a CORevisionID and CORevision per store.
 */
@interface CORevisionInfo : NSObject
{
@private
    ETUUID *_revisionID;
    ETUUID *_parentRevisionID;
    ETUUID *_mergeParentRevisionID;
    ETUUID *_persistentRootUUID;
    ETUUID *_branchUUID;
    NSDictionary *_metadata;
    NSDate *_date;
}

@property (nonatomic, readwrite, copy) ETUUID *revisionUUID;
@property (nonatomic, readwrite, copy) ETUUID *parentRevisionUUID;
@property (nonatomic, readwrite, copy) ETUUID *mergeParentRevisionUUID;
@property (nonatomic, readwrite, copy) ETUUID *persistentRootUUID;
@property (nonatomic, readwrite, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) NSDictionary *metadata;
@property (nonatomic, readwrite, copy) NSDate *date;
@property (nonatomic, readonly, strong) id plist;

+ (CORevisionInfo *)revisionInfoWithPlist: (id)aPlist;

@end
