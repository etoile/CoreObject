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

- (OutlineItem *)prepareContext
{
    OutlineItem *parent = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    OutlineItem *child = [[OutlineItem alloc] initWithObjectGraphContext: parent.objectGraphContext];
    
    child.label = @"Child";
    parent.label = @"Parent";
    parent.contents = @[child];
    
    return parent;
}

- (void)testDefaultSchemaVersion
{
    UKIntsEqual(0, ctx.store.schemaVersion);
}

- (void)testSinglePersistentRoot
{
    // Snapshot commit (before migration)
    CORevision *rev = nil;
    OutlineItem *parent = [self prepareContext];
    OutlineItem *child = parent.contents[0];

    [ctx commit];
    rev = [parent revision];

    UKFalse(parent.isShared);
    UKIntsEqual(0, ctx.store.schemaVersion);
    UKIntsEqual(0, rev.schemaVersion);
    
    // Delta commit (before migration)
    parent.isShared = YES;
    parent.label = @"Parent";
    [ctx commit];
    rev = [parent revision];
    
    UKTrue(parent.isShared);
    UKIntsEqual(0, ctx.store.schemaVersion);
    UKIntsEqual(0, rev.schemaVersion);
    
    // Migration
    [ctx.store migrateRevisionsToVersion: 1
                             withHandler: ^COItemGraph *(COItemGraph *oldItemGraph, int64_t oldVersion, int64_t newVersion) {
        NSMutableArray *newItems = [NSMutableArray array];

        for (COItem *oldItem in oldItemGraph.items)
        {
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
    }];
    
    NSArray<CORevisionInfo *> *revInfos = 
        [ctx.store revisionInfosForBranchUUID: parent.branch.UUID
                                      options: COBranchRevisionReadingDefault];
    
    UKIntsEqual(1, ctx.store.schemaVersion);
    UKIntsEqual(1, revInfos[0].schemaVersion);
    UKIntsEqual(1, revInfos[1].schemaVersion);
    UKIntsEqual(2, revInfos.count);
    
    // Delta commit (after migration)
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
    
    // Snapshot commit (after migration)
    [newParent.branch setCurrentRevision: newParent.branch.firstRevision];

    UKFalse(newParent.isShared);
    UKStringsEqual(@"Parent", newParent.label);
    UKStringsEqual(@"New York", [newParent valueForProperty: @"city"]);
    UKFalse(newChild.isShared);
    UKStringsEqual(@"Child", newChild.label);
    UKStringsEqual(@"Chicago", [newChild valueForProperty: @"city"]);
}

@end
