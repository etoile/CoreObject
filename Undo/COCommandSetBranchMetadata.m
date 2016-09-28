/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COCommandSetBranchMetadata.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COStoreTransaction.h"

static NSString *const kCOCommandBranchUUID = @"COCommandBranchUUID";
static NSString *const kCOCommandOldMetadata = @"COCommandOldMetadata";
static NSString *const kCOCommandNewMetadata = @"COCommandNewMetadata";

@implementation COCommandSetBranchMetadata

@synthesize branchUUID = _branchUUID;
@synthesize oldMetadata = _oldMetadata;
@synthesize metadata = _newMetadata;

- (instancetype)initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.branchUUID = [ETUUID UUIDWithString: plist[kCOCommandBranchUUID]];
    self.oldMetadata = plist[kCOCommandOldMetadata];
    self.metadata = plist[kCOCommandNewMetadata];
    return self;
}

- (id)propertyList
{
    NSMutableDictionary *result = super.propertyList;
    result[kCOCommandBranchUUID] = [_branchUUID stringValue];
    if (_oldMetadata != nil)
    {
        result[kCOCommandOldMetadata] = _oldMetadata;
    }
    if (_newMetadata != nil)
    {
        result[kCOCommandNewMetadata] = _newMetadata;
    }
    return result;
}

- (COCommand *)inverse
{
    COCommandSetBranchMetadata *inverse = [[COCommandSetBranchMetadata alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;

    inverse.branchUUID = _branchUUID;
    inverse.oldMetadata = _newMetadata;
    inverse.metadata = _oldMetadata;
    return inverse;
}

- (BOOL)canApplyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);
    return YES;
}

- (void)addToStoreTransaction: (COStoreTransaction *)txn
         withRevisionMetadata: (NSDictionary *)metadata
  assumingEditingContextState: (COEditingContext *)ctx
{
    [txn setMetadata: _newMetadata forBranch: _branchUUID ofPersistentRoot: _persistentRootUUID];
}

- (void)applyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    ETAssert(branch != nil);

    branch.metadata = _newMetadata;
}

- (NSString *)kind
{
    return _(@"Branch Metadata Update");
}

- (id)copyWithZone: (NSZone *)zone
{
    COCommandSetBranchMetadata *aCopy = [super copyWithZone: zone];
    aCopy->_branchUUID = _branchUUID;
    aCopy->_oldMetadata = _oldMetadata;
    aCopy->_newMetadata = _newMetadata;
    return aCopy;
}

@end
