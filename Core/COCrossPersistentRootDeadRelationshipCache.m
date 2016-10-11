/*
    Copyright (C) 2015 Quentin Mathe

    Date:  May 2015
    License:  MIT  (see COPYING)
 */

#import "COCrossPersistentRootDeadRelationshipCache.h"
#import "COPath.h"

//#define MISSING_ZEROING_WEAK_REF

@implementation COCrossPersistentRootDeadRelationshipCache

- (instancetype)init
{
    SUPERINIT;
    _pathToReferringObjects = [NSMutableDictionary new];
    _referringObjectToPaths = [NSMapTable weakToStrongObjectsMapTable];
    return self;
}

- (void)addReferringObject: (COObject *)aReferrer
                   forPath: (COPath *)aPath
{
    NSHashTable *referringObjects = _pathToReferringObjects[aPath];
    NSMutableSet *paths = [_referringObjectToPaths objectForKey: aReferrer];

    if (referringObjects == nil)
    {
        referringObjects = [NSHashTable weakObjectsHashTable];

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
