/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

NS_ASSUME_NONNULL_BEGIN

@protocol COParentRevisionProvider
- (nullable ETUUID *)parentRevisionUUIDForRevisionUUID: (ETUUID *)aRevisionUUID
                               mergeParentRevisionUUID: (ETUUID *_Nullable*_Nullable)aMergeParentRevisionUUID
                                    persistentRootUUID: (ETUUID *)aPersistentRoot;
@end

ETUUID *_Nullable COCommonAncestorRevisionUUIDs(ETUUID *revA, 
                                                ETUUID *revB,
                                                ETUUID *persistentRoot,
                                                id <COParentRevisionProvider> provider);
BOOL CORevisionUUIDEqualToOrParent(ETUUID *revA,
                                   ETUUID *revB,
                                   ETUUID *persistentRoot,
                                   id <COParentRevisionProvider> provider);
/**
 * As a special case, if [start isEqual: end] returns the empty array.
 */
NSArray<ETUUID *> *CORevisionsUUIDsFromExclusiveToInclusive(ETUUID *start, 
                                                            ETUUID *end,
                                                            ETUUID *persistentRoot,
                                                            id <COParentRevisionProvider> provider);

NS_ASSUME_NONNULL_END
