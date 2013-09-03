#import "COLeastCommonAncestor.h"
#import "CORevisionID.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"

@implementation COLeastCommonAncestor

/**
 * Naiive algorithm: gather paths from commitA to the root, and commitB to the root,
 * and return their first intersection.
 */
+ (CORevisionID *)commonAncestorForCommit: (CORevisionID *)commitA
                                andCommit: (CORevisionID *)commitB
                                    store: (COSQLiteStore *)aStore
{
	NSMutableSet *ancestorsOfA = [NSMutableSet set];
	
	for (CORevisionID *temp = commitA; temp != nil; temp = [[aStore revisionInfoForRevisionID: temp] parentRevisionID])
	{
		[ancestorsOfA addObject: temp];
	}
	
	for (CORevisionID *temp = commitB; temp != nil; temp = [[aStore revisionInfoForRevisionID: temp] parentRevisionID])
	{
		if ([ancestorsOfA containsObject: temp])
		{
			return temp;
		}
	}
	
	// No common ancestor
	return nil;
}

@end
