#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

#import <CoreObject/CoreObject.h>

/**
 * Many-to-many map between COObject and persistent root UUID. An entry
 * in the map means that COObject has a cross-reference to that persistent root.
 *
 * N.B. The regular relationship cache tracks relationships between COObjects
 *      in a many-to-many map, but instead of having a central cache stored in
 *      COEditingContext, it's distributed among COObject instances. 
 *      It might be possible to reuse that mechanism for this, however it wouldn't
 *      be clean.
 *
 *      For example, we have to handle:
 *       - branch deletion, undeletion
 *       - persistent root deletion, undeletion
 *
 *      and when a branch is undeleted, we need to find all objects with references
 *      to it and recreate those references.
 *
 *      If we tried to use the COObject relationship cache for this, we'd need
 *      to keep a root COObject alive for deleted branches, and even deleted
 *      persistent roots no longer in the store (ugly)
 */
@interface COCrossPersistentRootReferenceCache : NSObject
{
    NSMapTable *_objectToPersistentRoots;
    NSMutableDictionary *_persistentRootToObjects;
}

- (NSArray *) affectedObjectsForChangeInPersistentRoot: (ETUUID *)aPersistentRoot;

- (void) clearReferencedPersistentRootsForObject: (COObject *)anObject;
- (void) addReferencedPersistentRoot: (ETUUID *)aPersistentRoot
                           forObject: (COObject *)anObject;

@end
