#import "TestCommon.h"
#import "COItem.h"
#import "COPath.h"
#import "COSearchResult.h"

/**
 * Tests two persistent roots sharing the same backing store behave correctly
 */
@interface TestSQLiteStoreSharedPersistentRoots : SQLiteStoreTestCase <UKTest>
{
    COPersistentRootInfo *prootA;
    COPersistentRootInfo *prootB;
}
@end

@implementation TestSQLiteStoreSharedPersistentRoots

// Embdedded item UUIDs
static ETUUID *rootUUID;

+ (void) initialize
{
    if (self == [TestSQLiteStoreSharedPersistentRoots class])
    {
        rootUUID = [[ETUUID alloc] init];
    }
}

- (COItemGraph *) prooBitemTree
{
    COMutableItem *rootItem = [[COMutableItem alloc] initWithUUID: rootUUID];
    [rootItem setValue: @"prootB" forAttribute: @"name" type: kCOTypeString];
    
    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (COItemGraph *) prootAitemTree
{
    COMutableItem *rootItem = [[COMutableItem alloc] initWithUUID: rootUUID];
    [rootItem setValue: @"prootA" forAttribute: @"name" type: kCOTypeString];
    
    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (id) init
{
    SUPERINIT;
    
    [store beginTransactionWithError: NULL];
    prootA = [store createPersistentRootWithInitialItemGraph: [self prootAitemTree]
                                                               UUID: [ETUUID UUID]
                                                         branchUUID: [ETUUID UUID]
                                                           revisionMetadata: nil
                                                              error: NULL];

	ETUUID *prootBBranchUUID = [ETUUID UUID];
    prootB = [store createPersistentRootWithInitialRevision: [[prootA currentBranchInfo] currentRevisionID]
                                                             UUID: [ETUUID UUID]
                                                       branchUUID: [ETUUID UUID]
                                                            error: NULL];
    
    CORevisionID *prootBRev = [store writeRevisionWithItemGraph: [self prooBitemTree]
                                                       metadata: nil
                                               parentRevisionID: [[prootA currentBranchInfo] currentRevisionID]
                                          mergeParentRevisionID: nil
	                                                 branchUUID: prootBBranchUUID
                                                  modifiedItems: A(rootUUID)
                                                          error: NULL];

    [store setCurrentRevision: prootBRev
	             tailRevision: nil
	                forBranch: [prootB currentBranchUUID]
	         ofPersistentRoot: [prootB UUID]
	                    error: NULL];

    prootB =  [store persistentRootInfoForUUID: [prootB UUID]];
    
    [store commitTransactionWithError: NULL];
    
    return self;
}


- (void) testBasic
{
    UKNotNil(prootA);
    UKNotNil(prootB);
    
    CORevisionInfo *prootARevInfo = [store revisionInfoForRevisionID: [prootA currentRevisionID]];
    CORevisionInfo *prootBRevInfo = [store revisionInfoForRevisionID: [prootB currentRevisionID]];
    
    UKNotNil(prootARevInfo);
    UKNotNil(prootBRevInfo);
    
    UKObjectsNotEqual([prootARevInfo revisionID], [prootBRevInfo revisionID]);
    UKObjectsEqual([prootARevInfo revisionID], [prootBRevInfo parentRevisionID]);
    
    UKObjectsEqual([self prootAitemTree], [store itemGraphForRevisionID: [prootA currentRevisionID]]);
    UKObjectsEqual([self prooBitemTree], [store itemGraphForRevisionID: [prootB currentRevisionID]]);
}

- (void) testDeleteOriginalPersistentRoot
{
    [store beginTransactionWithError: NULL];
    UKTrue([store deletePersistentRoot: [prootA UUID] error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKTrue([store finalizeDeletionsForPersistentRoot: [prootA UUID] error: NULL]);

    UKNil([store persistentRootInfoForUUID: [prootA UUID]]);
    
    // prootB should be unaffected. Both commits should be accessible.
    
    UKNotNil([store persistentRootInfoForUUID: [prootB UUID]]);

    UKObjectsEqual([self prootAitemTree], [store itemGraphForRevisionID: [prootA currentRevisionID]]);
    UKObjectsEqual([self prooBitemTree], [store itemGraphForRevisionID: [prootB currentRevisionID]]);
}

- (void) testDeleteCopiedPersistentRoot
{
    [store beginTransactionWithError: NULL];
    UKTrue([store deletePersistentRoot: [prootB UUID] error: NULL]);
    [store commitTransactionWithError: NULL];
    
    UKTrue([store finalizeDeletionsForPersistentRoot: [prootB UUID] error: NULL]);
    
    UKNil([store persistentRootInfoForUUID: [prootB UUID]]);
    
    // prootA should be unaffected. Only the first commit should be accessible.
    
    UKNotNil([store persistentRootInfoForUUID: [prootA UUID]]);
    
    UKObjectsEqual([self prootAitemTree], [store itemGraphForRevisionID: [prootA currentRevisionID]]);
    UKNil([store itemGraphForRevisionID: [prootB currentRevisionID]]);
}

@end
