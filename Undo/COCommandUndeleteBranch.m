#import "COCommandUndeleteBranch.h"
#import "COCommandDeleteBranch.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

static NSString * const kCOCommandBranchUUID = @"COCommandBranchUUID";

@implementation COCommandUndeleteBranch

@synthesize branchUUID = _branchUUID;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandBranchUUID]];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    [result setObject: [_branchUUID stringValue] forKey: kCOCommandBranchUUID];
    return result;
}

- (COCommand *) inverse
{
    COCommandDeleteBranch *inverse = [[[COCommandDeleteBranch alloc] init] autorelease];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    
    inverse.branchUUID = _branchUUID;
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    
    [branch setDeleted: NO];
}

@end
