#import "COEditSetCurrentBranch.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

#import <EtoileFoundation/Macros.h>

static NSString * const kCOEditOldBranchUUID = @"COEditOldBranchUUID";
static NSString * const kCOEditNewBranchUUID = @"COEditNewBranchUUID";

@implementation COEditSetCurrentBranch

@synthesize oldBranchUUID = _oldBranchUUID;
@synthesize branchUUID = _newBranchUUID;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.oldBranchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOEditOldBranchUUID]];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOEditNewBranchUUID]];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    [result setObject: [_oldBranchUUID stringValue] forKey: kCOEditOldBranchUUID];
    [result setObject: [_newBranchUUID stringValue] forKey: kCOEditNewBranchUUID];
    return result;
}

- (COEdit *) inverse
{
    COEditSetCurrentBranch *inverse = [[[COEditSetCurrentBranch alloc] init] autorelease];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    inverse.displayName = _displayName;
    
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
