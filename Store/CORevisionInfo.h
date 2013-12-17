/*
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

@property (readwrite, nonatomic, strong) ETUUID *revisionUUID;
@property (readwrite, nonatomic, strong) ETUUID *parentRevisionUUID;
@property (readwrite, nonatomic, strong) ETUUID *mergeParentRevisionUUID;

@property (readwrite, nonatomic, strong) ETUUID *persistentRootUUID;
@property (readwrite, nonatomic, strong) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) NSDictionary *metadata;
@property (readwrite, nonatomic, strong) NSDate *date;

- (id) plist;
+ (CORevisionInfo *) revisionInfoWithPlist: (id)aPlist;

@end
