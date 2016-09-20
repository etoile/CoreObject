/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import "COLeastCommonAncestor.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"
#import "COEditingContext+Private.h"
#import "CORevision.h"

@implementation COEditingContext (CommonAncestor)

- (void) addUUIDAndParents: (ETUUID *)aUUID persistentRoot: (ETUUID *)persistentRoot toSet: (NSMutableSet *)dest
{
	if ([dest containsObject: aUUID])
		return;
	
	[dest addObject: aUUID];
	
	CORevision *revision = [self revisionForRevisionUUID: aUUID persistentRootUUID: persistentRoot];
	
	if (revision.parentRevision != nil)
		[self addUUIDAndParents: revision.parentRevision.UUID persistentRoot: persistentRoot toSet: dest];
	
	if (revision.mergeParentRevision != nil)
		[self addUUIDAndParents: revision.mergeParentRevision.UUID persistentRoot: persistentRoot toSet: dest];
}

- (ETUUID *)commonAncestorForCommit: (ETUUID *)commitA
						  andCommit: (ETUUID *)commitB
					 persistentRoot: (ETUUID *)persistentRoot
{
	NSMutableSet *ancestorsOfA = [NSMutableSet set];
	
	[self addUUIDAndParents: commitA persistentRoot: persistentRoot toSet: ancestorsOfA];
	
	// Do a BFS starting at commitB until we hit a commit in ancestorsOfA
	// TODO: Check whether this makes sense
	
	NSMutableArray *siblingsArray = [NSMutableArray arrayWithObject: commitB];
	
	while (siblingsArray.count > 0)
	{
		NSMutableArray *nextSiblingsArray = [NSMutableArray new];
		
		for (ETUUID *sibling in siblingsArray)
		{
			if ([ancestorsOfA containsObject: sibling])
			{
				return sibling;
			}
			
			CORevision *revision = [self revisionForRevisionUUID: sibling persistentRootUUID: persistentRoot];
			
			if (revision.parentRevision != nil)
				[nextSiblingsArray addObject: revision.parentRevision.UUID];
			
			if (revision.mergeParentRevision != nil)
				[nextSiblingsArray addObject: revision.mergeParentRevision.UUID];
		}
		
		[siblingsArray setArray: nextSiblingsArray];
	}
	
	// No common ancestor
	return nil;
}

- (BOOL)        isRevision: (ETUUID *)commitA
 equalToOrParentOfRevision: (ETUUID *)commitB
			persistentRoot: (ETUUID *)persistentRoot
{
    ETUUID *rev = commitB;
    while (rev != nil)
    {
        if ([rev isEqual: commitA])
        {
            return YES;
        }
        rev = [self revisionForRevisionUUID: rev persistentRootUUID: persistentRoot].parentRevision.UUID;
    }
    return NO;
}

- (NSArray *) revisionUUIDsFromRevisionUUIDExclusive: (ETUUID *)start
							 toRevisionUUIDInclusive: (ETUUID *)end
									  persistentRoot: (ETUUID *)persistentRoot
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
        rev = [self revisionForRevisionUUID: rev persistentRootUUID: persistentRoot].parentRevision.UUID;
    }
    return nil;
}


@end
