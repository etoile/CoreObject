/*
    Copyright (C) 2014 Quentin Mathé

    Date:  February 2024
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestRevisionMigration : EditingContextTestCase <UKTest>
{
    COEditingContext *migrationCtx;
}

@end

@interface COBranch (PreviousRevision)
- (void)moveToPreviousRevision;
@end

COItemGraph *(^handler)(COItemGraph *, int64_t, int64_t) = ^COItemGraph *(COItemGraph *oldItemGraph, int64_t oldVersion, int64_t newVersion) {
    NSMutableArray *newItems = [NSMutableArray array];

    for (COItem *oldItem in oldItemGraph.items)
    {
        // Check items migrated in prior revisions don't leak into the old item graph
        UKIntsEqual(oldVersion, oldItem.packageVersion);

        COMutableItem *newItem = [oldItem mutableCopy];
        BOOL isParent = ![[newItem valueForAttribute: @"contents"] isEmpty];
        
        newItem.packageVersion = newVersion;
        if (isParent)
        {
            [newItem setValue: @"New York" forAttribute: @"city" type: kCOTypeString];
        }
        else
        {
            [newItem setValue: @"Chicago" forAttribute: @"city" type: kCOTypeString];
        }

        [newItems addObject: newItem];
    }

    return [[COItemGraph alloc] initWithItems: newItems
                                 rootItemUUID: oldItemGraph.rootItemUUID];
};

@implementation TestRevisionMigration

- (ETModelDescriptionRepository *)addingCityPropertyToModelDescriptionRepository: (int64_t)aVersion
{
    ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];
    CORegisterCoreObjectMetamodel(repo);

    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPropertyDescription *city = [ETPropertyDescription descriptionWithName: @"city"];

    city.type = [repo descriptionForName: @"NSString"];
    city.persistent = YES;
    
    repo.version = aVersion;
    outlineEntity.owner.version = aVersion;

    [outlineEntity addPropertyDescription: city];
    [repo addDescription: city];
    return [self validateModelDescriptionRepository: repo];
}

- (ETModelDescriptionRepository *)validateModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    NSMutableArray *warnings = [NSMutableArray new];
    [repo checkConstraints: warnings];
    ETAssert([warnings isEmpty]);
    return repo;
}

- (void)prepareNewMigrationContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    migrationCtx = [[COEditingContext alloc] initWithStore: ctx.store
                                modelDescriptionRepository: repo];
}

- (OutlineItem *)insertNewPersistentRoot
{
    OutlineItem *parent = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    OutlineItem *child = [[OutlineItem alloc] initWithObjectGraphContext: parent.objectGraphContext];
    
    child.label = @"Child";
    parent.label = @"Parent";
    parent.contents = @[child];
    
    return parent;
}

- (void)checkStoreMigratedToVersion: (int64_t)version
              forPersistentRootUUID: (ETUUID *)uuid
             expectingRevisionCount: (NSInteger)revCount
{
    NSArray<CORevisionInfo *> *revInfos =
        [ctx.store revisionInfosForBackingStoreOfPersistentRootUUID: uuid];
    
    UKIntsEqual(version, ctx.store.schemaVersion);
    for (CORevisionInfo *rev in revInfos)
    {
        UKIntsEqual(version, rev.schemaVersion);
        UKIntsEqual(version, rev.schemaVersion);
    }
    UKIntsEqual(revCount, revInfos.count);
}

- (void)testDefaultSchemaVersion
{
    UKIntsEqual(0, ctx.store.schemaVersion);
}

- (void)testSingleBranchInSinglePersistentRoot
{
    // Persistent root 1 - revid 0 (snapshot)
    CORevision *rev = nil;
    OutlineItem *parent = [self insertNewPersistentRoot];
    OutlineItem *child = parent.contents[0];

    [ctx commit];
    rev = [parent revision];

    UKFalse(parent.isShared);
    UKIntsEqual(0, ctx.store.schemaVersion);
    UKIntsEqual(0, rev.schemaVersion);
    
    // Persistent root 1 - revid 1
    parent.isShared = YES;
    parent.label = @"Parent";
    [ctx commit];
    rev = [parent revision];
    
    UKTrue(parent.isShared);
    UKIntsEqual(0, ctx.store.schemaVersion);
    UKIntsEqual(0, rev.schemaVersion);
    
    // Migration
    [ctx.store migrateRevisionsToVersion: 1
                             withHandler: handler];

    [self checkStoreMigratedToVersion: 1
                forPersistentRootUUID: parent.persistentRoot.UUID
               expectingRevisionCount: 2];
    
    // Persistent root 1 - revid 0
    COEditingContext *newCtx =
        [[COEditingContext alloc] initWithStore: ctx.store
                     modelDescriptionRepository: [self addingCityPropertyToModelDescriptionRepository: 1]];
    COObjectGraphContext *newGraph =
        [newCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    OutlineItem *newParent = [newGraph loadedObjectForUUID: parent.UUID];
    OutlineItem *newChild = [newGraph loadedObjectForUUID: child.UUID];
    
    UKTrue(newParent.isShared);
    UKStringsEqual(@"Parent", newParent.label);
    UKStringsEqual(@"New York", [newParent valueForProperty: @"city"]);
    UKFalse(newChild.isShared);
    UKStringsEqual(@"Child", newChild.label);
    UKStringsEqual(@"Chicago", [newChild valueForProperty: @"city"]);
    
    // Persistent root 1 - revid 1
    [newParent.branch moveToPreviousRevision];

    UKFalse(newParent.isShared);
    UKStringsEqual(@"Parent", newParent.label);
    UKStringsEqual(@"New York", [newParent valueForProperty: @"city"]);
    UKFalse(newChild.isShared);
    UKStringsEqual(@"Child", newChild.label);
    UKStringsEqual(@"Chicago", [newChild valueForProperty: @"city"]);
}

- (void)testSingleBranchInMultiplePersistentRoots
{

    // Persistent root 1 - revid 0 (snapshot)
    OutlineItem *parent1 = [self insertNewPersistentRoot];
    OutlineItem *child1 = parent1.contents[0];
    parent1.label = @"Parent (1)";
    [ctx commit];

    // Persistent root 1 - revid 1
    parent1.isShared = YES;
    [ctx commit];
    
    // Persistent root 2 - revid 2 (snapshot)
    OutlineItem *parent2 = [self insertNewPersistentRoot];
    OutlineItem *child2 = parent2.contents[0];
    parent2.label = @"Parent (2)";
    parent2.isShared = YES;
    [ctx commit];
        
    // Persistent root 2 - revid 3
    child2.isShared = YES;
    [ctx commit];
    
    // Persistent root 1 - revid 4
    parent1.isShared = NO;
    [ctx commit];
    
    // Migration
    [ctx.store migrateRevisionsToVersion: 1
                             withHandler: handler];
    
    [self checkStoreMigratedToVersion: 1
                forPersistentRootUUID: parent1.persistentRoot.UUID
               expectingRevisionCount: 3];
    [self checkStoreMigratedToVersion: 1
                forPersistentRootUUID: parent2.persistentRoot.UUID
               expectingRevisionCount: 2];
    
    COEditingContext *newCtx =
        [[COEditingContext alloc] initWithStore: ctx.store
                     modelDescriptionRepository: [self addingCityPropertyToModelDescriptionRepository: 1]];
    
    // Persistent Root 1 - revid 4
    COObjectGraphContext *newGraph1 =
        [newCtx persistentRootForUUID: parent1.persistentRoot.UUID].objectGraphContext;
    OutlineItem *newParent1 = [newGraph1 loadedObjectForUUID: parent1.UUID];
    OutlineItem *newChild1 = [newGraph1 loadedObjectForUUID: child1.UUID];
    
    UKFalse(newParent1.isShared);
    UKFalse(newChild1.isShared);
    
    // Persistent Root 1 - revid 1
    [newParent1.branch moveToPreviousRevision];

    UKTrue(newParent1.isShared);
    UKFalse(newChild1.isShared);
    
    // Persistent Root 1 - revid 0
    [newParent1.branch moveToPreviousRevision];

    UKFalse(newParent1.isShared);
    UKFalse(newChild1.isShared);
    
    // Persistent Root 2 - revid 3
    COObjectGraphContext *newGraph2 =
        [newCtx persistentRootForUUID: parent2.persistentRoot.UUID].objectGraphContext;
    OutlineItem *newParent2 = [newGraph2 loadedObjectForUUID: parent2.UUID];
    OutlineItem *newChild2 = [newGraph2 loadedObjectForUUID: child2.UUID];
    
    UKTrue(newParent2.isShared);
    UKTrue(newChild2.isShared);
    
    // Persistent Root 2 - revid 2
    [newParent2.branch moveToPreviousRevision];

    UKTrue(newParent2.isShared);
    UKFalse(newChild2.isShared);
    
}

@end


@implementation COBranch (PreviousRevision)

- (void)moveToPreviousRevision
{
    self.currentNode = [self nextNodeOnTrackFrom: self.currentNode backwards: YES];
}

@end
