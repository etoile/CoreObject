/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COCommandUndeletePersistentRoot.h"
#import "COCommandDeletePersistentRoot.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COStoreTransaction.h"

static NSString *const kCOCommandInitialRevisionID = @"COCommandInitialRevisionID";

@implementation COCommandDeletePersistentRoot

@synthesize initialRevisionID = _initialRevisionID;

- (instancetype)initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    if (self == nil)
        return nil;

    id serializedRevID = plist[kCOCommandInitialRevisionID];

    if (serializedRevID != nil)
    {
        _initialRevisionID = [ETUUID UUIDWithString: serializedRevID];
    }
    return self;
}

- (id)propertyList
{
    NSMutableDictionary *result = super.propertyList;

    if (_initialRevisionID != nil)
    {
        result[kCOCommandInitialRevisionID] = [_initialRevisionID stringValue];
    }
    return result;
}

- (COCommand *)inverse
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

    if (isCreateInverse)
    {
        ((COCommandCreatePersistentRoot *)inverse).initialRevisionID = _initialRevisionID;
    }

    return inverse;
}

- (BOOL)canApplyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);
    if (nil == [aContext persistentRootForUUID: _persistentRootUUID])
    {
        return NO;
    }
    return YES;
}

- (void)addToStoreTransaction: (COStoreTransaction *)txn
         withRevisionMetadata: (NSDictionary *)metadata
  assumingEditingContextState: (COEditingContext *)ctx
{
    [txn deletePersistentRoot: _persistentRootUUID];
}

- (void)applyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);
    [[aContext persistentRootForUUID: _persistentRootUUID] setDeleted: YES];
}

- (NSString *)kind
{
    return _(@"Persistent Root Deletion");
}

- (id)copyWithZone: (NSZone *)zone
{
    COCommandDeletePersistentRoot *aCopy = [super copyWithZone: zone];
    aCopy->_initialRevisionID = _initialRevisionID;
    return aCopy;
}

@end
