/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  August 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COCrossPersistentRootReferenceCache.h"

@implementation COCrossPersistentRootReferenceCache

- (id) init
{
    SUPERINIT;

	// FIXME: For versions prior to 10.8, objects must be explicitly removed
	// from the map table if manual reference couting is used.
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8
	_objectToPersistentRoots = [[NSMapTable alloc] initWithKeyOptions: NSMapTableWeakMemory
#else
	_objectToPersistentRoots = [[NSMapTable alloc] initWithKeyOptions: NSMapTableZeroingWeakMemory							
#endif
                                                         valueOptions: NSMapTableStrongMemory
                                                             capacity: 16];
    
    _persistentRootToObjects = [[NSMutableDictionary alloc] init];
    
    return self;
}

// TODO: Improve the output
- (NSString *)description
{
	NSMutableDictionary *dict = D(_persistentRootToObjects, @"Persistent root to Objects",
	                              _objectToPersistentRoots, @"Object to Persistent Roots");

	/* For Mac OS X, see http://www.cocoabuilder.com/archive/cocoa/197297-who-broke-nslog-on-leopard.html */
	NSString *desc = [dict description];
	desc = [desc stringByReplacingOccurrencesOfString: @"\\n" withString: @"\n"];
	desc = [desc stringByReplacingOccurrencesOfString: @"\\\"" withString: @""];
	return desc;
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
			// FIXME: For versions prior to 10.8, objects must be explicitly
			// removed from the hash table if manual reference couting is used.
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8
			objectSet = [NSHashTable weakObjectsHashTable];
#else
            objectSet = [NSHashTable hashTableWithWeakObjects];
#endif
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
