/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizerUtils.h"
#import "COSQLiteStore.h"
#import "COStoreTransaction.h"

@interface COGraphCache : NSObject
{
	COSQLiteStore *store;
	ETUUID *persistentRoot;
	NSMutableDictionary *cache;
}
- (instancetype) initWithPersistentRootUUID: (ETUUID *)aUUID store: (COSQLiteStore *)aStore;
/**
 * Don't modify the returned graph
 */
- (COItemGraph *) graphForUUID: (ETUUID *)aRevision;
@end

@implementation COGraphCache

- (instancetype) initWithPersistentRootUUID: (ETUUID *)aUUID store: (COSQLiteStore *)aStore
{
	SUPERINIT;
	persistentRoot = aUUID;
	store = aStore;
	cache = [NSMutableDictionary new];
	return self;
}

- (COItemGraph *) graphForUUID: (ETUUID *)aRevision
{
	COItemGraph *result = cache[aRevision];
	if (result == nil)
	{
		result = [store itemGraphForRevisionUUID: aRevision persistentRoot: persistentRoot];
		cache[aRevision] = result;
	}
	return result;
}

- (void) setGraph: (COItemGraph *)aGraph forUUID: (ETUUID *)aRevision
{
	cache[aRevision] = aGraph;
}

@end


@implementation COSynchronizerUtils

+ (NSArray *) rebaseRevision: (ETUUID *)source
				ontoRevision: (ETUUID *)dest
			  commonAncestor: (ETUUID *)lca
		  persistentRootUUID: (ETUUID *)persistentRoot
				  branchUUID: (ETUUID *)branch
					   store: (COSQLiteStore *)store
				 transaction: (COStoreTransaction *)txn
			  editingContext: (COEditingContext *)ctx
  modelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	ETAssert(source != nil);
	ETAssert(dest != nil);
	ETAssert(lca != nil);
			
	// Gather the revisions to rebase (between 'lca', exclusive, and 'source', inclusive)
	NSArray *sourceRevs = [ctx revisionUUIDsFromRevisionUUIDExclusive: lca
											  toRevisionUUIDInclusive: source
													   persistentRoot: persistentRoot];
	ETAssert(sourceRevs != nil);
	ETAssert([sourceRevs count] > 0);
	
	NSMutableArray *newRevids = [[NSMutableArray alloc] init];
	
	COGraphCache *cache = [[COGraphCache alloc] initWithPersistentRootUUID: persistentRoot store: store];
		
	ETUUID *currentLCA = lca;
	ETUUID *currentDest = dest;
	for (ETUUID *sourceRev in sourceRevs)
	{
		NSDictionary *sourceMetadata = [store revisionInfoForRevisionUUID: sourceRev persistentRootUUID: persistentRoot].metadata;
		id <COItemGraph> currentSourceGraph = [cache graphForUUID: sourceRev];
		id <COItemGraph> currentDestGraph = [cache graphForUUID: currentDest];
		id <COItemGraph> currentLCAGraph = [cache graphForUUID: currentLCA];
				
		CODiffManager *sourceBranchDiff = [CODiffManager diffItemGraph: currentLCAGraph withItemGraph: currentSourceGraph modelDescriptionRepository: repo sourceIdentifier: @"source"];
		CODiffManager *destBranchDiff = [CODiffManager diffItemGraph: currentLCAGraph withItemGraph: currentDestGraph modelDescriptionRepository: repo sourceIdentifier: @"dest"];
		
		CODiffManager *mergedDiff = [destBranchDiff diffByMergingWithDiff: sourceBranchDiff];
		
		if([mergedDiff hasConflicts])
		{
			NSLog(@"Attempting to auto-resolve conflicts favouring the other user...");
			[mergedDiff resolveConflictsFavoringSourceIdentifier: @"source"]; // FIXME: Hardcoded
		}
		
		//NSLog(@"Applying diff %@", diff);
		
		COItemGraph *mergeResult = [[COItemGraph alloc] initWithItemGraph: currentLCAGraph];
		[mergedDiff applyTo: mergeResult];
		
		ETUUID *nextRev = [ETUUID UUID];
		[newRevids addObject: nextRev];
		[txn writeRevisionWithModifiedItems: mergeResult
							   revisionUUID: nextRev
								   metadata: sourceMetadata
						   parentRevisionID: currentDest
					  mergeParentRevisionID: nil
						 persistentRootUUID: persistentRoot
								 branchUUID: branch];

		[cache setGraph: mergeResult forUUID: nextRev];
		currentDest = nextRev;
		currentLCA = sourceRev;
	}
	
	return newRevids;
}

@end
