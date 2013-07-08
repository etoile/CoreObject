#import "CORevisionInfo.h"
#import <EtoileFoundation/Macros.h>

@implementation CORevisionInfo

NSString *kCORevisionID = @"CORevisionID";
NSString *kCORevisionParentID = @"CORevisionParentID";
NSString *kCORevisionMetadata = @"CORevisionMetadata";

- (id) initWithRevisionID: (CORevisionID *)revisionId
         parentRevisionID: (CORevisionID *)parentRevisionId
                 metadata: (NSDictionary *)metadata
{
    NSParameterAssert(revisionId != nil);
    
    SUPERINIT;
    ASSIGN(revisionID_, revisionId);
    ASSIGN(parentRevisionID_, parentRevisionId);
    ASSIGN(metadata_, metadata);
    return self;
}

- (void) dealloc
{
    [revisionID_ release];
    [parentRevisionID_ release];
    [metadata_ release];
    [super dealloc];
}

- (CORevisionID *)revisionID
{
    return revisionID_;
}
- (CORevisionID *)parentRevisionID
{
    return parentRevisionID_;
}
- (NSDictionary *)metadata
{
    return metadata_;
}

- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass: [CORevisionInfo class]])
    {
        return [((CORevisionInfo *)object)->revisionID_ isEqual: revisionID_]
            && [((CORevisionInfo *)object)->parentRevisionID_ isEqual: parentRevisionID_];
    }
    return NO;
}

- (NSUInteger) hash
{
    return [revisionID_ hash] ^ 15497645834521126867ULL;
}

- (id) plist
{
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject: [revisionID_ plist] forKey: kCORevisionID];
    if (parentRevisionID_ != nil)
    {
        [d setObject: [parentRevisionID_ plist] forKey: kCORevisionParentID];
    }
    if (metadata_ != nil)
    {
        [d setObject: metadata_ forKey: kCORevisionMetadata];
    }
    return d;
}
+ (CORevisionInfo *) revisionWithPlist: (id)plist
{
    return [[[self alloc] initWithRevisionID: [plist objectForKey:kCORevisionID]
                            parentRevisionID: [plist objectForKey: kCORevisionParentID]
                                    metadata: [plist objectForKey: kCORevisionMetadata]] autorelease];
}

- (id) copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSString *)description
{
    if (parentRevisionID_ != nil)
    {
        return [NSString stringWithFormat: @"(Revision %@, Parent %@)", revisionID_, parentRevisionID_];
    }
    return [NSString stringWithFormat: @"(Revision %@)", revisionID_];
}


@end
