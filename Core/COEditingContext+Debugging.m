/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import "COEditingContext+Debugging.h"
#import "COObjectGraphContext.h"
#import "COPersistentRoot.h"

@implementation COEditingContext (Debugging)

- (NSArray *)loadedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(loadedObjects)];
}

- (NSArray *)loadedRootObjects
{
	NSMutableArray *collectedObjects = [NSMutableArray new];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		for (COObjectGraphContext *objectGraphContext in persistentRoot.allObjectGraphContexts)
		{
			[collectedObjects addObject: objectGraphContext.rootObject];
		}
	}
	return collectedObjects;
}

- (NSArray *)arrayByCollectingObjectsFromPersistentRootsUsingSelector: (SEL)aSelector
{
	NSMutableArray *collectedObjects = [NSMutableArray new];

	for (COPersistentRoot *persistentRoot in [_loadedPersistentRoots objectEnumerator])
	{
		for (COObjectGraphContext *objectGraphContext in persistentRoot.allObjectGraphContexts)
		{
			[collectedObjects addObjectsFromArray: [objectGraphContext performSelector: aSelector]];
		}
	}
	return collectedObjects;
}

- (NSArray *)insertedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(insertedObjects)];
}

- (NSArray *)updatedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(updatedObjects)];
}

- (NSArray *)changedObjects
{
	return [self arrayByCollectingObjectsFromPersistentRootsUsingSelector: @selector(changedObjects)];
}

@end
