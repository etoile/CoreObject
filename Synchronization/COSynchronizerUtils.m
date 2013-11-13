#import "COSynchronizerUtils.h"
#import "COSQLiteStore.h"
#import "COStoreTransaction.h"

@implementation COSynchronizerUtils

+ (COItemGraphDiff *)diffForRebasingGraph: (id <COItemGraph>)sourceGraph
								ontoGraph: (id <COItemGraph>)destGraph
								baseGraph: (id <COItemGraph>)baseGraph
{
    COItemGraphDiff *mergingBranchDiff = [COItemGraphDiff diffItemTree: baseGraph withItemTree: sourceGraph sourceIdentifier: @"merged"];
    COItemGraphDiff *selfDiff = [COItemGraphDiff diffItemTree: baseGraph withItemTree: destGraph sourceIdentifier: @"self"];
    
    COItemGraphDiff *merged = [selfDiff itemTreeDiffByMergingWithDiff: mergingBranchDiff];
	return merged;
}

+ (NSArray *) rebaseRevision: (ETUUID *)source
				ontoRevision: (ETUUID *)dest
		  persistentRootUUID: (ETUUID *)persistentRoot
				  branchUUID: (ETUUID *)branch
					   store: (COSQLiteStore *)store
				 transaction: (COStoreTransaction *)txn
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
		
		COItemGraphDiff *diff = [self diffForRebasingGraph: sourceGraph
												 ontoGraph: currentDestGraph
												 baseGraph: baseGraph];
		
		if([diff hasConflicts])
		{
			NSLog(@"Attempting to auto-resolve conflicts favouring the other user...");
			[diff resolveConflictsFavoringSourceIdentifier: @"merged"]; // FIXME: Hardcoded
		}
		
		//NSLog(@"Applying diff %@", diff);
		
		COItemGraph *mergeResult = [diff itemTreeWithDiffAppliedToItemGraph: baseGraph];
		
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


+ (ETUUID *) writeMergeWithBaseRevision: (ETUUID *)base
							firstBranch: (ETUUID *)branch1
						   secondBranch: (ETUUID *)branch2
					 persistentRootUUID: (ETUUID *)persistentRoot
							 branchUUID: (ETUUID *)branch
								  store: (COSQLiteStore *)store
							transaction: (COStoreTransaction *)txn
{
	id <COItemGraph> baseGraph = [store itemGraphForRevisionUUID: base persistentRoot: persistentRoot];
	id <COItemGraph> branch1Graph = [store itemGraphForRevisionUUID: branch1 persistentRoot: persistentRoot];
	id <COItemGraph> branch2Graph = [store itemGraphForRevisionUUID: branch2 persistentRoot: persistentRoot];
	
	COItemGraphDiff *diff = [self diffForRebasingGraph: branch1Graph
											 ontoGraph: branch2Graph
											 baseGraph: baseGraph];
		
	if([diff hasConflicts])
	{
		NSLog(@"Attempting to auto-resolve conflicts favouring the other user...");
		[diff resolveConflictsFavoringSourceIdentifier: @"merged"]; // FIXME: Hardcoded
	}
		
	//NSLog(@"Applying diff %@", diff);
	
	COItemGraph *mergeResult = [diff itemTreeWithDiffAppliedToItemGraph: baseGraph];
	
	ETUUID *nextRev = [ETUUID UUID];

	[txn writeRevisionWithModifiedItems: mergeResult
						   revisionUUID: nextRev
							   metadata: @{}
					   parentRevisionID: branch2
				  mergeParentRevisionID: nil
					 persistentRootUUID: persistentRoot
							 branchUUID: branch];

	return nextRev;
}

@end
