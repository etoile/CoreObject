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
	
	int64_t prootAChangeCount;
	int64_t prootBChangeCount;
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
    
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    prootA = [txn createPersistentRootWithInitialItemGraph: [self prootAitemTree]
													  UUID: [ETUUID UUID]
												branchUUID: [ETUUID UUID]
										  revisionMetadata: nil];

	ETUUID *prootBBranchUUID = [ETUUID UUID];
	
	prootB = [txn createPersistentRootCopyWithUUID: [ETUUID UUID]
						  parentPersistentRootUUID: [prootA UUID]
										branchUUID: [ETUUID UUID]
								  parentBranchUUID: nil
							   initialRevisionUUID: [prootA currentRevisionUUID]];
    
    ETUUID *prootBRev = [ETUUID UUID];
	
	[txn writeRevisionWithModifiedItems: [self prooBitemTree]
						   revisionUUID: prootBRev
							   metadata: nil
					   parentRevisionID: [prootA currentRevisionUUID]
				  mergeParentRevisionID: nil
					 persistentRootUUID: [prootB UUID]
							 branchUUID: prootBBranchUUID];

    [txn setCurrentRevision: prootBRev
				 headRevision: prootBRev
	                forBranch: [prootB currentBranchUUID]
	         ofPersistentRoot: [prootB UUID]];

    prootB.currentBranchInfo.currentRevisionUUID = prootBRev;
    
	prootAChangeCount = [txn setOldTransactionID: -1 forPersistentRoot: [prootA UUID]];
	prootBChangeCount = [txn setOldTransactionID: -1 forPersistentRoot: [prootB UUID]];
	
    UKTrue([store commitStoreTransaction: txn]);
	
    return self;
}


- (void) testBasic
{
    UKNotNil(prootA);
    UKNotNil(prootB);
    
    CORevisionInfo *prootARevInfo = [store revisionInfoForRevisionUUID: [prootA currentRevisionUUID] persistentRootUUID: [prootA UUID]];
    CORevisionInfo *prootBRevInfo = [store revisionInfoForRevisionUUID: [prootB currentRevisionUUID] persistentRootUUID: [prootB UUID]];
    
    UKNotNil(prootARevInfo);
    UKNotNil(prootBRevInfo);
    
    UKObjectsNotEqual([prootARevInfo revisionUUID], [prootBRevInfo revisionUUID]);
    UKObjectsEqual([prootARevInfo revisionUUID], [prootBRevInfo parentRevisionUUID]);
    
    UKObjectsEqual([self prootAitemTree], [self currentItemGraphForPersistentRoot: [prootA UUID]]);
    UKObjectsEqual([self prooBitemTree], [self currentItemGraphForPersistentRoot: [prootB UUID]]);
	
	NSDictionary *prootAAttrs = [store attributesForPersistentRootWithUUID: [prootA UUID]];
	NSDictionary *prootBAttrs = [store attributesForPersistentRootWithUUID: [prootB UUID]];
	
	// For the original (non cheap copy)
	
	UKIntsNotEqual(0, [prootAAttrs[COPersistentRootAttributeExportSize] longLongValue]);
	UKIntsNotEqual(0, [prootAAttrs[COPersistentRootAttributeUsedSize] longLongValue]);
	UKIntsEqual([prootAAttrs[COPersistentRootAttributeExportSize] longLongValue],
				[prootAAttrs[COPersistentRootAttributeUsedSize] longLongValue]);
	
	// For the cheap copy
	
	UKTrue([prootBAttrs[COPersistentRootAttributeUsedSize] longLongValue] <
		   [prootBAttrs[COPersistentRootAttributeExportSize] longLongValue]);
}

- (void) testDeleteOriginalPersistentRoot
{
	{
		COStoreTransaction *txn = [[COStoreTransaction alloc] init];
		[txn deletePersistentRoot: [prootA UUID]];
		prootAChangeCount = [txn setOldTransactionID: prootAChangeCount forPersistentRoot: [prootA UUID]];
		UKTrue([store commitStoreTransaction: txn]);
	}

    UKTrue([store finalizeDeletionsForPersistentRoot: [prootA UUID] error: NULL]);

    UKNil([store persistentRootInfoForUUID: [prootA UUID]]);
    
    // prootB should be unaffected. Both commits should be accessible.
    
    UKNotNil([store persistentRootInfoForUUID: [prootB UUID]]);

    UKObjectsEqual([self prootAitemTree], [store itemGraphForRevisionUUID: [prootA currentRevisionUUID] persistentRoot: [prootA UUID]]);
    UKObjectsEqual([self prooBitemTree], [store itemGraphForRevisionUUID: [prootB currentRevisionUUID] persistentRoot: [prootB UUID]]);
}

- (void) testDeleteCopiedPersistentRoot
{
	{
		COStoreTransaction *txn = [[COStoreTransaction alloc] init];
		[txn deletePersistentRoot: [prootB UUID]];
		prootBChangeCount = [txn setOldTransactionID: prootBChangeCount forPersistentRoot: [prootB UUID]];
		UKTrue([store commitStoreTransaction: txn]);
	}

    UKTrue([store finalizeDeletionsForPersistentRoot: [prootB UUID] error: NULL]);
    
    UKNil([store persistentRootInfoForUUID: [prootB UUID]]);
    
    // prootA should be unaffected. Only the first commit should be accessible.
    
    UKNotNil([store persistentRootInfoForUUID: [prootA UUID]]);
    
    UKObjectsEqual([self prootAitemTree], [store itemGraphForRevisionUUID: [prootA currentRevisionUUID] persistentRoot: [prootA UUID]]);
    UKNil([store itemGraphForRevisionUUID: [prootB currentRevisionUUID] persistentRoot: [prootB UUID]]);
}

@end
