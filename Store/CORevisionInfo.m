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
@synthesize schemaVersion = _schemaVersion;
@synthesize date = _date;

- (BOOL)isEqual: (id)object
{
    if ([object isKindOfClass: [CORevisionInfo class]])
    {
        CORevisionInfo *other = (CORevisionInfo *)object;
        return [_revisionID isEqual: other.revisionUUID];
    }
    return NO;
}

- (NSUInteger)hash
{
    return _revisionID.hash ^ 15497645834521126867ULL;
}

- (NSString *)description
{
    if (_parentRevisionID != nil)
    {
        return [NSString stringWithFormat: @"(Revision %@, Parent %@)",
                                           _revisionID,
                                           _parentRevisionID];
    }
    return [NSString stringWithFormat: @"(Revision %@)", _revisionID];
}

- (id)plist
{
    return @{@"revisionID": [_revisionID stringValue],
             @"parentRevisionID": _parentRevisionID != nil ? [_parentRevisionID stringValue] : [NSNull null],
             @"mergeParentRevisionID": _mergeParentRevisionID != nil ? [_mergeParentRevisionID stringValue] : [NSNull null],
             @"branchUUID": [_branchUUID stringValue],
             @"schemaVersion": @(_schemaVersion),
             @"metadata": _metadata != nil ? _metadata : [NSNull null],
             @"date": [[[NSDateFormatter alloc] init] stringFromDate: _date]};
}

+ (CORevisionInfo *)revisionInfoWithPlist: (NSDictionary *)aPlist
{
    CORevisionInfo *info = [[CORevisionInfo alloc] init];
    info.revisionUUID = [ETUUID UUIDWithString: aPlist[@"revisionID"]];

    if (aPlist[@"parentRevisionID"] != [NSNull null])
    {
        info.parentRevisionUUID = [ETUUID UUIDWithString: aPlist[@"parentRevisionID"]];
    }
    else
    {
        info.parentRevisionUUID = nil;
    }

    if (aPlist[@"mergeParentRevisionID"] != [NSNull null])
    {
        info.mergeParentRevisionUUID = [ETUUID UUIDWithString: aPlist[@"mergeParentRevisionID"]];
    }
    else
    {
        info.mergeParentRevisionUUID = nil;
    }

    info.branchUUID = [ETUUID UUIDWithString: aPlist[@"branchUUID"]];
    info.schemaVersion = ((NSNumber *)aPlist[@"schemaVersion"]).longLongValue;
    info.metadata = (aPlist[@"metadata"] != [NSNull null]) ? aPlist[@"metadata"] : nil;
    info.date = [[[NSDateFormatter alloc] init] dateFromString: aPlist[@"date"]];
    return info;
}

@end
