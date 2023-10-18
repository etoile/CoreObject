/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct
{
    ETUUID *_Nullable parent;
    ETUUID *_Nullable mergeParent;
} COParentRevisionUUIDs;

@protocol COParentRevisionProvider
- (COParentRevisionUUIDs)parentRevisionUUIDsForRevisionUUID: (ETUUID *)aRevisionUUID
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
