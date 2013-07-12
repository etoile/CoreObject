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
    [rootItem setValue: @"favourites" forAttribute: @"name" type: kCOStringType];
    [rootItem setValue: S([COPath pathWithPersistentRoot: aUUID])
          forAttribute: @"taggedDocuments"
                  type: kCOReferenceType | kCOSetType];

    return [COItemGraph treeWithItemsRootFirst: A(rootItem)];
}

- (COItemGraph *) docItemTree
{
    COMutableItem *rootItem = [[[COMutableItem alloc] initWithUUID: tagUUID] autorelease];
    [rootItem setValue: @"my document" forAttribute: @"name" type: kCOStringType];
    
    return [COItemGraph treeWithItemsRootFirst: A(rootItem)];
}

- (id) init
{
    SUPERINIT;
    
    ASSIGN(docProot, [store createPersistentRootWithInitialContents: [self docItemTree]
                                                         metadata: nil]);
    ASSIGN(tagProot, [store createPersistentRootWithInitialContents: [self tagItemTreeWithDocProoUUID: [docProot UUID]]
                                                         metadata: nil]);
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
    UKObjectsEqual([[tagProot mainBranchInfo] currentRevisionID], [result revision]);
    UKObjectsEqual(tagUUID, [result embeddedObjectUUID]);
}

@end
