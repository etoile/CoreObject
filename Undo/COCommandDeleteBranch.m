/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COCommandUndeleteBranch.h"
#import "COCommandDeleteBranch.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COStoreTransaction.h"

static NSString * const kCOCommandBranchUUID = @"COCommandBranchUUID";

@implementation COCommandDeleteBranch

@synthesize branchUUID = _branchUUID;

- (instancetype) initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.branchUUID = [ETUUID UUIDWithString: plist[kCOCommandBranchUUID]];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = super.propertyList;
    result[kCOCommandBranchUUID] = [_branchUUID stringValue];
    return result;
}

- (COCommand *) inverse
{
    COCommandUndeleteBranch *inverse = [[COCommandUndeleteBranch alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;

    inverse.branchUUID = _branchUUID;
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);
    return YES;
}

- (void) addToStoreTransaction: (COStoreTransaction *)txn withRevisionMetadata: (NSDictionary *)metadata assumingEditingContextState: (COEditingContext *)ctx
{
    [txn deleteBranch: _branchUUID ofPersistentRoot: _persistentRootUUID];
}

- (void) applyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _branchUUID];
    ETAssert(branch != nil);

    [branch setDeleted: YES];
}

- (NSString *)kind
{
    return _(@"Branch Deletion");
}

- (id) copyWithZone:(NSZone *)zone
{
    COCommandDeleteBranch *aCopy = [super copyWithZone: zone];
    aCopy->_branchUUID = _branchUUID;
    return aCopy;
}

@end
