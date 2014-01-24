/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

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

- (id) initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.oldBranchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandOldBranchUUID]];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandNewBranchUUID]];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
    [result setObject: [_oldBranchUUID stringValue] forKey: kCOCommandOldBranchUUID];
    [result setObject: [_newBranchUUID stringValue] forKey: kCOCommandNewBranchUUID];
    return result;
}

- (COCommand *) inverse
{
    COCommandSetCurrentBranch *inverse = [[COCommandSetCurrentBranch alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    
    inverse.oldBranchUUID = _newBranchUUID;
    inverse.branchUUID = _oldBranchUUID;
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _newBranchUUID];
    ETAssert(branch != nil);

    [proot setCurrentBranch: branch];
}

- (NSString *)kind
{
	return _(@"Branch Switch");
}

@end
