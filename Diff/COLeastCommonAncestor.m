#import "COLeastCommonAncestor.h"
#import "CORevisionID.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"

@implementation COLeastCommonAncestor

/**
 * Naiive algorithm: gather paths from commitA to the root, and commitB to the root,
 * and return their first intersection.
 */
+ (ETUUID *)commonAncestorForCommit: (ETUUID *)commitA
                          andCommit: (ETUUID *)commitB
					 persistentRoot: (ETUUID *)persistentRoot
                              store: (COSQLiteStore *)aStore
{
	NSMutableSet *ancestorsOfA = [NSMutableSet set];
	
	// TODO: Use CORevision version so we hit the revision cache?
	
	for (ETUUID *temp = commitA; temp != nil; temp = [[aStore revisionInfoForRevisionUUID: temp persistentRootUUID: persistentRoot] parentRevisionUUID])
	{
		[ancestorsOfA addObject: temp];
	}
	
	for (ETUUID *temp = commitB; temp != nil; temp = [[aStore revisionInfoForRevisionUUID: temp persistentRootUUID: persistentRoot] parentRevisionUUID])
	{
		if ([ancestorsOfA containsObject: temp])
		{
			return temp;
		}
	}
	
	// No common ancestor
	return nil;
}

+ (BOOL)        isRevision: (ETUUID *)commitA
 equalToOrParentOfRevision: (ETUUID *)commitB
			persistentRoot: (ETUUID *)persistentRoot
                     store: (COSQLiteStore *)aStore
{
	// TODO: Use CORevision so we hit the revision cache?
	
    ETUUID *rev = commitB;
    while (rev != nil)
    {
        if ([rev isEqual: commitA])
        {
            return YES;
        }
        rev = [[aStore revisionInfoForRevisionUUID: rev persistentRootUUID: persistentRoot] parentRevisionUUID];
    }
    return NO;
}

@end
