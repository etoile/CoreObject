/*
    Copyright (C) 2015 Quentin Mathe

    Date:  May 2015
    License:  MIT  (see COPYING)
 */

#import "COCrossPersistentRootDeadRelationshipCache.h"
#import "COPath.h"
#import "COPersistentRoot.h"

//#define MISSING_ZEROING_WEAK_REF

@implementation COCrossPersistentRootDeadRelationshipCache

- (instancetype)init
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

- (void)removeObjectFromPathsToReferringObjects: (COObject *)aReferrer forPath: (COPath *)path
{
    NSHashTable *referringObjects = _pathToReferringObjects[path];
        
    [referringObjects removeObject: aReferrer];

    if (referringObjects.count == 0)
    {
        [_pathToReferringObjects removeObjectForKey: path];
    }
}

- (void)removeReferringObject: (COObject *)aReferrer
                      forPath: (COPath *)aPath
{
    NSMutableSet *paths = [_referringObjectToPaths objectForKey: aReferrer];

    [paths removeObject: aPath];
    [self removeObjectFromPathsToReferringObjects: aReferrer
                                          forPath: aPath];
}

- (void)removeReferringObject: (COObject *)aReferrer
{
    NSMutableSet *paths = [_referringObjectToPaths objectForKey: aReferrer];

    if (paths == nil)
        return;

    [_referringObjectToPaths removeObjectForKey: aReferrer];
    for (COPath *path in paths)
    {
        [self removeObjectFromPathsToReferringObjects: aReferrer
                                              forPath: path];
    }
}

- (void)removePath: (COPath *)aPath
{
    NSHashTable *referringObjects = [_pathToReferringObjects[aPath] copy];

    for (COObject *referrer in referringObjects)
    {
        [self removeReferringObject: referrer forPath: aPath];
    }
}

@end
