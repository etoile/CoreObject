#import "COCommandSetPersistentRootMetadata.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

static NSString * const kCOCommandOldMetadata = @"COCommandOldMetadata";
static NSString * const kCOCommandNewMetadata = @"COCommandNewMetadata";

@implementation COCommandSetPersistentRootMetadata 

@synthesize oldMetadata = _oldMetadata;
@synthesize metadata = _newMetadata;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    self.oldMetadata = [plist objectForKey: kCOCommandOldMetadata];
    self.metadata = [plist objectForKey: kCOCommandNewMetadata];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    if (_oldMetadata != nil)
    {
        [result setObject: _oldMetadata forKey: kCOCommandOldMetadata];
    }
    if (_newMetadata != nil)
    {
        [result setObject: _newMetadata forKey: kCOCommandNewMetadata];
    }
    return result;
}

- (COCommand *) inverse
{
    COCommandSetPersistentRootMetadata *inverse = [[COCommandSetPersistentRootMetadata alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    
    inverse.oldMetadata = _newMetadata;
    inverse.metadata = _oldMetadata;
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
   	ETAssert(proot != nil);

    [proot setMetadata: _newMetadata];
}

@end
