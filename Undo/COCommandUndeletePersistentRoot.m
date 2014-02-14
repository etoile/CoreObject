/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import "COCommandUndeletePersistentRoot.h"
#import "COCommandDeletePersistentRoot.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"
#import "CORevisionCache.h"
#import "COUndoTrack.h"
#import "COEditingContext+Private.h"
#import "COStoreTransaction.h"

@implementation COCommandUndeletePersistentRoot

- (COCommand *) inverse
{
    COCommandDeletePersistentRoot *inverse = [[COCommandDeletePersistentRoot alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
    if (nil == [aContext persistentRootForUUID: _persistentRootUUID])
    {
        return NO;
    }
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
    [[aContext persistentRootForUUID: _persistentRootUUID] setDeleted: NO];
}

- (void) addToStoreTransaction: (COStoreTransaction *)txn assumingEditingContextState: (COEditingContext *)ctx
{
	[txn undeletePersistentRoot: _persistentRootUUID];
}

- (NSString *)kind
{
	return _(@"Persistent Root Undeletion");
}

@end


static NSString * const kCOCommandInitialRevisionID = @"COCommandInitialRevisionID";

@implementation COCommandCreatePersistentRoot

@synthesize initialRevisionID = _initialRevisionID;

- (id) initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
	if (self == nil)
		return nil;

   	_initialRevisionID = [ETUUID UUIDWithString: plist[kCOCommandInitialRevisionID]];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
    [result setObject: [_initialRevisionID stringValue] forKey: kCOCommandInitialRevisionID];
    return result;
}

- (COCommand *) inverse
{
    COCommandDeletePersistentRoot *inverse = (id)[super inverse];
	inverse.initialRevisionID = _initialRevisionID;
    return inverse;
}

- (NSString *)kind
{
	return _(@"Persistent Root Creation");
}

- (CORevision *)revision
{
	return [_parentUndoTrack.editingContext revisionForRevisionUUID: _initialRevisionID
												 persistentRootUUID: _persistentRootUUID];
}

#pragma mark -
#pragma mark Track Node Protocol

- (NSDictionary *)metadata
{
	return [[self revision] metadata];
}

- (NSDate *)date
{
	return [[self revision] date];
}

- (NSString *)localizedShortDescription
{
	return [[self revision] localizedShortDescription];
}

@end
