/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import "COCommandSetPersistentRootMetadata.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COStoreTransaction.h"

static NSString * const kCOCommandOldMetadata = @"COCommandOldMetadata";
static NSString * const kCOCommandNewMetadata = @"COCommandNewMetadata";

@implementation COCommandSetPersistentRootMetadata 

@synthesize oldMetadata = _oldMetadata;
@synthesize metadata = _newMetadata;

- (id) initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.oldMetadata = [plist objectForKey: kCOCommandOldMetadata];
    self.metadata = [plist objectForKey: kCOCommandNewMetadata];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
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

- (void) addToStoreTransaction: (COStoreTransaction *)txn isUndo: (BOOL)isUndo assumingEditingContextState: (COEditingContext *)ctx
{
	[txn setMetadata: _newMetadata forPersistentRoot: _persistentRootUUID];
}

- (NSString *)kind
{
	return _(@"Persistent Root Metadata Update");
}

@end
