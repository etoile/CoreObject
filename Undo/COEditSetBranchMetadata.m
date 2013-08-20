#import "COEditSetBranchMetadata.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

static NSString * const kCOEditBranchUUID = @"COEditBranchUUID";
static NSString * const kCOEditOldMetadata = @"COEditOldMetadata";
static NSString * const kCOEditNewMetadata = @"COEditNewMetadata";

@implementation COEditSetBranchMetadata 

@synthesize branchUUID = _branchUUID;
@synthesize oldMetadata = _oldMetadata;
@synthesize newMetadata = _newMetadata;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOEditBranchUUID]];
    self.oldMetadata = [plist objectForKey: kCOEditOldMetadata];
    self.newMetadata = [plist objectForKey: kCOEditNewMetadata];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    [result setObject: [_branchUUID stringValue] forKey: kCOEditBranchUUID];
    if (_oldMetadata != nil)
    {
        [result setObject: _oldMetadata forKey: kCOEditOldMetadata];
    }
    if (_newMetadata != nil)
    {
        [result setObject: _newMetadata forKey: kCOEditNewMetadata];
    }
    return result;
}

- (COEdit *) inverse
{
    COEditSetBranchMetadata *inverse = [[[COEditSetBranchMetadata alloc] init] autorelease];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    inverse.displayName = _displayName;
    
    inverse.branchUUID = _branchUUID;
    inverse.oldMetadata = _newMetadata;
    inverse.newMetadata = _oldMetadata;
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
    
    [branch setMetadata: _newMetadata];
}

@end
