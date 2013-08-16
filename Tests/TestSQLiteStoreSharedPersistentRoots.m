#import "TestCommon.h"
#import "COItem.h"
#import "COPath.h"
#import "COSearchResult.h"

/**
 * Tests two persistent roots sharing the same backing store behave correctly
 */
@interface TestSQLiteStoreSharedPersistentRoots : COSQLiteStoreTestCase <UKTest>
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
    [rootItem setValue: @"prootB" forAttribute: @"name" type: kCOStringType];
    
    return [COItemGraph treeWithItemsRootFirst: A(rootItem)];
}

- (COItemGraph *) prootAitemTree
{
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: rootUUID] autorelease];
    [rootItem setValue: @"prootA" forAttribute: @"name" type: kCOStringType];
    
    return [COItemGraph treeWithItemsRootFirst: A(rootItem)];
}

- (id) init
{
    SUPERINIT;
    
    ASSIGN(prootA, [store createPersistentRootWithInitialContents: [self prootAitemTree]
                                                               UUID: [ETUUID UUID]
                                                         branchUUID: [ETUUID UUID]
                                                           metadata: nil
                                                              error: NULL]);
    prootAchangeCount = [prootA changeCount];
    
    ASSIGN(prootB, [store createPersistentRootWithInitialRevision: [[prootA currentBranchInfo] currentRevisionID]
                                                             UUID: [ETUUID UUID]
                                                       branchUUID: [ETUUID UUID]
                                                         metadata: nil
                                                            error: NULL]);

    prootBchangeCount = [prootB changeCount];
    
    CORevisionID *prootBRev = [store writeContents: [self prooBitemTree] withMetadata: nil parentRevisionID: [[prootA currentBranchInfo] currentRevisionID] modifiedItems: A(rootUUID) error: NULL];

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
    
    UKObjectsEqual([self prootAitemTree], [store contentsForRevisionID: [prootA currentRevisionID]]);
    UKObjectsEqual([self prooBitemTree], [store contentsForRevisionID: [prootB currentRevisionID]]);
}

@end
