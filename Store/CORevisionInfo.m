/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "CORevisionInfo.h"

@implementation CORevisionInfo

@synthesize revisionUUID = _revisionID;
@synthesize parentRevisionUUID = _parentRevisionID;
@synthesize mergeParentRevisionUUID = _mergeParentRevisionID;
@synthesize persistentRootUUID = _persistentRootUUID;
@synthesize branchUUID = _branchUUID;
@synthesize metadata = _metadata;
@synthesize date = _date;

- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass: [CORevisionInfo class]])
    {
        CORevisionInfo *other = (CORevisionInfo *)object;
        return [_revisionID isEqual: other.revisionUUID];
    }
    return NO;
}

- (NSUInteger) hash
{
    return _revisionID.hash ^ 15497645834521126867ULL;
}

- (NSString *)description
{
    if (_parentRevisionID != nil)
    {
        return [NSString stringWithFormat: @"(Revision %@, Parent %@)", _revisionID, _parentRevisionID];
    }
    return [NSString stringWithFormat: @"(Revision %@)", _revisionID];
}

- (id) plist
{
    return @{ @"revisionID" : [_revisionID stringValue],
              @"parentRevisionID" : _parentRevisionID != nil ? [_parentRevisionID stringValue] : [NSNull null],
              @"mergeParentRevisionID" : _mergeParentRevisionID != nil ? [_mergeParentRevisionID stringValue] : [NSNull null],
              @"branchUUID" : [_branchUUID stringValue],
              @"metadata" : _metadata != nil ? _metadata : [NSNull null],
              @"date" : [[[NSDateFormatter alloc] init] stringFromDate: _date]  };
}

+ (CORevisionInfo *) revisionInfoWithPlist: (NSDictionary *)aPlist
{
    CORevisionInfo *info = [[CORevisionInfo alloc] init];
    info.revisionUUID = [ETUUID UUIDWithString: aPlist[@"revisionID"]];
    info.parentRevisionUUID = aPlist[@"parentRevisionID"] != [NSNull null] ?
        [ETUUID UUIDWithString: aPlist[@"parentRevisionID"]] : nil;
    info.mergeParentRevisionUUID = aPlist[@"mergeParentRevisionID"] != [NSNull null] ?
        [ETUUID UUIDWithString: aPlist[@"mergeParentRevisionID"]] : nil;
    info.branchUUID = [ETUUID UUIDWithString: aPlist[@"branchUUID"]];
    info.metadata = aPlist[@"metadata"] != [NSNull null] ? aPlist[@"metadata"] : nil;
    info.date = [[[NSDateFormatter alloc] init] dateFromString: aPlist[@"date"]];
    return info;
}

@end
