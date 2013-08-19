#import "COEditCreateBranch.h"
#import <EtoileFoundation/Macros.h>
#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COEditDeleteBranch.h"
#import "CORevision.h"

static NSString * const kCOEditBranchUUID = @"COEditBranchUUID";
static NSString * const kCOEditRevisionID = @"COEditRevisionID";
static NSString * const kCOEditBranchMetadata = @"COEditBranchMetadata";

@implementation COEditCreateBranch

@synthesize branchUUID = _branchUUID;
@synthesize revisionID = _revisionID;
@synthesize metadata = _metadata;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOEditBranchUUID]];
    self.revisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOEditRevisionID]];
    self.metadata = [plist objectForKey: kCOEditBranchMetadata];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];    
    [result setObject: [_branchUUID stringValue] forKey: kCOEditBranchUUID];
    [result setObject: [_revisionID plist] forKey:kCOEditRevisionID];
    [result setObject: self.metadata forKey: kCOEditBranchMetadata];
    return result;
}

- (COEdit *) inverse
{
    COEditDeleteBranch *inverse = [[[COEditDeleteBranch alloc] init] autorelease];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    inverse.displayName = _displayName;
    
    inverse.branchUUID = _branchUUID;
    inverse.revisionID = _revisionID;
    inverse.metadata = _metadata;
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
    
    if ([branch isDeleted])
    {
        [branch setDeleted: NO];
    }
    else
    {
        [proot makeBranchWithUUID: _branchUUID
                         metadata: _metadata
                       atRevision: [CORevision revisionWithStore: [proot store]
                                                      revisionID: _revisionID]];
    }
}

@end
