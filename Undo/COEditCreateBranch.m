#import "COEditCreateBranch.h"
#import <EtoileFoundation/Macros.h>
#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COEditDeleteBranch.h"
#import "CORevision.h"

static NSString * const kCOEditBranchUUID = @"COEditBranchUUID";
static NSString * const kCOEditRevisionID = @"COEditRevisionID";

@implementation COEditCreateBranch

@synthesize branchUUID = _branchUUID;
@synthesize revisionID = _revisionID;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOEditBranchUUID]];
    self.revisionID = [CORevisionID revisionIDWithPlist: [plist objectForKey: kCOEditRevisionID]];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];    
    [result setObject: [_branchUUID stringValue] forKey: kCOEditBranchUUID];
    [result setObject: [_revisionID plist] forKey:kCOEditRevisionID];
    return result;
}

- (COEdit *) inverse
{
    COEditDeleteBranch *inverse = [[[COEditDeleteBranch alloc] init] autorelease];
    
    
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    if (proot == nil)
    {
        return NO;
    }
    
    if ([proot branchForUUID: _branchUUID] != nil)
    {
        return NO;
    }
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    ETAssert(proot != nil);
    
    // FIXME: Need to recreate same branch UUID
    [[proot currentBranch] makeBranchWithLabel: @"FIXME"
                                    atRevision: [CORevision revisionWithStore: [proot store]
                                                                   revisionID: _revisionID]];
}

@end
