/*
    Copyright (C) 2015 Eric Wasylishen
 
    Date:  September 2015
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "FMDatabaseAdditions.h"

#pragma mark MockStore -

@interface MockStore : NSObject

@property (nonatomic, readwrite, assign) NSUInteger maxNumberOfDeltaCommits;
@property (nonatomic, readwrite, strong) FMDatabase *database;

@end


@implementation MockStore

@synthesize maxNumberOfDeltaCommits, database;

- (instancetype)init
{
    SUPERINIT;
    self.maxNumberOfDeltaCommits = 4;
    // Create an in-memory DB. See https://www.sqlite.org/c3ref/open.html
    self.database = [FMDatabase databaseWithPath: @":memory:"];
    ETAssert([self.database open]);
    return self;
}

@end


#pragma mark COSQLiteStorePersistentRootBackingStore (Private) -


@interface COSQLiteStorePersistentRootBackingStore (Private)

- (NSString *)tableName;

@end


#pragma mark TestSQLiteBackingStore -


@interface TestSQLiteBackingStore : TestCase <UKTest>
{
    MockStore *store;
    ETUUID *prootUUID;
    ETUUID *branchUUID;
    COSQLiteStorePersistentRootBackingStore *backing;
    ETUUID *rootitemUUID;
    ETUUID *childitemUUID;
}

@end


@implementation TestSQLiteBackingStore


#pragma mark Sample Item Graph Creation -


- (COItem *)parentItem: (NSString *)name referenceChildren: (BOOL)addChildRefs
{
    COMutableItem *rootitem = [[COMutableItem alloc] initWithUUID: rootitemUUID];
    [rootitem setValue: name forAttribute: @"name" type: kCOTypeString];
    if (addChildRefs)
    {
        [rootitem setValue: @[childitemUUID]
              forAttribute: @"contents"
                      type: COTypeMakeArrayOf(kCOTypeCompositeReference)];
    }
    return rootitem;
}

- (COItem *)childItem: (NSString *)name
{
    COMutableItem *childitem = [[COMutableItem alloc] initWithUUID: childitemUUID];
    [childitem setValue: name forAttribute: @"name" type: kCOTypeString];
    return childitem;
}

- (COItemGraph *)graphWithParent: (NSString *)name
{
    return [[COItemGraph alloc] initWithItems: @[[self parentItem: name referenceChildren: NO]]
                                 rootItemUUID: rootitemUUID];
}

- (COItemGraph *)graphWithParent: (NSString *)name child: (NSString *)childlabel
{
    return [[COItemGraph alloc] initWithItems: @[[self parentItem: name referenceChildren: YES],
                                                 [self childItem: childlabel]]
                                 rootItemUUID: rootitemUUID];
}

- (COItemGraph *)graphWithChild: (NSString *)childlabel
{
    return [[COItemGraph alloc] initWithItems: @[[self childItem: childlabel]]
                                 rootItemUUID: rootitemUUID];
}


#pragma mark Test Methods -


- (instancetype)init
{
    SUPERINIT;
    store = [MockStore new];
    prootUUID = [ETUUID UUID];
    branchUUID = [ETUUID UUID];
    backing = [[COSQLiteStorePersistentRootBackingStore alloc] initWithPersistentRootUUID: prootUUID
                                                                                    store: (COSQLiteStore *)store
                                                                               useStoreDB: YES
                                                                                    error: NULL];
    rootitemUUID = [ETUUID UUID];
    childitemUUID = [ETUUID UUID];
    return self;
}

- (void)commitWithGraph: (COItemGraph *)graph parent: (int64_t)parentRevid
{
    ETUUID *revUUID = [ETUUID UUID];
    const BOOL ok = [backing writeItemGraph: graph
                               revisionUUID: revUUID
                               withMetadata: @{}
                                 withParent: parentRevid
                            withMergeParent: -1
                                 branchUUID: branchUUID
                         persistentrootUUID: prootUUID
                                      error: NULL];
    ETAssert(ok);
}

- (COItemGraph *)itemGraphForRevid: (int64_t)revid
{
    ETAssert(revid != -1);
    return [backing itemGraphForRevid: revid];
}

// FIXME: -rangeOfData:options:range: not on GNUstep
#ifndef GNUSTEP
- (BOOL)storeHasPassword
{
    NSData *passwordBytes = [@"password" dataUsingEncoding: NSUTF8StringEncoding];

    for (NSData *blob in [store.database arrayForQuery: [NSString stringWithFormat: @"SELECT contents FROM %@",
                                                                                    [backing tableName]]])
    {
        NSRange rangeOfPassword = [blob rangeOfData: passwordBytes
                                            options: 0
                                              range: NSMakeRange(0, blob.length)];
        if (rangeOfPassword.location != NSNotFound)
        {
            return YES;
        }
    }
    return NO;
}
#endif

- (void)testDeletion
{
    COItemGraph *rootgraph = [self graphWithParent: @"parent"];                         // revid 0
    COItemGraph *branch1_a = [self graphWithParent: @"parent 1_a" child: @"password!"]; // revid 1
    COItemGraph *branch2_a = [self graphWithParent: @"parent 2_a" child: @"child 2_a"]; // revid 2
    COItemGraph *branch1_b = [self graphWithParent: @"parent 1_b"];                     // revid 3

    [self commitWithGraph: rootgraph parent: -1];   // revid 0
    [self commitWithGraph: branch1_a parent: 0];    // revid 1
    [self commitWithGraph: branch2_a parent: 0];    // revid 2
    [self commitWithGraph: branch1_b parent: 1];    // revid 3

    UKObjectsEqual(rootgraph, [backing itemGraphForRevid: 0]);
    UKObjectsEqual(branch1_a, [backing itemGraphForRevid: 1]);
    UKObjectsEqual(branch2_a, [backing itemGraphForRevid: 2]);
    UKObjectsEqual(branch1_b, [backing itemGraphForRevid: 3]);

#ifndef GNUSTEP
    UKTrue([self storeHasPassword]);
#endif

    // now delete revid 1, to remove "password!" from the store

    [backing deleteRevids: INDEXSET(1)];
#ifndef GNUSTEP
    UKFalse([self storeHasPassword]);
#endif

    UKObjectsEqual(rootgraph, [backing itemGraphForRevid: 0]);
    UKNil([backing itemGraphForRevid: 1]);
    UKObjectsEqual(branch2_a, [backing itemGraphForRevid: 2]);
    UKObjectsEqual(branch1_b, [backing itemGraphForRevid: 3]);
}

- (void)testFullSave
{
    NSArray *graphs = @[[self graphWithParent: @"parent0"],
                        [self graphWithParent: @"parent1" child: @"child1"],
                        [self graphWithParent: @"parent2" child: @"child2"],
                        [self graphWithParent: @"parent3"],
                        [self graphWithParent: @"parent4"], // full save
                        [self graphWithParent: @"parent5" child: @"child5"],
                        [self graphWithParent: @"parent6"],
                        [self graphWithParent: @"parent7" child: @"child7"],
                        [self graphWithParent: @"parent8" child: @"child8"], // full save
                        [self graphWithParent: @"parent9"],
    ];

    for (int i = 0; i < graphs.count; i++)
    {
        [self commitWithGraph: graphs[i] parent: i - 1];
    }

    // check for delta commits and full saves
    UKIntsEqual(0, [backing deltabaseForRowid: 0]); // full save
    UKIntsEqual(0, [backing deltabaseForRowid: 1]);
    UKIntsEqual(0, [backing deltabaseForRowid: 2]);
    UKIntsEqual(0, [backing deltabaseForRowid: 3]);
    UKIntsEqual(4, [backing deltabaseForRowid: 4]); // full save
    UKIntsEqual(4, [backing deltabaseForRowid: 5]);
    UKIntsEqual(4, [backing deltabaseForRowid: 6]);
    UKIntsEqual(4, [backing deltabaseForRowid: 7]);
    UKIntsEqual(8, [backing deltabaseForRowid: 8]); // full save
    UKIntsEqual(8, [backing deltabaseForRowid: 9]);

    // check that the full saves don't have garbage in them.
    UKNotNil([[backing itemGraphForRevid: 3] itemForUUID: childitemUUID]);
    UKNil([[backing itemGraphForRevid: 4] itemForUUID: childitemUUID]);
}

@end
