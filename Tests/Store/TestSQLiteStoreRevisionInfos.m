/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  January 2014
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * Tests the store method -revisionInfosForBranchUUID:options:
 *
 * For each execution of a test method, the store is recreated and a persistent root
 * is created in -init with a single commit, with the contents returned by -makeInitialItemTree.
 *
 * TODO: Switch to the more complex history graph in TestHistoryInspection
 * See comments in TestHistoryInspection.
 */
@interface TestSQLiteStoreRevisionInfos : SQLiteStoreTestCase <UKTest>
@end


@implementation TestSQLiteStoreRevisionInfos

static ETUUID *rootItemUUID;
static ETUUID *r0, *r1, *r2, *r3, *r4, *r5, *r6;
static ETUUID *p1, *p2;
static ETUUID *b1A, *b1B, *b2A;

+ (void)initialize
{
    if (self == [TestSQLiteStoreRevisionInfos class])
    {
        rootItemUUID = [ETUUID new];
        r0 = [ETUUID new];
        r1 = [ETUUID new];
        r2 = [ETUUID new];
        r3 = [ETUUID new];
        r4 = [ETUUID new];
        r5 = [ETUUID new];
        r6 = [ETUUID new];
        p1 = [ETUUID new];
        p2 = [ETUUID new];
        b1A = [ETUUID new];
        b1B = [ETUUID new];
        b2A = [ETUUID new];
    }
}

/*

             ---[5]              )
            /                    }-- persistent root p1, branch b1B
           2-----3------[4]      )      (current revision: r2, head revision: r3)
          /
  0------1          }-- persistent root p1, branch b1A (current revision: r1)
   \
    ------------6   }-- persistent root p2, branch b2A (current revision: r6)

 */

- (COItemGraph *)itemGraphWithLabel: (NSString *)aLabel
{
    COMutableItem *rootItem = [[COMutableItem alloc] initWithUUID: rootItemUUID];
    [rootItem setValue: aLabel forAttribute: @"label" type: kCOTypeString];

    return [COItemGraph itemGraphWithItemsRootFirst: @[rootItem]];
}

- (instancetype)init
{
    SUPERINIT;

    COStoreTransaction *txn = [[COStoreTransaction alloc] init];

    [txn createPersistentRootCopyWithUUID: p1
                 parentPersistentRootUUID: nil
                               branchUUID: b1A
                         parentBranchUUID: nil
                      initialRevisionUUID: r0];
    [txn setCurrentRevision: r1 headRevision: r1 forBranch: b1A ofPersistentRoot: p1];
    [txn createBranchWithUUID: b1B parentBranch: b1A initialRevision: r2 forPersistentRoot: p1];
    [txn setCurrentRevision: r2 headRevision: r3 forBranch: b1B ofPersistentRoot: p1];
    [txn createPersistentRootCopyWithUUID: p2
                 parentPersistentRootUUID: p1
                               branchUUID: b2A
                         parentBranchUUID: b1A
                      initialRevisionUUID: r6];

    [txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"0"]
                           revisionUUID: r0
                               metadata: nil
                       parentRevisionID: nil
                  mergeParentRevisionID: nil
                     persistentRootUUID: p1
                             branchUUID: b1A
                          schemaVersion: 0];
    [txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"1"]
                           revisionUUID: r1
                               metadata: nil
                       parentRevisionID: r0
                  mergeParentRevisionID: nil
                     persistentRootUUID: p1
                             branchUUID: b1A
                          schemaVersion: 0];
    [txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"2"]
                           revisionUUID: r2
                               metadata: nil
                       parentRevisionID: r1
                  mergeParentRevisionID: nil
                     persistentRootUUID: p1
                             branchUUID: b1B
                          schemaVersion: 0];
    [txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"3"]
                           revisionUUID: r3
                               metadata: nil
                       parentRevisionID: r2
                  mergeParentRevisionID: nil
                     persistentRootUUID: p1
                             branchUUID: b1B
                          schemaVersion: 0];
    [txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"4"]
                           revisionUUID: r4
                               metadata: nil
                       parentRevisionID: r3
                  mergeParentRevisionID: nil
                     persistentRootUUID: p1
                             branchUUID: b1B
                          schemaVersion: 0];
    [txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"5"]
                           revisionUUID: r5
                               metadata: nil
                       parentRevisionID: r2
                  mergeParentRevisionID: nil
                     persistentRootUUID: p1
                             branchUUID: b1B
                          schemaVersion: 0];
    [txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"6"]
                           revisionUUID: r6
                               metadata: nil
                       parentRevisionID: r0
                  mergeParentRevisionID: nil
                     persistentRootUUID: p2
                             branchUUID: b2A
                          schemaVersion: 0];

    ETAssert([store commitStoreTransaction: txn]);

    return self;
}

static NSArray *
RevisionInfoUUIDs(NSArray *revInfos)
{
    return (NSArray *)((CORevisionInfo *)[revInfos mappedCollection]).revisionUUID;
}

#pragma mark - Tests

- (void)testRevisionInfosRevisionProperties
{
    NSArray *b1ARevInfos = [store revisionInfosForBranchUUID: b1A options: 0];

    for (CORevisionInfo *info in b1ARevInfos)
    {
        UKNotNil(info.date);
        UKTrue(fabs([info.date timeIntervalSinceNow]) < 1.0); /* Less than 1 second old */
        UKObjectsEqual(p1, info.persistentRootUUID);
        UKObjectsEqual(b1A, info.branchUUID);

        // TODO: Check other properties
    }
}

- (void)testRevisionInfosForBranchDefaultOptions
{
    NSArray *b1ARevInfos = [store revisionInfosForBranchUUID: b1A options: 0];
    NSArray *b1BRevInfos = [store revisionInfosForBranchUUID: b1B options: 0];
    NSArray *b2ARevInfos = [store revisionInfosForBranchUUID: b2A options: 0];

    UKObjectsEqual(A(r0, r1), RevisionInfoUUIDs(b1ARevInfos));
    UKObjectsEqual(A(r2, r3), RevisionInfoUUIDs(b1BRevInfos));
    UKObjectsEqual(A(r6), RevisionInfoUUIDs(b2ARevInfos));
}

- (void)testRevisionInfosForBranchWithParentBranchesOption
{
    NSArray *b1ARevInfos = [store revisionInfosForBranchUUID: b1A
                                                     options: COBranchRevisionReadingParentBranches];
    NSArray *b1BRevInfos = [store revisionInfosForBranchUUID: b1B
                                                     options: COBranchRevisionReadingParentBranches];
    NSArray *b2ARevInfos = [store revisionInfosForBranchUUID: b2A
                                                     options: COBranchRevisionReadingParentBranches];

    UKObjectsEqual(A(r0, r1), RevisionInfoUUIDs(b1ARevInfos));
    UKObjectsEqual(A(r0, r1, r2, r3), RevisionInfoUUIDs(b1BRevInfos));
    UKObjectsEqual(A(r0, r6), RevisionInfoUUIDs(b2ARevInfos));
}

- (void)testRevisionInfosForBranchWithDivergentRevisionsOption
{
    NSArray *b1ARevInfos = [store revisionInfosForBranchUUID: b1A
                                                     options: COBranchRevisionReadingDivergentRevisions];
    NSArray *b1BRevInfos = [store revisionInfosForBranchUUID: b1B
                                                     options: COBranchRevisionReadingDivergentRevisions];
    NSArray *b2ARevInfos = [store revisionInfosForBranchUUID: b2A
                                                     options: COBranchRevisionReadingDivergentRevisions];

    UKObjectsEqual(A(r0, r1), RevisionInfoUUIDs(b1ARevInfos));
    UKObjectsEqual(A(r2, r3, r4, r5), RevisionInfoUUIDs(b1BRevInfos));
    UKObjectsEqual(A(r6), RevisionInfoUUIDs(b2ARevInfos));
}

- (void)testRevisionInfosForBranchWithParentBranchesAndDivergentRevisionsOption
{
    NSArray *b1ARevInfos = [store revisionInfosForBranchUUID: b1A
                                                     options: COBranchRevisionReadingParentBranches | COBranchRevisionReadingDivergentRevisions];
    NSArray *b1BRevInfos = [store revisionInfosForBranchUUID: b1B
                                                     options: COBranchRevisionReadingParentBranches | COBranchRevisionReadingDivergentRevisions];
    NSArray *b2ARevInfos = [store revisionInfosForBranchUUID: b2A
                                                     options: COBranchRevisionReadingParentBranches | COBranchRevisionReadingDivergentRevisions];

    UKObjectsEqual(A(r0, r1), RevisionInfoUUIDs(b1ARevInfos));
    UKObjectsEqual(A(r0, r1, r2, r3, r4, r5), RevisionInfoUUIDs(b1BRevInfos));
    UKObjectsEqual(A(r0, r6), RevisionInfoUUIDs(b2ARevInfos));
}

- (void)testRevisionInfosForBackingStoreOfPersistentRootUUID
{
    UKObjectsEqual(A(r0, r1, r2, r3, r4, r5, r6),
                   RevisionInfoUUIDs([store revisionInfosForBackingStoreOfPersistentRootUUID: p1]));
    UKObjectsEqual(A(r0, r1, r2, r3, r4, r5, r6),
                   RevisionInfoUUIDs([store revisionInfosForBackingStoreOfPersistentRootUUID: p2]));
}

@end
