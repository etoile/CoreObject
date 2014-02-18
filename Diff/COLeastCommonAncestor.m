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

/**
 * Naiive algorithm: gather paths from commitA to the root, and commitB to the root,
 * and return their first intersection.
 */
- (ETUUID *)commonAncestorForCommit: (ETUUID *)commitA
						  andCommit: (ETUUID *)commitB
					 persistentRoot: (ETUUID *)persistentRoot
{
	NSMutableSet *ancestorsOfA = [NSMutableSet set];
	
	for (ETUUID *temp = commitA; temp != nil; temp = [[[self revisionForRevisionUUID: temp persistentRootUUID: persistentRoot] parentRevision] UUID])
	{
		[ancestorsOfA addObject: temp];
	}
	
	for (ETUUID *temp = commitB; temp != nil; temp = [[[self revisionForRevisionUUID: temp persistentRootUUID: persistentRoot] parentRevision] UUID])
	{
		if ([ancestorsOfA containsObject: temp])
		{
			return temp;
		}
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
        rev = [[[self revisionForRevisionUUID: rev persistentRootUUID: persistentRoot] parentRevision] UUID];
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
        rev = [[[self revisionForRevisionUUID: rev persistentRootUUID: persistentRoot] parentRevision] UUID];
    }
    return nil;
}


@end
