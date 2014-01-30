/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "COBranchInfo.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COBranchInfo

@synthesize UUID = uuid_;
@synthesize persistentRootUUID = _persistentRootUUID;
@synthesize deleted = deleted_;
@synthesize metadata = metadata_;
@synthesize parentBranchUUID = parentBranchUUID_;

@synthesize headRevisionUUID = _headRevisionUUID;
@synthesize currentRevisionUUID = _currentRevisionUUID;

- (ETUUID *) remoteMirror
{
    NSString *value = metadata_[@"remoteMirror"];
    if (value != nil)
    {
        return [ETUUID UUIDWithString: value];
    }
    return nil;
}

- (ETUUID *) replcatedBranch
{
    NSString *value = metadata_[@"replcatedBranch"];
    if (value != nil)
    {
        return [ETUUID UUIDWithString: value];
    }
    return nil;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<Branch %@ <curr. rev.: %@> %@>", uuid_, _currentRevisionUUID, metadata_];
}

@end
