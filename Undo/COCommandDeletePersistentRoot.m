#import "COCommandUndeletePersistentRoot.h"
#import "COCommandDeletePersistentRoot.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

@implementation COCommandDeletePersistentRoot

- (COCommand *) inverse
{
	Class inverseClass = [COCommandUndeletePersistentRoot class];
	BOOL isCreateInverse = (_revisionID != nil);

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
		[(COCommandCreatePersistentRoot *)inverse setRevisionID: _revisionID];
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
