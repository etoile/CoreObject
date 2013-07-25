#import "CORevisionID.h"
#import <EtoileFoundation/ETUUID.h>

@implementation CORevisionID

- (id) initWithPersistentRootBackingStoreUUID: (ETUUID *)aUUID
                                revisionIndex: (int64_t)anIndex
{
    self = [super init];
    if (self != nil)
    {
        backingStoreUUID_ = [aUUID retain];
        revisionIndex_ = anIndex;
    }
    return self;
}

+ (CORevisionID *) revisionWithBackinStoreUUID: (ETUUID *)aUUID
                                 revisionIndex: (int64_t)anIndex
{
    return [[[self alloc] initWithPersistentRootBackingStoreUUID: aUUID revisionIndex: anIndex] autorelease];
}

- (void) dealloc
{
    [backingStoreUUID_ release];
    [super dealloc];
}

- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass: [CORevisionID class]])
    {
        return ((CORevisionID *)object)->revisionIndex_ == revisionIndex_
        && [((CORevisionID *)object)->backingStoreUUID_ isEqual: backingStoreUUID_];
    }
    return NO;
}

- (NSUInteger) hash
{
    return revisionIndex_ ^ [backingStoreUUID_ hash];
}
- (ETUUID *) backingStoreUUID
{
    return backingStoreUUID_;
}
- (int64_t) revisionIndex
{
    return revisionIndex_;
}

- (CORevisionID *) revisionIDWithRevisionIndex: (int64_t)anIndex
{
    return [[[CORevisionID alloc] initWithPersistentRootBackingStoreUUID: backingStoreUUID_
                                                           revisionIndex: anIndex] autorelease];
}

- (id) plist
{
    return [NSString stringWithFormat: @"%@:%@", backingStoreUUID_,
            [NSNumber numberWithLongLong: (long long)revisionIndex_]];
}
+ (CORevisionID *) revisionIDWithPlist: (id)plist
{
    NSArray *comps = [(NSString *)plist componentsSeparatedByString:@":"];
    
    CORevisionID *result = [[[CORevisionID alloc] init] autorelease];
    
    result->backingStoreUUID_ = [[ETUUID UUIDWithString: [comps objectAtIndex: 0]] retain];
    result->revisionIndex_ = [(NSString *)[comps objectAtIndex: 1] longLongValue];
    
    return result;
}

- (id) copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"<State Token %@.%lld>", backingStoreUUID_, (long long int)revisionIndex_];
}

@end
