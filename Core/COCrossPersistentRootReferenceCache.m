#import "COCrossPersistentRootReferenceCache.h"

@implementation COCrossPersistentRootReferenceCache

- (id) init
{
    SUPERINIT;
    
    _objectToPersistentRoots = [[NSMapTable alloc] initWithKeyOptions: NSMapTableWeakMemory
                                                         valueOptions: NSMapTableStrongMemory
                                                             capacity: 16];
    
    _persistentRootToObjects = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_objectToPersistentRoots release];
    [_persistentRootToObjects release];
    [super dealloc];
}

- (NSArray *) affectedObjectsForChangeInPersistentRoot: (ETUUID *)aPersistentRoot
{
    NSHashTable *set = [_persistentRootToObjects objectForKey: aPersistentRoot];
    return [set allObjects];
}

- (NSArray *) referencedPersistentRootUUIDsForObject: (COObject *)anObject
{
    NSSet *set = [_objectToPersistentRoots objectForKey: anObject];
    return [set allObjects];
}

- (void) addReferencedPersistentRoot: (ETUUID *)aPersistentRoot
                           forObject: (COObject *)anObject
{
    {
        NSMutableSet *persistentRootSet = [_objectToPersistentRoots objectForKey: anObject];
        if (persistentRootSet == nil)
        {
            persistentRootSet = [NSMutableSet set];
            [_objectToPersistentRoots setObject: persistentRootSet forKey: anObject];
        }
        [persistentRootSet addObject: aPersistentRoot];
    }

    {
        NSHashTable *objectSet = [_persistentRootToObjects objectForKey: aPersistentRoot];
        if (objectSet == nil)
        {
            objectSet = [NSHashTable weakObjectsHashTable];
            [_persistentRootToObjects setObject: objectSet forKey: aPersistentRoot];
        }
        [objectSet addObject: anObject];
    }
}

- (void) removeReferencedPersistentRoot: (ETUUID *)aPersistentRoot
                              forObject: (COObject *)anObject
{
    {
        NSMutableSet *persistentRootSet = [_objectToPersistentRoots objectForKey: anObject];
        [persistentRootSet removeObject: aPersistentRoot];
    }
    
    {
        NSHashTable *objectSet = [_persistentRootToObjects objectForKey: aPersistentRoot];
        [objectSet removeObject: anObject];
    }
}

- (void) clearReferencedPersistentRootsForObject: (COObject *)anObject
{
    NSMutableSet *persistentRootSet = [_objectToPersistentRoots objectForKey: anObject];
    
    for (ETUUID *persistentRoot in persistentRootSet)
    {
        NSHashTable *objectSet = [_persistentRootToObjects objectForKey: persistentRoot];
        [objectSet removeObject: anObject];
    }
    
    [persistentRootSet removeAllObjects];
}

@end
