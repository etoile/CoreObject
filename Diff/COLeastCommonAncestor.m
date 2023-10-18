/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COLeastCommonAncestor.h"

void COCollectParentRevisionUUIDsFromInclusiveInto(ETUUID *rev,
                                              ETUUID *persistentRoot,
                                              NSMutableSet *ancestorRevs,
                                              id <COParentRevisionProvider> provider)
{
    if ([ancestorRevs containsObject: rev])
        return;

    [ancestorRevs addObject: rev];

    ETUUID *mergeParentRev;
    ETUUID *parentRev = [provider parentRevisionUUIDForRevisionUUID: rev
                                            mergeParentRevisionUUID: &mergeParentRev
                                                 persistentRootUUID: persistentRoot];

    if (parentRev != nil)
    {
        COCollectParentRevisionUUIDsFromInclusiveInto(parentRev,
                                                      persistentRoot,
                                                      ancestorRevs,
                                                      provider);
    }
    if (mergeParentRev != nil)
    {
        COCollectParentRevisionUUIDsFromInclusiveInto(mergeParentRev,
                                                      persistentRoot,
                                                      ancestorRevs,
                                                      provider);
    }
}


ETUUID *COCommonAncestorRevisionUUIDs(ETUUID *revA,
                                      ETUUID *revB,
                                      ETUUID *persistentRoot,
                                      id <COParentRevisionProvider> provider)
{
    NSMutableSet *ancestorsOfA = [NSMutableSet set];

    COCollectParentRevisionUUIDsFromInclusiveInto(revA, persistentRoot, ancestorsOfA, provider);

    // Do a BFS starting at revB until we hit a commit in ancestorsOfA
    // TODO: Check whether this makes sense

    NSMutableArray *siblings = [NSMutableArray arrayWithObject: revB];

    while (siblings.count > 0)
    {
        NSMutableArray *nextSiblings = [NSMutableArray new];

        for (ETUUID *sibling in siblings)
        {
            if ([ancestorsOfA containsObject: sibling])
            {
                return sibling;
            }
            ETUUID *mergeParentRev;
            ETUUID *parentRev = [provider parentRevisionUUIDForRevisionUUID: sibling
                                                    mergeParentRevisionUUID: &mergeParentRev
                                                         persistentRootUUID: persistentRoot];

            if (parentRev != nil)
                [nextSiblings addObject: parentRev];

            if (mergeParentRev != nil)
                [nextSiblings addObject: mergeParentRev];
        }

        [siblings setArray: nextSiblings];
    }

    // No common ancestor
    return nil;
}

BOOL CORevisionUUIDEqualToOrParent(ETUUID *revA,
                                   ETUUID *revB,
                                   ETUUID *persistentRoot,
                                   id <COParentRevisionProvider> provider)
{
    ETUUID *rev = revB;
    while (rev != nil)
    {
        if ([rev isEqual: revA])
        {
            return YES;
        }
        rev = [provider parentRevisionUUIDForRevisionUUID: rev
                                  mergeParentRevisionUUID: NULL
                                       persistentRootUUID: persistentRoot];
    }
    return NO;
}

NSArray *CORevisionsUUIDsFromExclusiveToInclusive(ETUUID *start,
                                                  ETUUID *end,
                                                  ETUUID *persistentRoot,
                                                  id <COParentRevisionProvider> provider)
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    ETUUID *rev = end;
    while (rev != nil)
    {
        if ([rev isEqual: start])
        {
            return result;
        }
        [result insertObject: rev atIndex: 0];
        rev = [provider parentRevisionUUIDForRevisionUUID: rev
                                  mergeParentRevisionUUID: NULL
                                       persistentRootUUID: persistentRoot];
    }
    return nil;
}
