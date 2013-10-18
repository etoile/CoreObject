#import "TestCommon.h"
#import "COItem.h"
#import "CORevisionInfo.h"

@interface TestSQLiteStorePerformance : SQLiteStoreTestCase <UKTest>
{
    NSMutableArray *revisionIDs;
}
@end


@implementation TestSQLiteStorePerformance

// --------------------------------------------
// Test case setup
// --------------------------------------------

static const int NUM_CHILDREN = 200;
static const int NUM_COMMITS = 200;

static const int NUM_PERSISTENT_ROOTS = 100;
static const int NUM_CHILDREN_PER_PERSISTENT_ROOT = 100;
static const int NUM_PERSISTENT_ROOT_COPIES = 200;

static const int LOTS_OF_EMBEDDED_ITEMS = 10000;

static ETUUID *rootUUID;
static ETUUID *childUUIDs[NUM_CHILDREN];

+ (void) initialize
{
    if (self == [TestSQLiteStorePerformance class])
    {
        rootUUID = [[ETUUID alloc] init];
        for (int i=0; i<NUM_CHILDREN; i++)
        {
            childUUIDs[i] = [[ETUUID alloc] init];
        }
    }
}

- (COItem *) initialRootItem
{
    COMutableItem *rootItem = [[COMutableItem alloc] initWithUUID: rootUUID];
    [rootItem setValue: @"root" forAttribute: @"name" type: kCOTypeString];
    [rootItem setValue: A()
          forAttribute: @"children"
                  type: kCOTypeCompositeReference | kCOTypeArray];
    
    for (int i=0; i<NUM_CHILDREN; i++)
    {
        [rootItem addObject: childUUIDs[i] forAttribute: @"children"];
    }
    return rootItem;
}

- (COItem *) initialChildItem: (int)i
{
    COMutableItem *child = [[COMutableItem alloc] initWithUUID: childUUIDs[i]];
    [child setValue: [self labelForCommit: 0 child: i]
       forAttribute: @"name"
               type: kCOTypeString];
    return child;
}

// returns index of the item that was changed at the given commit index
static int itemChangedAtCommit(int i)
{
    return ((1 + i) * 9871) % NUM_CHILDREN;
}

- (NSString *) labelForCommit: (int)commit // 0..(NUM_COMMITS - 1)
                        child: (int)child
{
    for (int i=commit; i>=0; i--)
    {
        if (itemChangedAtCommit(i) == child)
        {
            return [NSString stringWithFormat: @"modified %d in commit %d", child, i];
        }
    }
    return [NSString stringWithFormat: @"child %d never modified!", child];
}

- (COItemGraph*) makeInitialItemTree
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: NUM_CHILDREN+1];
    [dict setObject: [self initialRootItem] forKey: rootUUID];
    for (int i=0; i<NUM_CHILDREN; i++)
    {
        [dict setObject: [self initialChildItem: i]
                 forKey: childUUIDs[i]];
    }
    COItemGraph *it = [[COItemGraph alloc] initWithItemForUUID: dict rootItemUUID: rootUUID];
    return it;
}


- (ETUUID *) makeDemoPersistentRoot
{
    revisionIDs =  [NSMutableArray array];
    NSDate *startDate = [NSDate date];
    
    COItemGraph *initialTree = [self makeInitialItemTree];
    
    // Commit them to a persistet root
    
    [store beginTransactionWithError: NULL];
    COPersistentRootInfo *proot = [store createPersistentRootWithInitialItemGraph: initialTree
                                                                            UUID: [ETUUID UUID]
                                                                      branchUUID: [ETUUID UUID]
                                                                        revisionMetadata: nil
                                                                           error: NULL];
	
	// Make another copy of the item graph because we're going to modify it
	// (currently you can't modify a graph passed in to -createPersistentRootWithInitialItemGraph)
    initialTree = [self makeInitialItemTree];
	
	// Commit a change to each object
	
    [revisionIDs addObject: [[proot currentBranchInfo] currentRevisionID]];
    for (int commit=1; commit<NUM_COMMITS; commit++)
    {
        int i = itemChangedAtCommit(commit);
        
        NSString *label = [self labelForCommit: commit child: i];
        
        //        NSLog(@"item %d changed in commit %d - seting label to %@", i, commit, label);
        
        COMutableItem *item = (COMutableItem *)[initialTree itemForUUID: childUUIDs[i]];
        [item setValue:label
          forAttribute: @"name"];
        
		COItemGraph *deltaGraph = [[COItemGraph alloc] initWithItems: @[item]
														rootItemUUID: [initialTree rootItemUUID]];
		
        [revisionIDs addObject: [store writeRevisionWithItemGraph: deltaGraph
                                                     revisionUUID: [ETUUID UUID]
                                                         metadata: nil
                                                 parentRevisionID: [revisionIDs lastObject]
                                            mergeParentRevisionID: nil 
                                                       branchUUID: [proot currentBranchUUID]
                                               persistentRootUUID: [proot UUID]
                                                            error: NULL]];
    }
    
    // Set the persistent root's state to the last commit
    
    [store setCurrentRevision: [revisionIDs lastObject]
			  initialRevision: [[proot currentBranchInfo] currentRevisionID]
                 headRevision: [revisionIDs lastObject]
                    forBranch: [proot currentBranchUUID]
             ofPersistentRoot: [proot UUID]
                        error: NULL];
    
    NSLog(@"committing a %d-item persistent root and then making %d commits which touched 1 item each took %lf ms",
          NUM_CHILDREN, NUM_COMMITS, 1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
    
//    for (int i=0; i<NUM_CHILDREN; i++)
//    {
//        NSLog(@"label: %@", [self labelForCommit: NUM_COMMITS - 1
//                                           child: i]);
//    }
    
    [store commitTransactionWithError: NULL];
    
    return [proot UUID];
}


- (COItemGraph*) makeItemTreeWithChildCount: (NSUInteger)numChildren
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: numChildren+1];
    
    for (int i=0; i<numChildren; i++)
    {
        @autoreleasepool {
            COMutableItem *item = [COMutableItem item];
            [item setValue: [NSNumber numberWithInt: i] forAttribute: @"name" type: kCOTypeInt64];
            [item setValue: @"blah blah 1" forAttribute: @"test1" type: kCOTypeString];
            [item setValue: @"blah blah 2" forAttribute: @"test2" type: kCOTypeString];
            [item setValue: @"blah blah 3" forAttribute: @"test3" type: kCOTypeString];
            [item setValue: @"blah blah 4" forAttribute: @"test4" type: kCOTypeString];
            [dict setObject: item forKey: [item UUID]];
        }
    }
    
    COMutableItem *rootItem = [COMutableItem item];
    [rootItem setValue: [dict allKeys]
          forAttribute: @"children" type: kCOTypeArray | kCOTypeCompositeReference];
    [dict setObject: rootItem forKey: [rootItem UUID]];
    
    COItemGraph *it = [[COItemGraph alloc] initWithItemForUUID: dict
                                                 rootItemUUID: [rootItem UUID]];
    return it;
}

// --------------------------------------------
// End test case setup
// --------------------------------------------

- (void)testReadDelta
{
    ETUUID *prootUUID = [self makeDemoPersistentRoot];

    NSDate *startDate = [NSDate date];
    
    COPersistentRootInfo *proot = [store persistentRootInfoForUUID: prootUUID];
    
    CORevisionID *lastCommitId = [[proot currentBranchInfo] currentRevisionID];
    
    // Now traverse them in reverse order and test that the items are as expected.
    // There are NUM_CHILDREN + 1 commits (the initial one made by creating the persistent roots)

    for (int rev=NUM_COMMITS-1; rev>=1; rev--)
    {
        CORevisionID *parentCommitId = [[store revisionInfoForRevisionID: lastCommitId] parentRevisionID];
        
        COItemGraph *tree = [store partialItemGraphFromRevisionID: parentCommitId
                                                   toRevisionID: lastCommitId];
        
        int i = itemChangedAtCommit(rev);
        COItem *item = [tree itemForUUID: childUUIDs[i]];
        
        NSString *expectedLabel = [self labelForCommit: rev child: i];
        
        UKObjectsEqual(expectedLabel,
                       [item valueForAttribute: @"name"]);
              
        // Step back one revision
        
        lastCommitId = parentCommitId;
    }
    
    NSLog(@"reading back %d deltas which touched 1 item each of a %d-item persistent root took %lf ms",
          NUM_COMMITS, NUM_CHILDREN, 1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}

- (void) testReloadFullStates
{
    COItemGraph *initialTree = [self makeInitialItemTree];
    ETUUID *prootUUID = [self makeDemoPersistentRoot];
    
    NSDate *startDate = [NSDate date];

    COPersistentRootInfo *proot = [store persistentRootInfoForUUID: prootUUID];
    
    CORevisionID *lastCommitId = [[proot currentBranchInfo] currentRevisionID];
    
    for (int rev=NUM_COMMITS-1; rev>=0; rev--)
    {
        COItemGraph *tree = [store itemGraphForRevisionID: lastCommitId];
        
        // Check the state
        UKObjectsEqual(rootUUID, [tree rootItemUUID]);
		
		// TODO: Should be UKObjectsEqual - UnitKit has performance problems
		// cause by generating output messages that are never displayed
        assert([[initialTree itemForUUID: rootUUID] isEqual:
                       [tree itemForUUID: rootUUID]]);
        
        for (int i=0; i<NUM_CHILDREN; i++)
        {
            // on rev=NUM_CHILDREN, child[NUM_CHILDREN - 1]'s name was changed
            
            NSString *expectedLabel = [self labelForCommit: rev child: i];
            
            assert([expectedLabel isEqualToString:
                           [[tree itemForUUID: childUUIDs[i]] valueForAttribute: @"name"]]);
        }
        
        // Step back one revision
        
        lastCommitId = [[store revisionInfoForRevisionID: lastCommitId] parentRevisionID];
    }
    
    NSLog(@"reading back %d full snapshots of a %d-item persistent root took %lf ms",
          MIN(25, NUM_COMMITS), NUM_CHILDREN, 1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);

}

- (void) testFTS
{
    ETUUID *prootUUID = [self makeDemoPersistentRoot];
    COPersistentRootInfo *proot = [store persistentRootInfoForUUID: prootUUID];
    
    int itemIndex = itemChangedAtCommit(32);
    
    NSDate *startDate = [NSDate date];
    
    NSArray *results = [store revisionIDsMatchingQuery: [NSString stringWithFormat: @"\"modified %d in commit 32\"",
                                                         itemIndex]];
    
    NSLog(@"FTS took %lf ms", 1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
    
    UKTrue([results count] == 1);
    if ([results count] == 1)
    {
        CORevisionID *revid = [results objectAtIndex: 0];
        UKObjectsEqual([proot UUID], revid.revisionPersistentRootUUID);
        UKObjectsEqual([revisionIDs objectAtIndex: 32], revid);
    }
}


- (void)testLotsOfPersistentRoots
{
    COItemGraph *it = [self makeItemTreeWithChildCount: NUM_CHILDREN_PER_PERSISTENT_ROOT];
    
    NSDate *startDate = [NSDate date];
    
    [store beginTransactionWithError: NULL];
    for (int i =0; i<NUM_PERSISTENT_ROOTS; i++)
    {
		[store createPersistentRootWithInitialItemGraph: it
                                                  UUID: [ETUUID UUID]
                                            branchUUID: [ETUUID UUID]
                                              revisionMetadata: nil
                                                 error: NULL];
    }
    [store commitTransactionWithError: NULL];
    
    UKPass();
    NSLog(@"creating %d persistent roots each containing a %d-item tree took %lf ms", NUM_PERSISTENT_ROOTS,
          NUM_CHILDREN_PER_PERSISTENT_ROOT, 1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}

- (void)testLotsOfPersistentRootCopies
{
    NSDate *startDate = [NSDate date];
    
    COItemGraph *it = [self makeItemTreeWithChildCount: NUM_CHILDREN_PER_PERSISTENT_ROOT];

    [store beginTransactionWithError: NULL];
    COPersistentRootInfo *proot = [store createPersistentRootWithInitialItemGraph: it
                                                                            UUID: [ETUUID UUID]
                                                                      branchUUID: [ETUUID UUID]
                                                                        revisionMetadata: nil
                                                                           error: NULL];
    
    for (int i =0; i<NUM_PERSISTENT_ROOT_COPIES; i++)
    {
        [store createPersistentRootWithInitialRevision: [[proot currentBranchInfo] currentRevisionID]
                                                  UUID: [ETUUID UUID]
                                            branchUUID: [ETUUID UUID]
									  parentBranchUUID:	nil
                                                 error: NULL];
    }
    [store commitTransactionWithError: NULL];
    
    UKPass();
    NSLog(@"creating %d persistent root copies took %lf ms", NUM_PERSISTENT_ROOT_COPIES,
          1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}


- (void) testMakeBigItemTree
{
    // 1. create in-memory tree
    
    NSDate *startDate = [NSDate date];

    COItemGraph *it = [self makeItemTreeWithChildCount: LOTS_OF_EMBEDDED_ITEMS];
    
    NSLog(@"creating %d item itemtree took %lf ms", LOTS_OF_EMBEDDED_ITEMS,
          1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
    
    // 2. commit it
    
    startDate = [NSDate date];
    
    [store beginTransactionWithError: NULL];
    COPersistentRootInfo *proot = [store createPersistentRootWithInitialItemGraph: it
                                                                            UUID: [ETUUID UUID]
                                                                      branchUUID: [ETUUID UUID]
                                                                        revisionMetadata: nil
                                                                           error: NULL];
    [store commitTransactionWithError: NULL];
    
    NSLog(@"committing %d item itemtree took %lf ms", LOTS_OF_EMBEDDED_ITEMS,
          1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);

    // 3. read it back
    
    startDate = [NSDate date];
    
    COItemGraph *readBack = [store itemGraphForRevisionID: [[proot currentBranchInfo] currentRevisionID]];
    
    NSLog(@"reading %d item itemtree took %lf ms", (int)[[readBack itemUUIDs] count],
          1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}

@end
