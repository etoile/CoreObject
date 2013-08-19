#import "COEditDeleteBranch.h"
#import "COEditCreateBranch.h"
#import <EtoileFoundation/Macros.h>
#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"

@implementation COEditDeleteBranch

- (COEdit *) inverse
{
    COEditCreateBranch *inverse = [[[COEditCreateBranch alloc] init] autorelease];
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

    [branch setDeleted: YES];
}

@end
