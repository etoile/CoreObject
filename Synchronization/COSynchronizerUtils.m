/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizerUtils.h"
#import "COSQLiteStore.h"
#import "COStoreTransaction.h"

@implementation COSynchronizerUtils

+ (CODiffManager *)diffForRebasingGraph: (id <COItemGraph>)sourceGraph
							  ontoGraph: (id <COItemGraph>)destGraph
							  baseGraph: (id <COItemGraph>)baseGraph
			 modelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    CODiffManager *mergingBranchDiff = [CODiffManager diffItemGraph: baseGraph withItemGraph: sourceGraph modelDescriptionRepository: repo sourceIdentifier: @"merged"];
    CODiffManager *selfDiff = [CODiffManager diffItemGraph: baseGraph withItemGraph: destGraph modelDescriptionRepository: repo sourceIdentifier: @"self"];
    
    CODiffManager *merged = [selfDiff diffByMergingWithDiff: mergingBranchDiff];
	return merged;
}

+ (NSArray *) rebaseRevision: (ETUUID *)source
				ontoRevision: (ETUUID *)dest
		  persistentRootUUID: (ETUUID *)persistentRoot
				  branchUUID: (ETUUID *)branch
					   store: (COSQLiteStore *)store
				 transaction: (COStoreTransaction *)txn
  modelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	ETUUID *lca = [COLeastCommonAncestor commonAncestorForCommit: source
													   andCommit: dest
												  persistentRoot: persistentRoot
														   store: store];
	
	ETAssert(lca != nil);
	
	id <COItemGraph> baseGraph = [store itemGraphForRevisionUUID: lca persistentRoot: persistentRoot];
	
	NSArray *sourceRevs = [COLeastCommonAncestor revisionUUIDsFromRevisionUUIDExclusive: lca
																toRevisionUUIDInclusive: source
																		 persistentRoot: persistentRoot
																				  store: store];
	
	NSMutableArray *newRevids = [[NSMutableArray alloc] init];

	NSMutableDictionary *transactionGraphs = [[NSMutableDictionary alloc] init];
	
	ETUUID *currentDest = dest;
	for (ETUUID *rev in sourceRevs)
	{
		id <COItemGraph> sourceGraph = [store itemGraphForRevisionUUID: rev persistentRoot: persistentRoot];
		id <COItemGraph> currentDestGraph = transactionGraphs[currentDest];
		if (currentDestGraph == nil)
		{
			currentDestGraph = [store itemGraphForRevisionUUID: currentDest persistentRoot: persistentRoot];
			ETAssert(currentDestGraph != nil);
		}
		
		CODiffManager *diff = [self diffForRebasingGraph: sourceGraph
											   ontoGraph: currentDestGraph
											   baseGraph: baseGraph
							  modelDescriptionRepository: repo];
		
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
								   metadata: @{} // FIXME: Reuse metadata from source revision?
						   parentRevisionID: currentDest
					  mergeParentRevisionID: nil
						 persistentRootUUID: persistentRoot
								 branchUUID: branch];
		transactionGraphs[nextRev] = mergeResult;
		
		currentDest = nextRev;
	}
	
	return newRevids;
}

@end
