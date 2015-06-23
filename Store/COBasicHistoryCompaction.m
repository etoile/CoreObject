/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "COBasicHistoryCompaction.h"

@implementation COBasicHistoryCompaction

@synthesize finalizablePersistentRootUUIDs = _finalizablePersistentRootUUIDs,
	compactablePersistentRootUUIDs = _compactablePersistentRootUUIDs;

- (NSSet *)deadRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs
{
	return [NSSet new];
}

- (NSSet *)liveRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs
{
	return [NSSet new];
}

@end
