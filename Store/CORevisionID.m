#import "CORevisionID.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation CORevisionID

@synthesize revisionPersistentRootUUID;
@synthesize revisionUUID;

+ (CORevisionID *) revisionWithPersistentRootUUID: (ETUUID *)aUUID
                                  revisionUUID: (ETUUID *)revUUID
{
    return [[self alloc] initWithPersistentRootUUID: aUUID
                                                    revisionUUID: revUUID];
}

- (id) initWithPersistentRootUUID: (ETUUID *)aUUID
                                 revisionUUID: (ETUUID *)revUUID
{
    self = [super init];
    if (self != nil)
    {
        revisionPersistentRootUUID = aUUID;
        revisionUUID = revUUID;
    }
    return self;
}


- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass: [CORevisionID class]])
    {
        return [((CORevisionID *)object)->revisionUUID isEqual: revisionUUID];
    }
    return NO;
}

- (NSUInteger) hash
{
    return [revisionUUID hash];
}

- (CORevisionID *) revisionIDWithRevisionUUID: (ETUUID *)revUUID
{
    return [CORevisionID revisionWithPersistentRootUUID: revisionPersistentRootUUID
                                        revisionUUID: revUUID];
}

- (id) plist
{
    return [NSString stringWithFormat: @"%@:%@", revisionPersistentRootUUID, revisionUUID];
}

+ (CORevisionID *) revisionIDWithPlist: (id)plist
{
	NILARG_EXCEPTION_TEST(plist);

    NSArray *comps = [(NSString *)plist componentsSeparatedByString:@":"];
    
    CORevisionID *result = [[CORevisionID alloc] init];
    
    result->revisionPersistentRootUUID = [ETUUID UUIDWithString: [comps objectAtIndex: 0]];
    result->revisionUUID = [ETUUID UUIDWithString: [comps objectAtIndex: 1]];
    
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
