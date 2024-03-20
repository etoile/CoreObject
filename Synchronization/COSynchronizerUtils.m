/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizerUtils.h"
#import "COStoreTransaction.h"

@interface COGraphCache : NSObject
{
    COSQLiteStore *store;
    ETUUID *persistentRoot;
    NSMutableDictionary *cache;
}

- (instancetype)initWithPersistentRootUUID: (ETUUID *)aUUID
                                     store: (COSQLiteStore *)aStore NS_DESIGNATED_INITIALIZER;
/**
 * Don't modify the returned graph
 */
- (COItemGraph *)graphForUUID: (ETUUID *)aRevision;

@end


@implementation COGraphCache

- (instancetype)initWithPersistentRootUUID: (ETUUID *)aUUID store: (COSQLiteStore *)aStore
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(aStore)
    SUPERINIT;
    persistentRoot = aUUID;
    store = aStore;
    cache = [NSMutableDictionary new];
    return self;
}

- (instancetype)init
{
    return [self initWithPersistentRootUUID: nil store: nil];
}

- (COItemGraph *)graphForUUID: (ETUUID *)aRevision
{
    COItemGraph *result = cache[aRevision];
    if (result == nil)
    {
        result = [store itemGraphForRevisionUUID: aRevision persistentRoot: persistentRoot];
        cache[aRevision] = result;
    }
    return result;
}

- (void)setGraph: (COItemGraph *)aGraph forUUID: (ETUUID *)aRevision
{
    cache[aRevision] = aGraph;
}

@end


@implementation COSynchronizerUtils

+ (NSArray *)rebaseRevision: (ETUUID *)source
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
    NSArray *sourceRevs =
        CORevisionsUUIDsFromExclusiveToInclusive(lca, source, persistentRoot, ctx);
    ETAssert(sourceRevs != nil);
    ETAssert(sourceRevs.count > 0);

    NSMutableArray *newRevids = [[NSMutableArray alloc] init];

    COGraphCache *cache = [[COGraphCache alloc] initWithPersistentRootUUID: persistentRoot
                                                                     store: store];

    ETUUID *currentLCA = lca;
    ETUUID *currentDest = dest;
    for (ETUUID *sourceRev in sourceRevs)
    {
        CORevisionInfo *sourceRevInfo = [store revisionInfoForRevisionUUID: source
                                                        persistentRootUUID: persistentRoot];
        CORevisionInfo *destRevInfo = [store revisionInfoForRevisionUUID: dest
                                                      persistentRootUUID: persistentRoot];
        CORevisionInfo *lcaRevInfo = [store revisionInfoForRevisionUUID: lca
                                                     persistentRootUUID: persistentRoot];
        
        // NOTE: If we want to support schema migration on-demand when loading item graphs, then
        // the migration code must be called before diffing/merging item graphs below.
        NSAssert(sourceRevInfo.schemaVersion == destRevInfo.schemaVersion
              && sourceRevInfo.schemaVersion == lcaRevInfo.schemaVersion,
                 @"Mismatched schema versions between merged revisions for rebase");
        
        id <COItemGraph> currentSourceGraph = [cache graphForUUID: sourceRev];
        id <COItemGraph> currentDestGraph = [cache graphForUUID: currentDest];
        id <COItemGraph> currentLCAGraph = [cache graphForUUID: currentLCA];

        CODiffManager *sourceBranchDiff = [CODiffManager diffItemGraph: currentLCAGraph
                                                         withItemGraph: currentSourceGraph
                                            modelDescriptionRepository: repo
                                                      sourceIdentifier: @"source"];
        CODiffManager *destBranchDiff = [CODiffManager diffItemGraph: currentLCAGraph
                                                       withItemGraph: currentDestGraph
                                          modelDescriptionRepository: repo
                                                    sourceIdentifier: @"dest"];

        CODiffManager *mergedDiff = [destBranchDiff diffByMergingWithDiff: sourceBranchDiff];

        if (mergedDiff.hasConflicts)
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
                                   metadata: sourceRevInfo.metadata
                           parentRevisionID: currentDest
                      mergeParentRevisionID: nil
                         persistentRootUUID: persistentRoot
                                 branchUUID: branch
                              schemaVersion: sourceRevInfo.schemaVersion];

        [cache setGraph: mergeResult forUUID: nextRev];
        currentDest = nextRev;
        currentLCA = sourceRev;
    }

    return newRevids;
}

@end
