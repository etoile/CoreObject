#import "CORevisionID.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation CORevisionID

@synthesize backingStoreUUID = backingStoreUUID_;
@synthesize revisionUUID = revisionUUID_;

+ (CORevisionID *) revisionWithBackinStoreUUID: (ETUUID *)aUUID
                                  revisionUUID: (ETUUID *)revUUID
{
    return [[self alloc] initWithPersistentRootBackingStoreUUID: aUUID
                                                    revisionUUID: revUUID];
}

- (id) initWithPersistentRootBackingStoreUUID: (ETUUID *)aUUID
                                 revisionUUID: (ETUUID *)revUUID
{
    self = [super init];
    if (self != nil)
    {
        backingStoreUUID_ = aUUID;
        revisionUUID_ = revUUID;
    }
    return self;
}


- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass: [CORevisionID class]])
    {
        return [((CORevisionID *)object)->backingStoreUUID_ isEqual: backingStoreUUID_]
            && [((CORevisionID *)object)->revisionUUID_ isEqual: revisionUUID_];
    }
    return NO;
}

- (NSUInteger) hash
{
    return [revisionUUID_ hash];
}

- (CORevisionID *) revisionIDWithRevisionUUID: (ETUUID *)revUUID
{
    return [CORevisionID revisionWithBackinStoreUUID: backingStoreUUID_
                                        revisionUUID: revUUID];
}

- (id) plist
{
    return [NSString stringWithFormat: @"%@:%@", backingStoreUUID_, revisionUUID_];
}

+ (CORevisionID *) revisionIDWithPlist: (id)plist
{
    NSArray *comps = [(NSString *)plist componentsSeparatedByString:@":"];
    
    CORevisionID *result = [[CORevisionID alloc] init];
    
    result->backingStoreUUID_ = [ETUUID UUIDWithString: [comps objectAtIndex: 0]];
    result->revisionUUID_ = [ETUUID UUIDWithString: [comps objectAtIndex: 1]];
    
    return result;
}

- (id) copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)description
{
    return [[self plist] description];
}

@end
