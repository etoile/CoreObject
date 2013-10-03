#import "COCommandUndeletePersistentRoot.h"
#import "COCommandDeletePersistentRoot.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevisionID.h"

static NSString * const kCOCommandInitialRevisionID = @"COCommandInitialRevisionID";

@implementation COCommandDeletePersistentRoot

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
	if (self == nil)
		return nil;

	id serializedRevID = [plist objectForKey: kCOCommandInitialRevisionID];

	if (serializedRevID != nil)
	{
   		_initialRevisionID = [CORevisionID revisionIDWithPlist: serializedRevID];
	}
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];

	if (_initialRevisionID != nil)
	{
    	[result setObject: [_initialRevisionID plist] forKey: kCOCommandInitialRevisionID];
	}
    return result;
}

- (COCommand *) inverse
{
	Class inverseClass = [COCommandUndeletePersistentRoot class];
	BOOL isCreateInverse = (_initialRevisionID != nil);

	if (isCreateInverse)
	{
		inverseClass = [COCommandCreatePersistentRoot class];
	}

    COCommandUndeletePersistentRoot *inverse = [[inverseClass alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
	if (isCreateInverse)
	{
		[(COCommandCreatePersistentRoot *)inverse setInitialRevisionID: _initialRevisionID];
	}

    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    if (nil == [aContext persistentRootForUUID: _persistentRootUUID])
    {
        return NO;
    }
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
    [[aContext persistentRootForUUID: _persistentRootUUID] setDeleted: YES];
}

@end
