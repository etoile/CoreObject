#import "COCommandUndeleteBranch.h"
#import "COCommandDeleteBranch.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

static NSString * const kCOCommandBranchUUID = @"COCommandBranchUUID";

@implementation COCommandDeleteBranch

@synthesize branchUUID = _branchUUID;

- (id) initWithPropertyList: (id)plist
{
    self = [super initWithPropertyList: plist];
    self.branchUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandBranchUUID]];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
    [result setObject: [_branchUUID stringValue] forKey: kCOCommandBranchUUID];
    return result;
}

- (COCommand *) inverse
{
    COCommandUndeleteBranch *inverse = [[COCommandUndeleteBranch alloc] init];
	inverse.UUID = [ETUUID new];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;

    inverse.branchUUID = _branchUUID;
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
    COBranch *branch = [proot branchForUUID: _branchUUID];
	ETAssert(branch != nil);

    [branch setDeleted: YES];
}

- (NSString *)kind
{
	return _(@"Branch Deletion");
}

@end
