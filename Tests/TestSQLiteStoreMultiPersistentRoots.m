#import "TestCommon.h"
#import "COItem.h"
#import "COPath.h"
#import "COSearchResult.h"


@interface TestSQLiteStoreMultiPersistentRoots : SQLiteStoreTestCase <UKTest>
{
    COPersistentRootInfo *docProot;
    COPersistentRootInfo *tagProot;
	int64_t docProotChangeCount;
	int64_t tagProotChangeCount;
}
@end

@implementation TestSQLiteStoreMultiPersistentRoots

// Embdedded item UUIDs
static ETUUID *docUUID;
static ETUUID *tagUUID;

+ (void) initialize
{
    if (self == [TestSQLiteStoreMultiPersistentRoots class])
    {
        docUUID = [[ETUUID alloc] init];
        tagUUID = [[ETUUID alloc] init];
    }
}

- (COItemGraph *) tagItemTreeWithDocProoUUID: (ETUUID*)aUUID
{
    COMutableItem *rootItem = [[COMutableItem alloc] initWithUUID: tagUUID];
    [rootItem setValue: @"favourites" forAttribute: @"name" type: kCOTypeString];
    [rootItem setValue: S([COPath pathWithPersistentRoot: aUUID])
          forAttribute: @"taggedDocuments"
                  type: kCOTypeReference | kCOTypeSet];

    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (COItemGraph *) docItemTree
{
    COMutableItem *rootItem = [[COMutableItem alloc] initWithUUID: docUUID];
    [rootItem setValue: @"my document" forAttribute: @"name" type: kCOTypeString];
    
    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (id) init
{
    SUPERINIT;
    
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    docProot = [txn createPersistentRootWithInitialItemGraph: [self docItemTree]
														UUID: [ETUUID UUID]
												  branchUUID: [ETUUID UUID]
											revisionMetadata: nil];
    
    tagProot = [txn createPersistentRootWithInitialItemGraph: [self tagItemTreeWithDocProoUUID: [docProot UUID]]
														UUID: [ETUUID UUID]
												  branchUUID: [ETUUID UUID]
											revisionMetadata: nil];
	docProotChangeCount = [txn setOldTransactionID: -1 forPersistentRoot: [docProot UUID]];
	tagProotChangeCount = [txn setOldTransactionID: -1 forPersistentRoot: [tagProot UUID]];

    UKTrue([store commitStoreTransaction: txn]);
    
    return self;
}


- (void) testSearch
{
    NSArray *results = [store referencesToPersistentRoot: [docProot UUID]];
    
    COSearchResult *result = [results objectAtIndex: 0];
    UKObjectsEqual([[tagProot currentBranchInfo] currentRevisionID], [result revision]);
    UKObjectsEqual(tagUUID, [result innerObjectUUID]);
}

- (void) testDeletion
{
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
	[txn deletePersistentRoot: [docProot UUID]];
	docProotChangeCount = [txn setOldTransactionID: docProotChangeCount forPersistentRoot: [docProot UUID]];
	UKTrue([store commitStoreTransaction: txn]);
    
    UKTrue([store finalizeDeletionsForPersistentRoot: [docProot UUID]
                                               error: NULL]);
    
    UKNil([store itemGraphForRevisionUUID: [[docProot currentBranchInfo] currentRevisionUUID] persistentRoot: [docProot UUID]]);
}

@end
