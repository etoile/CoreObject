/*
	Copyright (C) 2015 Quentin Mathe

	Date:  July 2015
	License:  MIT  (see COPYING)
 */

#import "COCrossPersistentRootDeadRelationshipCache.h"
#import "COPath.h"
#import "COPersistentRoot.h"

//#define MISSING_ZEROING_WEAK_REF

@implementation COCrossPersistentRootDeadRelationshipCache

- (id)init
{
	SUPERINIT;
	_pathToReferringObjects = [NSMutableDictionary new];
#if TARGET_OS_IPHONE
	_referringObjectToPaths = [NSMapTable weakToStrongObjectsMapTable];
#else
	_referringObjectToPaths = [NSMapTable mapTableWithWeakToStrongObjects];
#endif
	return self;
}

- (void)addReferringObject: (COObject *)aReferrer
                   forPath: (COPath *)aPath
{
	NSHashTable *referringObjects = _pathToReferringObjects[aPath];
	NSMutableSet *paths = [_referringObjectToPaths objectForKey: aReferrer];

	if (referringObjects == nil)
	{
		// FIXME: If we don't ditch 10.7 support, we need a reverse mapping
		// from each referringObject to a path set, that can be used to remove
		// the referring objects when their object graph context is discarded.
#if TARGET_OS_IPHONE
		referringObjects = [NSHashTable weakObjectsHashTable];
#else
		referringObjects = [NSHashTable hashTableWithWeakObjects];
#endif
 
		_pathToReferringObjects[aPath] = referringObjects;
	}
	if (paths == nil)
	{
		paths = [NSMutableSet new];
		[_referringObjectToPaths setObject: paths
		                            forKey: aReferrer];
	}
	[paths addObject: aPath];
	[referringObjects addObject: aReferrer];
}

- (NSHashTable *)referringObjectsForPath: (COPath *)aPath
{
	return _pathToReferringObjects[aPath];
}

- (void)removeReferringObject: (COObject *)aReferrer
                      forPath: (COPath *)aPath
{
	NSMutableSet *paths = [_referringObjectToPaths objectForKey: aReferrer];

	[paths removeObject: aPath];
	[_pathToReferringObjects[aPath] removeObject: aReferrer];
}

- (void)removeReferringObject: (COObject *)aReferrer
{
	NSMutableSet *paths = [_referringObjectToPaths objectForKey: aReferrer];
	
	if (paths == nil)
		return;

	[_referringObjectToPaths removeObjectForKey: aReferrer];
	[_pathToReferringObjects removeObjectsForKeys: paths.allObjects];
}

- (void)removePath: (COPath *)aPath
{
	NSHashTable *referringObjects = _pathToReferringObjects[aPath];

	for (COObject *referrer in referringObjects)
	{
		[_referringObjectToPaths removeObjectForKey: referrer];
	}
	[_pathToReferringObjects removeObjectForKey: aPath];
}

@end
