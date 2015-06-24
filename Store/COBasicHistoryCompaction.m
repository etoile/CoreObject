/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "COBasicHistoryCompaction.h"

@implementation COBasicHistoryCompaction

@synthesize finalizablePersistentRootUUIDs = _finalizablePersistentRootUUIDs,
	compactablePersistentRootUUIDs = _compactablePersistentRootUUIDs,
	finalizableBranchUUIDs = _finalizableBranchUUIDs,
	compactableBranchUUIDs = _compactableBranchUUIDs;

- (id)init
{
	SUPERINIT;
	_finalizablePersistentRootUUIDs = [NSSet new];
	_compactablePersistentRootUUIDs = [NSSet new];
	_finalizableBranchUUIDs = [NSSet new];
	_compactableBranchUUIDs = [NSSet new];
	return self;
}

- (NSSet *)deadRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs
{
	return [NSSet new];
}

- (NSSet *)liveRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs
{
	return [NSSet new];
}

@end
