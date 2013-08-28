#import "CORevisionInfo.h"
#import "CORevisionID.h"

@implementation CORevisionInfo

@synthesize revisionID = _revisionID;
@synthesize parentRevisionID = _parentRevisionID;
@synthesize metadata = _metadata;
@synthesize date = _date;

- (void) dealloc
{
    [_revisionID release];
    [_parentRevisionID release];
    [_metadata release];
    [_date release];
    [super dealloc];
}

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
              @"metadata" : _metadata != nil ? _metadata : [NSNull null],
              @"date" : [[[[NSDateFormatter alloc] init] autorelease] stringFromDate: _date]  };
}

+ (CORevisionInfo *) revisionInfoWithPlist: (id)aPlist
{
    CORevisionInfo *info = [[[CORevisionInfo alloc] init] autorelease];
    info.revisionID = [CORevisionID revisionIDWithPlist: aPlist[@"revisionID"]];
    info.parentRevisionID = aPlist[@"parentRevisionID"] != [NSNull null] ?
        [CORevisionID revisionIDWithPlist: aPlist[@"parentRevisionID"]] : nil;
    info.metadata = aPlist[@"metadata"] != [NSNull null] ? aPlist[@"metadata"] : nil;
    info.date = [[[[NSDateFormatter alloc] init] autorelease] dateFromString: aPlist[@"date"]];
    return info;
}

@end
