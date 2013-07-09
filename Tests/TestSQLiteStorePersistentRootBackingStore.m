#import "TestCommon.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "COItem.h"
#import "CORevisionInfo.h"

@interface TestSQLiteStorePersistentRootBackingStore : NSObject <UKTest>
{
    COSQLiteStorePersistentRootBackingStore *store;
}
@end

@implementation TestSQLiteStorePersistentRootBackingStore

static ETUUID *rootUUID;
static ETUUID *childUUID1;
static ETUUID *childUUID2;

+ (void) initialize
{
    if (self == [TestSQLiteStorePersistentRootBackingStore class])
    {
        rootUUID = [[ETUUID alloc] init];
        childUUID1 = [[ETUUID alloc] init];
        childUUID2 = [[ETUUID alloc] init];
    }
}

// --- Example data setup

#define BRANCH_LENGTH 250

/*
 * The sample store will look like this
 *
 *  Fist commit
 *
 *    revid 0---------[ revid 1 through BRANCH_LENGTH ]  ("branch A")
 *           \
 *            \
 *             ------------[ revid (BRANCH_LENGTH + 1) through (2 * BRANCH_LENGTH) ] ("branch B")
 *
 * revid 0 through BRANCH_LENGTH will contain rootUUID and childUUID1.
 * revid (BRANCH_LENGTH + 1) through (2 * BRANCH_LENGTH) will contain rootUUID and childUUID2.
 */

- (COItem *) initialRootItemForChildren: (NSArray *)children
{
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: rootUUID] autorelease];
    [rootItem setValue: @"root" forAttribute: @"name" type: kCOStringType];
    [rootItem setValue: children
          forAttribute: @"children"
                  type: kCOCompositeReferenceType | kCOArrayType];
    return rootItem;
}

- (COItem *) initialChildItemForUUID: (ETUUID*)aUUID
                                name: (NSString *)name
{
    COMutableItem *child = [[[COMutableItem alloc] initWithUUID: aUUID] autorelease];
    [child setValue: name
       forAttribute: @"name"
               type: kCOStringType];
    return child;
}

- (COItemGraph*) makeInitialItemTree
{
    return [COItemGraph treeWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID1)],
                                                 [self initialChildItemForUUID: childUUID1 name: @"initial child"])];
}

- (COItemGraph*) makeBranchAItemTreeAtRevid: (int64_t)aRev
{
    NSString *name = [NSString stringWithFormat: @"child for commit %lld", (long long int)aRev];
    return [COItemGraph treeWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID1)],
                                                 [self initialChildItemForUUID: childUUID1 name: name])];
}

- (COItemGraph*) makeBranchBItemTreeAtRevid: (int64_t)aRev
{
    NSString *name = [NSString stringWithFormat: @"child for commit %lld", (long long int)aRev];
    return [COItemGraph treeWithItemsRootFirst: A([self initialRootItemForChildren: A(childUUID2)],
                                                 [self initialChildItemForUUID: childUUID2 name: name])];
}

- (COItemGraph *)itemTreeWithChildNameChange: (NSString*)aName
{
    COItemGraph *it = [self makeInitialItemTree];    
    COMutableItem *item = (COMutableItem *)[it itemForUUID: childUUID1];
    [item setValue: aName
      forAttribute: @"name"];
    return it;
}

- (NSDictionary *)initialMetadata
{
    return D(@"first commit", @"name");
}

- (NSDictionary *)branchAMetadata
{
    return D(@"branch A", @"name");
}

- (NSDictionary *)branchBMetadata
{
    return D(@"branch B", @"name");
}

- (void) setupExampleStore
{
    UKTrue([store beginTransaction]);
    
    // First commit
    
    int64_t revid0 = [store writeItemTree: [self makeInitialItemTree]
                             withMetadata: [self initialMetadata]
                               withParent: -1
                            modifiedItems: nil];
    UKIntsEqual(0, revid0);
    
    // Branch A
    
    for (int64_t i = 1; i<=BRANCH_LENGTH; i++)
    {
        int64_t revid = [store writeItemTree: [self makeBranchAItemTreeAtRevid: i]
                                withMetadata: [self branchAMetadata]
                                  withParent: i - 1
                               modifiedItems: A(childUUID1)];
        UKIntsEqual(i, revid);
    }
    
    // Branch B
    
    UKIntsEqual(BRANCH_LENGTH + 1, [store writeItemTree: [self makeBranchBItemTreeAtRevid: BRANCH_LENGTH + 1]
                                           withMetadata: [self branchBMetadata]
                                             withParent: 0 
                                          modifiedItems: A(rootUUID, childUUID2)]);
    
    for (int64_t i = (BRANCH_LENGTH + 2); i <= (2 * BRANCH_LENGTH); i++)
    {
        int64_t revid = [store writeItemTree: [self makeBranchBItemTreeAtRevid: i]
                                withMetadata: [self branchBMetadata]
                                  withParent: i - 1
                               modifiedItems: A(childUUID2)];
        UKIntsEqual(i, revid);
    }
    
    UKTrue([store commit]);
}

- (id) init
{
    SUPERINIT;
    
    [[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL];
    store = [[COSQLiteStorePersistentRootBackingStore alloc] initWithPath: [STORE_URL path]];
    
    return self;
}

- (void) dealloc
{
    [store release];
    [super dealloc];
}

// --- The tests themselves

- (CORevisionInfo *) revisionForRevid: (int64_t)revid
{
    return [store revisionForID: [CORevisionID revisionWithBackinStoreUUID: nil revisionIndex: revid]];
}

- (NSDictionary *) metadataForRevid: (int64_t)revid
{
    return [[self revisionForRevid: revid] metadata];
}

- (int64_t) parentForRevid: (int64_t)revid
{
    return [[[self revisionForRevid: revid] parentRevisionID] revisionIndex];
}

- (void) testMetadataForRevid
{
    UKNil([store revisionForID: 0]);
    
    [self setupExampleStore];
    
    UKObjectsEqual([self initialMetadata], [self metadataForRevid: 0]);
    
    for (int64_t i = 1; i<=BRANCH_LENGTH; i++)
    {
        UKObjectsEqual([self branchAMetadata], [self metadataForRevid: i]);
    }
    
    for (int64_t i = (BRANCH_LENGTH + 1); i <= (2 * BRANCH_LENGTH); i++)
    {
        UKObjectsEqual([self branchBMetadata], [self metadataForRevid: i]);
    }
}

- (void) testParentForRevid
{
    UKNil([self revisionForRevid: 0]);
    
    [self setupExampleStore];
    
    UKIntsEqual(-1, [self parentForRevid: 0]);
    
    for (int64_t i = 1; i<=BRANCH_LENGTH; i++)
    {
        UKIntsEqual(i - 1, [self parentForRevid: i]);
    }
    
    for (int64_t i = (BRANCH_LENGTH + 1); i <= (2 * BRANCH_LENGTH); i++)
    {
        UKIntsEqual(i == (BRANCH_LENGTH + 1) ? 0 : i - 1, [self parentForRevid: i]);
    }
}

- (void) testItemTreeForRevid
{
    UKNil([store itemTreeForRevid: 0]);
    
    [self setupExampleStore];
    
    UKObjectsEqual([self makeInitialItemTree], [store itemTreeForRevid: 0]);
    
    for (int64_t i = 1; i<=BRANCH_LENGTH; i++)
    {
        UKObjectsEqual([self makeBranchAItemTreeAtRevid: i], [store itemTreeForRevid: i]);
    }
    
    for (int64_t i = (BRANCH_LENGTH + 1); i <= (2 * BRANCH_LENGTH); i++)
    {
        UKObjectsEqual([self makeBranchBItemTreeAtRevid: i], [store itemTreeForRevid: i]);
    }
}

- (void) testPartialItemTree
{    
    UKNil([store partialItemTreeFromRevid: 0 toRevid: 1]);
    
    [self setupExampleStore];
    
    UKRaisesException([store partialItemTreeFromRevid: 2 toRevid: 1]);
    
    // The first commit on branch B to the second only modified childUUID2
    COItemGraph *tree = [store partialItemTreeFromRevid: BRANCH_LENGTH + 1
                                               toRevid: BRANCH_LENGTH + 2];
    
    UKObjectsEqual(A(childUUID2), [tree itemUUIDs]);
    UKObjectsEqual(rootUUID, [tree rootItemUUID]);
}

- (void) testRevids
{
    UKNil([store revidsFromRevid: 0 toRevid: 1]);
    
    [self setupExampleStore];
    
    UKRaisesException([store revidsFromRevid: 1 toRevid: 0]);
    
    UKObjectsEqual([NSIndexSet indexSetWithIndex: 0], [store revidsFromRevid: 0 toRevid: 0]);

    // Test the first few commits on branch A
    UKObjectsEqual([NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, 4)], [store revidsFromRevid: 0 toRevid: 3]);

    // Test the first few commts on branch B
    UKObjectsEqual(INDEXSET(0, BRANCH_LENGTH + 1, BRANCH_LENGTH + 2, BRANCH_LENGTH + 3),
                   [store revidsFromRevid: 0 toRevid: BRANCH_LENGTH + 3]);
}

- (void) testDeleteRevids
{
    [self setupExampleStore];
    
    UKObjectsEqual([self makeInitialItemTree], [store itemTreeForRevid: 0]);
    
    NSMutableIndexSet *toDelete = [NSMutableIndexSet indexSet];
    [toDelete addIndex: 0];
    [toDelete addIndexesInRange: NSMakeRange(1, 100)];
    [toDelete addIndexesInRange: NSMakeRange(BRANCH_LENGTH + 1, 100)];
    
    UKTrue([store deleteRevids: toDelete]);
    
    // NOTE: This test depends on the delta run length being less than 100
    UKNil([store itemTreeForRevid: 0]);
    
    // Verify that the remaining revisions are still correct
    
    for (int64_t i = 101; i<=BRANCH_LENGTH; i++)
    {
        UKObjectsEqual([self makeBranchAItemTreeAtRevid: i], [store itemTreeForRevid: i]);
    }
    
    for (int64_t i = (BRANCH_LENGTH + 101); i <= (2 * BRANCH_LENGTH); i++)
    {
        UKObjectsEqual([self makeBranchBItemTreeAtRevid: i], [store itemTreeForRevid: i]);
    }
}

@end
