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

    COParentRevisionUUIDs parentRevUUIDs = 
        [provider parentRevisionUUIDsForRevisionUUID: rev
                                  persistentRootUUID: persistentRoot];

    if (parentRevUUIDs.parent != nil)
    {
        COCollectParentRevisionUUIDsFromInclusiveInto(parentRevUUIDs.parent,
                                                      persistentRoot,
                                                      ancestorRevs,
                                                      provider);
    }
    if (parentRevUUIDs.mergeParent != nil)
    {
        COCollectParentRevisionUUIDsFromInclusiveInto(parentRevUUIDs.mergeParent,
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
            COParentRevisionUUIDs parentRevUUIDs =
                [provider parentRevisionUUIDsForRevisionUUID: sibling
                                          persistentRootUUID: persistentRoot];

            if (parentRevUUIDs.parent != nil)
                [nextSiblings addObject: parentRevUUIDs.parent];

            if (parentRevUUIDs.mergeParent != nil)
                [nextSiblings addObject: parentRevUUIDs.mergeParent];
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
        rev = [provider parentRevisionUUIDsForRevisionUUID: rev
                                        persistentRootUUID: persistentRoot].parent;
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
        rev = [provider parentRevisionUUIDsForRevisionUUID: rev
                                        persistentRootUUID: persistentRoot].parent;
    }
    return nil;
}
