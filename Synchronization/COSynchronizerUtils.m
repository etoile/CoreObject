/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizerUtils.h"
#import "COSQLiteStore.h"
#import "COStoreTransaction.h"

@implementation COSynchronizerUtils

+ (NSArray *) rebaseRevision: (ETUUID *)source
				ontoRevision: (ETUUID *)dest
			  commonAncestor: (ETUUID *)lca
		  persistentRootUUID: (ETUUID *)persistentRoot
				  branchUUID: (ETUUID *)branch
					   store: (COSQLiteStore *)store
				 transaction: (COStoreTransaction *)txn
  modelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	ETAssert(source != nil);
	ETAssert(dest != nil);
	ETAssert(lca != nil);
		
	id <COItemGraph> baseGraph = [store itemGraphForRevisionUUID: lca persistentRoot: persistentRoot];
	id <COItemGraph> destGraph = [store itemGraphForRevisionUUID: dest persistentRoot: persistentRoot];
	
	// Gather the revisions to rebase (between 'lca', exclusive, and 'source', inclusive)
	NSArray *sourceRevs = [COLeastCommonAncestor revisionUUIDsFromRevisionUUIDExclusive: lca
																toRevisionUUIDInclusive: source
																		 persistentRoot: persistentRoot
																				  store: store];
	ETAssert(sourceRevs != nil);
	ETAssert([sourceRevs count] > 0);
	
	NSMutableArray *newRevids = [[NSMutableArray alloc] init];

	CODiffManager *selfDiff = [CODiffManager diffItemGraph: baseGraph withItemGraph: destGraph modelDescriptionRepository: repo sourceIdentifier: @"self"];
	
	ETUUID *currentDest = dest;
	for (ETUUID *rev in sourceRevs)
	{
		NSDictionary *sourceMetadata = [[store revisionInfoForRevisionUUID: rev persistentRootUUID: persistentRoot] metadata];
		id <COItemGraph> sourceGraph = [store itemGraphForRevisionUUID: rev persistentRoot: persistentRoot];
		ETAssert(sourceGraph != nil);
		
		CODiffManager *mergingBranchDiff = [CODiffManager diffItemGraph: baseGraph withItemGraph: sourceGraph modelDescriptionRepository: repo sourceIdentifier: @"merged"];
		
		CODiffManager *diff = [selfDiff diffByMergingWithDiff: mergingBranchDiff];
		
		if([diff hasConflicts])
		{
			NSLog(@"Attempting to auto-resolve conflicts favouring the other user...");
			[diff resolveConflictsFavoringSourceIdentifier: @"merged"]; // FIXME: Hardcoded
		}
		
		//NSLog(@"Applying diff %@", diff);
		
		COItemGraph *mergeResult = [[COItemGraph alloc] initWithItemGraph: baseGraph];
		[diff applyTo: mergeResult];
		
		ETUUID *nextRev = [ETUUID UUID];
		[newRevids addObject: nextRev];
		[txn writeRevisionWithModifiedItems: mergeResult
							   revisionUUID: nextRev
								   metadata: sourceMetadata
						   parentRevisionID: currentDest
					  mergeParentRevisionID: nil
						 persistentRootUUID: persistentRoot
								 branchUUID: branch];
		currentDest = nextRev;
	}
	
	return newRevids;
}

@end
