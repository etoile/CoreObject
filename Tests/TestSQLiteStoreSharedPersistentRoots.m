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
    
    int64_t prootAchangeCount;
    int64_t prootBchangeCount;
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
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: rootUUID] autorelease];
    [rootItem setValue: @"prootB" forAttribute: @"name" type: kCOTypeString];
    
    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (COItemGraph *) prootAitemTree
{
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: rootUUID] autorelease];
    [rootItem setValue: @"prootA" forAttribute: @"name" type: kCOTypeString];
    
    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (id) init
{
    SUPERINIT;
    
    ASSIGN(prootA, [store createPersistentRootWithInitialItemGraph: [self prootAitemTree]
                                                               UUID: [ETUUID UUID]
                                                         branchUUID: [ETUUID UUID]
                                                           revisionMetadata: nil
                                                              error: NULL]);
    prootAchangeCount = [prootA changeCount];
    
    ASSIGN(prootB, [store createPersistentRootWithInitialRevision: [[prootA currentBranchInfo] currentRevisionID]
                                                             UUID: [ETUUID UUID]
                                                       branchUUID: [ETUUID UUID]
                                                            error: NULL]);

    prootBchangeCount = [prootB changeCount];
    
    CORevisionID *prootBRev = [store writeRevisionWithItemGraph: [self prooBitemTree]
                                                       metadata: nil
                                               parentRevisionID: [[prootA currentBranchInfo] currentRevisionID]
                                          mergeParentRevisionID: nil
                                                  modifiedItems: A(rootUUID)
                                                          error: NULL];

    [store setCurrentRevision: prootBRev headRevision: prootBRev tailRevision: nil forBranch: [prootB currentBranchUUID] ofPersistentRoot: [prootB UUID] currentChangeCount: &prootBchangeCount error: NULL];

    ASSIGN(prootB, [store persistentRootInfoForUUID: [prootB UUID]]);
    
    return self;
}

- (void) dealloc
{
    [prootA release];
    [prootB release];
    [super dealloc];
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
    UKTrue([store deletePersistentRoot: [prootA UUID] error: NULL]);
    UKTrue([store finalizeDeletionsForPersistentRoot: [prootA UUID] error: NULL]);

    UKNil([store persistentRootInfoForUUID: [prootA UUID]]);
    
    // prootB should be unaffected. Both commits should be accessible.
    
    UKNotNil([store persistentRootInfoForUUID: [prootB UUID]]);

    UKObjectsEqual([self prootAitemTree], [store itemGraphForRevisionID: [prootA currentRevisionID]]);
    UKObjectsEqual([self prooBitemTree], [store itemGraphForRevisionID: [prootB currentRevisionID]]);
}

- (void) testDeleteCopiedPersistentRoot
{
    UKTrue([store deletePersistentRoot: [prootB UUID] error: NULL]);
    UKTrue([store finalizeDeletionsForPersistentRoot: [prootB UUID] error: NULL]);
    
    UKNil([store persistentRootInfoForUUID: [prootB UUID]]);
    
    // prootA should be unaffected. Only the first commit should be accessible.
    
    UKNotNil([store persistentRootInfoForUUID: [prootA UUID]]);
    
    UKObjectsEqual([self prootAitemTree], [store itemGraphForRevisionID: [prootA currentRevisionID]]);
    UKNil([store itemGraphForRevisionID: [prootB currentRevisionID]]);
}

@end
