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

- (instancetype) initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.oldMetadata = plist[kCOCommandOldMetadata];
    self.metadata = plist[kCOCommandNewMetadata];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = super.propertyList;
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

- (void) addToStoreTransaction: (COStoreTransaction *)txn withRevisionMetadata: (NSDictionary *)metadata assumingEditingContextState: (COEditingContext *)ctx
{
	[txn setMetadata: _newMetadata forPersistentRoot: _persistentRootUUID];
}

- (void) applyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
	
    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
   	ETAssert(proot != nil);
	
    proot.metadata = _newMetadata;
}

- (NSString *)kind
{
	return _(@"Persistent Root Metadata Update");
}

- (id) copyWithZone:(NSZone *)zone
{
    COCommandSetPersistentRootMetadata *aCopy = [super copyWithZone: zone];
	aCopy->_oldMetadata = _oldMetadata;
	aCopy->_newMetadata = _newMetadata;
    return aCopy;
}

@end
