#import "CORevisionInfo.h"
#import "CORevisionID.h"

@implementation CORevisionInfo

@synthesize revisionID = _revisionID;
@synthesize parentRevisionID = _parentRevisionID;
@synthesize mergeParentRevisionID = _mergeParentRevisionID;
@synthesize persistentRootUUID = _persistentRootUUID;
@synthesize branchUUID = _branchUUID;
@synthesize metadata = _metadata;
@synthesize date = _date;


- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass: [CORevisionInfo class]])
    {
        CORevisionInfo *other = (CORevisionInfo *)object;
        return [_revisionID isEqual: [other revisionID]];
    }
    return NO;
}

- (NSUInteger) hash
{
    return [_revisionID hash] ^ 15497645834521126867ULL;
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
    return @{ @"revisionID" : [_revisionID plist],
              @"parentRevisionID" : _parentRevisionID != nil ? [_parentRevisionID plist] : [NSNull null],
              @"mergeParentRevisionID" : _mergeParentRevisionID != nil ? [_mergeParentRevisionID plist] : [NSNull null],
			  @"branchUUID" : [_branchUUID stringValue],
              @"metadata" : _metadata != nil ? _metadata : [NSNull null],
              @"date" : [[[NSDateFormatter alloc] init] stringFromDate: _date]  };
}

+ (CORevisionInfo *) revisionInfoWithPlist: (NSDictionary *)aPlist
{
    CORevisionInfo *info = [[CORevisionInfo alloc] init];
    info.revisionID = [CORevisionID revisionIDWithPlist: aPlist[@"revisionID"]];
    info.parentRevisionID = aPlist[@"parentRevisionID"] != [NSNull null] ?
        [CORevisionID revisionIDWithPlist: aPlist[@"parentRevisionID"]] : nil;
    info.mergeParentRevisionID = aPlist[@"mergeParentRevisionID"] != [NSNull null] ?
        [CORevisionID revisionIDWithPlist: aPlist[@"mergeParentRevisionID"]] : nil;
	info.branchUUID = [ETUUID UUIDWithString: aPlist[@"branchUUID"]],
    info.metadata = aPlist[@"metadata"] != [NSNull null] ? aPlist[@"metadata"] : nil;
    info.date = [[[NSDateFormatter alloc] init] dateFromString: aPlist[@"date"]];
    return info;
}

@end
