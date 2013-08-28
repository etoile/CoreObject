#import "TestCommon.h"
#import "COItem.h"
#import "COPath.h"
#import "COSearchResult.h"


@interface TestSQLiteStoreMultiPersistentRoots : COSQLiteStoreTestCase <UKTest>
{
    COPersistentRootInfo *docProot;
    COPersistentRootInfo *tagProot;
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
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: tagUUID] autorelease];
    [rootItem setValue: @"favourites" forAttribute: @"name" type: kCOTypeString];
    [rootItem setValue: S([COPath pathWithPersistentRoot: aUUID])
          forAttribute: @"taggedDocuments"
                  type: kCOTypeReference | kCOTypeSet];

    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (COItemGraph *) docItemTree
{
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: docUUID] autorelease];
    [rootItem setValue: @"my document" forAttribute: @"name" type: kCOTypeString];
    
    return [COItemGraph itemGraphWithItemsRootFirst: A(rootItem)];
}

- (id) init
{
    SUPERINIT;
    
    ASSIGN(docProot, [store createPersistentRootWithInitialItemGraph: [self docItemTree]
                                                               UUID: [ETUUID UUID]
                                                         branchUUID: [ETUUID UUID]
                                                           revisionMetadata: nil
                                                              error: NULL]);
    
    ASSIGN(tagProot, [store createPersistentRootWithInitialItemGraph: [self tagItemTreeWithDocProoUUID: [docProot UUID]]
                                                               UUID: [ETUUID UUID]
                                                         branchUUID: [ETUUID UUID]
                                                           revisionMetadata: nil
                                                              error: NULL]);
    return self;
}

- (void) dealloc
{
    [tagProot release];
    [docProot release];
    [super dealloc];
}

- (void) testSearch
{
    NSArray *results = [store referencesToPersistentRoot: [docProot UUID]];
    
    COSearchResult *result = [results objectAtIndex: 0];
    UKObjectsEqual([[tagProot currentBranchInfo] currentRevisionID], [result revision]);
    UKObjectsEqual(tagUUID, [result embeddedObjectUUID]);
}

- (void) testDeletion
{
    UKTrue([store deletePersistentRoot: [docProot UUID]
                                 error: NULL]);
    UKTrue([store finalizeDeletionsForPersistentRoot: [docProot UUID]
                                               error: NULL]);
    
    UKNil([store itemGraphForRevisionID: [[docProot currentBranchInfo] currentRevisionID]]);    
}

@end
