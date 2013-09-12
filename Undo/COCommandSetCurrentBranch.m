#import "COCommandSetCurrentBranch.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

#import <EtoileFoundation/Macros.h>

static NSString * const kCOCommandOldBranchUUID = @"COCommandOldBranchUUID";
static NSString * const kCOCommandNewBranchUUID = @"COCommandNewBranchUUID";

@implementation COCommandSetCurrentBranch

@synthesize oldBranchUUID = _oldBranchUUID;
@synthesize branchUUID = _newBranchUUID;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.oldBranchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandOldBranchUUID]];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandNewBranchUUID]];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    [result setObject: [_oldBranchUUID stringValue] forKey: kCOCommandOldBranchUUID];
    [result setObject: [_newBranchUUID stringValue] forKey: kCOCommandNewBranchUUID];
    return result;
}

- (COCommand *) inverse
{
    COCommandSetCurrentBranch *inverse = [[COCommandSetCurrentBranch alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    
    inverse.oldBranchUUID = _newBranchUUID;
    inverse.branchUUID = _oldBranchUUID;
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _newBranchUUID];
    
    [proot setCurrentBranch: branch];
}

@end
