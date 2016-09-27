/**
    Copyright (C) 2015 Quentin Mathe

    Date:  May 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COPath, COObject;

/**
 * An instance of this class is owned by each COEditingContext, to cache 
 * incoming relationships for faulted, deleted or possibly finalized
 * persistent roots.
 *
 * For faulted or deleted persistent roots or branches, the root object is not
 * present in memory, so we cannot track incoming relationships accross 
 * persistent roots using the usual relationship cache that exists per object.
 *
 * When a persistent root or branch is unfaulted or undeleted, we use this cache 
 * to know which other persistent roots outgoing relationships must be fixed to 
 * point to the resurrected root object. To fix outgoing relationships accross 
 * persistent roots, we replace dead COPath references hidden in the 
 * COPrimitiveCollection backing by alive COObject references.
 */
@interface COCrossPersistentRootDeadRelationshipCache : NSObject
{
    @private
    NSMutableDictionary *_pathToReferringObjects;
    NSMapTable *_referringObjectToPaths;
}

- (void)addReferringObject: (COObject *)aReferrer
                   forPath: (COPath *)aPath;
/**
 * When no referring objects exist, returns nil.
 */
- (NSHashTable *)referringObjectsForPath: (COPath *)aPath;
- (void)removeReferringObject: (COObject *)aReferrer
                      forPath: (COPath *)aPath;
- (void)removeReferringObject: (COObject *)aReferrer;
/**
 * Removes all referring objects for the path.
 *
 * When a persistent root or branch is unfaulted, undeleted or finalized, this 
 * method should be called with a persistent root path that corresponds to the
 * undeletion/finalization target.
 * When a persistent root or branch is unloaded, any matching paths should be 
 * kept in the cache, in case it gets reloaded later (we cannot figure out cross 
 * persistent root incoming relationships from the reloading).
 *
 * For referring object graph contexts, when unloaded or finalized, the
 * deallocation will trigger their removal of their inner objects from the hash 
 * tables in the cache on 10.8 or iOS 6 or higher, but not on 10.7.
 */
- (void)removePath: (COPath *)aPath;

@end
