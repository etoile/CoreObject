/*
    Copyright (C) 2014 Quentin Mathé

    Date:  December 2014
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface COSchemaMigration ()

+ (void)clearRegisteredMigrations;

@end


@interface OutlineNode : COContainer
@end


@interface TestSchemaMigration : EditingContextTestCase <UKTest>
{
    COEditingContext *migrationCtx;
    Tag *tag;
    OutlineItem *parent;
    OutlineItem *child;
}

@end


@implementation TestSchemaMigration

- (id)init
{
    [COSchemaMigration clearRegisteredMigrations];
    SUPERINIT;
    [self prepareNewContextWithModelDescriptionRepository: [ETModelDescriptionRepository mainRepository]];
    return self;
}

- (void)dealloc
{
    [COSchemaMigration clearRegisteredMigrations];
}

- (void)prepareNewContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    ctx = [[COEditingContext alloc] initWithStore: store
                       modelDescriptionRepository: repo];
    tag = [ctx insertNewPersistentRootWithEntityName: @"Tag"].rootObject;
    parent = [[OutlineItem alloc] initWithObjectGraphContext: tag.objectGraphContext];
    child = [[OutlineItem alloc] initWithObjectGraphContext: parent.objectGraphContext];
    tag.contents = S(parent);
    [parent addObject: child];
}

- (ETModelDescriptionRepository *)validateModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    NSMutableArray *warnings = [NSMutableArray new];
    [repo checkConstraints: warnings];
    ETAssert([warnings isEmpty]);
    return repo;
}

- (ETModelDescriptionRepository *)modelDescriptionRepositoryForDestinationVersions: (NSDictionary *)versionsByPackageName
{
    ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];
    CORegisterCoreObjectMetamodel(repo);

    for (NSString *package in versionsByPackageName)
    {
        ETPackageDescription *packageDesc = [repo descriptionForName: package];
        ETAssert(packageDesc != nil);

        packageDesc.version = [versionsByPackageName[package] longLongValue];
    }
    return repo;
}

- (void)prepareNewMigrationContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    migrationCtx = [[COEditingContext alloc] initWithStore: ctx.store
                                modelDescriptionRepository: repo];
}

- (void)prepareNewMigrationContextForDestinationVersions: (NSDictionary *)versionsByPackageName
{
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self modelDescriptionRepositoryForDestinationVersions: versionsByPackageName]];
}

- (void)prepareNewMigrationContextForDestinationVersion: (int64_t)version
{
    [self prepareNewMigrationContextForDestinationVersions: @{@"Test": @(version)}];
}

/**
 * Returns the package version for the given package of the object.
 * (using the object's model description repository)
 */
- (int64_t)checkObject: (COObject *)anObject versionForPackageName: (NSString *)aPackage
{
    COItem *item = anObject.storeItem;
    if ([item.packageName isEqual: aPackage])
    {
        /* Sanity check that the item package/version are in sync with the model
           description repository. */
        UKObjectsEqual(item.packageName, anObject.entityDescription.owner.name);
        UKIntsEqual(item.packageVersion, anObject.entityDescription.owner.version);

        return item.packageVersion;
    }

    for (ETPackageDescription *package in anObject.entityDescription.allPackageDescriptions)
    {
        if ([package.name isEqual: aPackage])
        {
            return package.version;
        }
    }

    return -1;
}

- (void)testItemVersionsFromSerialization
{
    [self checkObjectGraphBeforeAndAfterSerializationRoundtrip: parent.objectGraphContext
                                                       inBlock:
       ^(COObjectGraphContext *testGraph,
         id testRootObject,
         BOOL isObjectGraphCopy)
       {
           OutlineItem *newParent = ((Tag *)testRootObject).contents.anyObject;
           OutlineItem *newChild = [newParent.content firstObject];

           UKIntsEqual(0,
                       newParent.storeItem.packageVersion);
           UKIntsEqual(0,
                       newParent.entityDescription.parent.owner.version);
           UKIntsEqual(0,
                       newChild.storeItem.packageVersion);
           UKIntsEqual(0,
                       newChild.entityDescription.parent.owner.version);

           UKObjectsEqual(@"Test",
                          newParent.storeItem.packageName);
           UKObjectsEqual(@"Test",
                          newParent.entityDescription.owner.name);
           UKObjectsEqual(@"org.etoile-project.CoreObject",
                          newParent.entityDescription.parent.owner.name);
           UKObjectsEqual(@"Test",
                          newChild.storeItem.packageName);
           UKObjectsEqual(@"Test",
                          newChild.entityDescription.owner.name);
           UKObjectsEqual(@"org.etoile-project.CoreObject",
                          newChild.entityDescription.parent.owner.name);
       }];
}

- (COSchemaMigration *)registerMigrationWithVersion: (int64_t)version
                                        packageName: (NSString *)package
               dependentSourceVersionsByPackageName: (NSDictionary *)deps
                                              block: (COMigrationBlock)block
{
    COSchemaMigration *migration = [COSchemaMigration new];

    migration.packageName = package;
    migration.destinationVersion = version;
    migration.migrationBlock = block;
    migration.dependentSourceVersionsByPackageName = deps;

    [COSchemaMigration registerMigration: migration];
    return migration;
}

- (COSchemaMigration *)registerMigrationWithVersion: (int64_t)version
                                            package: (NSString *)package
{
    return [self registerMigrationWithVersion: version
                                  packageName: package
         dependentSourceVersionsByPackageName: @{}
                                        block: NULL];
}

- (COSchemaMigration *)registerMigrationWithTestPackageVersion: (int64_t)version
                                                         block: (COMigrationBlock)block
{
    // The Test package depends on the CoreObject package, v0
    return [self registerMigrationWithVersion: version
                                  packageName: @"Test"
         dependentSourceVersionsByPackageName: @{@"org.etoile-project.CoreObject": @(0)}
                                        block: block];
}

- (void)testSchemaMigrationRegistration
{
    COSchemaMigration *migration1 = [self registerMigrationWithVersion: 500 package: @"Test"];
    COSchemaMigration *migration2 = [self registerMigrationWithVersion: 501 package: @"Test"];
    COSchemaMigration *migration3 =
        [self registerMigrationWithVersion: 500 package: @"org.etoile-project.CoreObject"];

    UKObjectsEqual(migration1,
                   [COSchemaMigration migrationForPackageName: @"Test" destinationVersion: 500]);
    UKObjectsEqual(migration2,
                   [COSchemaMigration migrationForPackageName: @"Test" destinationVersion: 501]);
    UKObjectsEqual(migration3,
                   [COSchemaMigration migrationForPackageName: @"org.etoile-project.CoreObject"
                                           destinationVersion: 500]);
    UKNil([COSchemaMigration migrationForPackageName: @"org.etoile-project.CoreObject"
                                  destinationVersion: 501]);
}

- (void)testInsertOrUpdateItemsWithoutMigration
{
    COObjectGraphContext *context = parent.objectGraphContext;

    UKDoesNotRaiseException([context insertOrUpdateItems: [context items]]);
}

/*  - (void) testInsertOrUpdateItemsWithMigration
 COObject *newParent =
 [migrationCtx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
 
    [newParent]*/

- (void)testExceptionOnFutureSchemaVersion
{
    COMutableItem *parentItem = [parent.storeItem mutableCopy];

    UKObjectsEqual(@"Test", parentItem.packageName);
    parentItem.packageVersion = 1;

    UKRaisesException([parent.objectGraphContext insertOrUpdateItems: @[parentItem]]);
}

- (void)testExceptionOnNegativeSchemaVersion
{
    COMutableItem *parentItem = [parent.storeItem mutableCopy];

    // FIXME: -1 is used as a marker for "no version set", so I changed this test
    // to use -2 as an invalid version.
    UKObjectsEqual(@"Test", parentItem.packageName);
    parentItem.packageVersion = -2;

    UKRaisesException([parent.objectGraphContext insertOrUpdateItems: @[parentItem]]);
}

- (void)testExceptionOnMissingMigration
{
    ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];
    CORegisterCoreObjectMetamodel(repo);
    ETPackageDescription *testPackage = [repo descriptionForName: @"Test"];
    ETAssert(testPackage != nil);

    testPackage.version = 1;

    COMutableItem *childItem = [child.storeItem mutableCopy];
    COObjectGraphContext *migratedContext =
        [COObjectGraphContext objectGraphContextWithModelDescriptionRepository: repo];

    UKRaisesException([migratedContext insertOrUpdateItems: @[childItem]]);
}

- (void)testExceptionOnMigrationReturningItemsWithIncorrectVersion
{
    /* The missing migration block means the item versions won't be incremented */
    [self registerMigrationWithTestPackageVersion: 1 block: NULL];

    [ctx commit];
    // Will retain the current context store and never release it due to the exception
    // (the store is retained when passed in argument to COEditingContext initializer)
    UKRaisesException({
                          [self prepareNewMigrationContextForDestinationVersion: 1];
                          // Trigger persistent root loading
                          COTag *testTag = [[migrationCtx persistentRootForUUID: tag.persistentRoot.UUID] rootObject];
                      });
}

- (id)registerLabelUpdateMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                if ([newItem.packageName isEqual: migration.packageName])
                {
                    newItem.packageVersion = migration.destinationVersion;
                }

                if ([newItem.entityName isEqualToString: @"OutlineItem"])
                {
                    [newItem setValue: @"Untitled" forAttribute: @"label"];
                }
                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (void)testBasicMigrationWithoutMetamodelChanges
{
    COSchemaMigration *migration = [self registerLabelUpdateMigrationWithVersion: 1];

    tag.name = @"Vista";

    [ctx commit];
    [self prepareNewMigrationContextForDestinationVersion: 1];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    /* When some properties are not migrated while others are, we must not lose
       these properties that belong to non-migrated packages. */
    UKStringsEqual(@"Vista", migratedTag.name);

    UKNil(migratedTag.label);
    UKStringsEqual(@"Untitled", migratedParent.label);
    UKStringsEqual(@"Untitled", migratedChild.label);

    UKObjectsEqual(S(migratedTag), migratedParent.parentCollections);
    UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

- (id)registerNameUpdateMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                if ([newItem.entityName isEqualToString: @"OutlineItem"])
                {
                    [newItem setValue: @"Unknown" forAttribute: @"name"];
                }
                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithVersion: version
                                  packageName: @"org.etoile-project.CoreObject"
         dependentSourceVersionsByPackageName: @{}
                                        block: block];
}

- (void)testBasicMigrationInTwoPackagesWithoutMetamodelChanges
{
    COSchemaMigration *testMigration = [self registerLabelUpdateMigrationWithVersion: 1];
    COSchemaMigration *coreObjectMigration = [self registerNameUpdateMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextForDestinationVersions:
        @{@"Test": @(1), @"org.etoile-project.CoreObject": @(1)}];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(1,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    UKNil(migratedTag.name);
    UKStringsEqual(@"Unknown", migratedParent.name);
    UKStringsEqual(@"Unknown", migratedChild.name);
    UKNil(migratedTag.label);
    UKStringsEqual(@"Untitled", migratedParent.label);
    UKStringsEqual(@"Untitled", migratedChild.label);

    UKObjectsEqual(S(migratedTag), migratedParent.parentCollections);
    UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

- (COSchemaMigration *)registerCommentAdditionMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                if ([newItem.entityName isEqualToString: @"OutlineItem"])
                {
                    [newItem setValue: @"Type something"
                         forAttribute: @"comment"
                                 type: kCOTypeString];
                }
                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (ETModelDescriptionRepository *)registerCommentAdditionInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(1), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPropertyDescription *comment = [ETPropertyDescription descriptionWithName: @"comment"];

    comment.type = [repo descriptionForName: @"NSString"];
    comment.persistent = YES;

    [outlineEntity addPropertyDescription: comment];
    [repo addDescription: comment];
    return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyAddition
{
    COSchemaMigration *testMigration = [self registerCommentAdditionMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerCommentAdditionInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    UKRaisesException([migratedTag valueForProperty: @"comment"]);
    UKStringsEqual(@"Type something", [migratedParent valueForProperty: @"comment"]);
    UKStringsEqual(@"Type something", [migratedChild valueForProperty: @"comment"]);
}

- (COSchemaMigration *)registerLabelDeletionMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                if ([newItem.entityName isEqualToString: @"OutlineItem"])
                {
                    [newItem removeValueForAttribute: @"label"];
                }
                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (ETModelDescriptionRepository *)registerLabelDeletionInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(1), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPropertyDescription *label = [outlineEntity propertyDescriptionForName: @"label"];

    [repo removeDescription: label];
    [outlineEntity removePropertyDescription: label];
    return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyDeletion
{
    COSchemaMigration *testMigration = [self registerLabelDeletionMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerLabelDeletionInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    UKNil([migratedTag valueForProperty: @"label"]);
    UKRaisesException([migratedParent valueForProperty: @"label"]);
    UKRaisesException([migratedChild valueForProperty: @"label"]);
}

- (COSchemaMigration *)registerLabelRenamingMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                if ([newItem.entityName isEqualToString: @"OutlineItem"])
                {
                    [newItem setValue: [oldItem valueForAttribute: @"label"]
                         forAttribute: @"title"
                                 type: [oldItem typeForAttribute: @"label"]];
                    [newItem removeValueForAttribute: @"label"];
                }
                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (ETModelDescriptionRepository *)registerLabelRenamingInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(1), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPropertyDescription *label = [outlineEntity propertyDescriptionForName: @"label"];

    // TODO: We should catch missing owner in -add/removeDescription: to prevent
    // ordering issues between -removeDescription: and -removePropertyDescriptions:
    [repo removeDescription: label];
    [outlineEntity removePropertyDescription: label];
    label.name = @"title";
    [outlineEntity addPropertyDescription: label];
    [repo addDescription: label];

    return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyRenaming
{
    COSchemaMigration *testMigration = [self registerLabelRenamingMigrationWithVersion: 1];

    parent.label = @"Zig";
    child.label = @"Zag";
    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerLabelRenamingInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    UKRaisesException([migratedTag valueForProperty: @"title"]);
    UKStringsEqual(parent.label, [migratedParent valueForProperty: @"title"]);
    UKStringsEqual(child.label, [migratedChild valueForProperty: @"title"]);
    UKNil([migratedTag valueForProperty: @"label"]);
    UKRaisesException([migratedParent valueForProperty: @"label"]);
    UKRaisesException([migratedChild valueForProperty: @"label"]);
}

- (COSchemaMigration *)registerNameOverridingMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                if ([newItem.entityName isEqualToString: @"OutlineItem"])
                {
                    /* We insert some random value, but we could do nothing or
                       compute a derived value to initialize this overriden property
                       that takes over COObject.name */
                    [newItem setValue: @"Overriden"
                         forAttribute: @"name"
                                 type: kCOTypeString];
                }
                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (ETModelDescriptionRepository *)registerNameOverridingInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(1), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPropertyDescription *name = [ETPropertyDescription descriptionWithName: @"name"];

    name.type = [repo descriptionForName: @"NSString"];
    name.persistent = YES;

    [outlineEntity addPropertyDescription: name];
    [repo addDescription: name];
    return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyOverridingAccrossPackages
{
    COSchemaMigration *testMigration = [self registerNameOverridingMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerNameOverridingInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    UKNil(migratedTag.name);
    UKStringsEqual(@"Overriden", migratedParent.name);
    UKStringsEqual(@"Overriden", migratedChild.name);
}

- (COSchemaMigration *)registerOutlineMediaAdditionMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                [migratedItems addObject: newItem];

                if (![newItem.entityName isEqualToString: @"OutlineItem"])
                    continue;

                COMutableItem *mediaItem = [COMutableItem item];

                [mediaItem setValue: @"OutlineMedia"
                       forAttribute: kCOObjectEntityNameProperty
                               type: kCOTypeString];
                [mediaItem setValue: [oldItem valueForAttribute: kCOObjectPackageNameProperty]
                       forAttribute: kCOObjectPackageNameProperty
                               type: [oldItem typeForAttribute: kCOObjectPackageNameProperty]];
                [mediaItem setValue: [oldItem valueForAttribute: kCOObjectPackageVersionProperty]
                       forAttribute: kCOObjectPackageVersionProperty
                               type: [oldItem typeForAttribute: kCOObjectPackageVersionProperty]];

                mediaItem.packageVersion = migration.destinationVersion;

                [newItem setValue: mediaItem.UUID
                     forAttribute: @"media"
                             type: kCOTypeReference];

                [migratedItems addObject: mediaItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (ETModelDescriptionRepository *)registerOutlineMediaAdditionInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(version), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *mediaEntity = [ETEntityDescription descriptionWithName: @"OutlineMedia"];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPropertyDescription *media = [ETPropertyDescription descriptionWithName: @"media"];

    mediaEntity.owner = [repo descriptionForName: @"Test"];
    mediaEntity.parent = [repo descriptionForName: @"COObject"];

    // TODO: Detect missing/invalid type in a property description on
    // -[ETModelDescriptionRepository addDescription:]
    media.type = mediaEntity;
    media.persistent = YES;

    [outlineEntity addPropertyDescription: media];
    [repo addDescription: mediaEntity];
    [repo addDescription: media];
    return [self validateModelDescriptionRepository: repo];
}

- (void)testEntityAddition
{
    COSchemaMigration *testMigration = [self registerOutlineMediaAdditionMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerOutlineMediaAdditionInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    ETEntityDescription *newEntity =
        [migratedContext.modelDescriptionRepository descriptionForName: @"OutlineMedia"];

    UKRaisesException([migratedTag valueForProperty: @"media"]);
    UKObjectsEqual(newEntity, [[migratedParent valueForProperty: @"media"] entityDescription]);
    UKObjectsEqual(newEntity, [[migratedChild valueForProperty: @"media"] entityDescription]);
    UKDoesNotRaiseException([migrationCtx insertNewPersistentRootWithEntityName: @"OutlineMedia"]);
}

- (COSchemaMigration *)registerTagDeletionMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                if ([oldItem.entityName isEqualToString: @"Tag"])
                    continue;

                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (ETModelDescriptionRepository *)registerTagDeletionInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(version), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *tagEntity = [repo descriptionForName: @"Tag"];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];

    [repo removeDescription: tagEntity];
    return [self validateModelDescriptionRepository: repo];
}

- (void)testEntityDeletion
{
    COSchemaMigration *testMigration = [self registerTagDeletionMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerTagDeletionInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    UKNil(migratedTag);
    UKTrue(migratedParent.parentCollections.isEmpty);
    UKRaisesException([migrationCtx insertNewPersistentRootWithEntityName: @"Tag"]);
}

- (COSchemaMigration *)registerOutlineItemRenamingMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                if ([newItem.entityName isEqualToString: @"OutlineItem"])
                {
                    newItem.entityName = @"OutlineNode";
                }
                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    return [self registerMigrationWithTestPackageVersion: version
                                                   block: block];
}

- (ETModelDescriptionRepository *)registerOutlineItemRenamingInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(version), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *tagEntity = [repo descriptionForName: @"Tag"];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];

    for (ETPropertyDescription *desc in outlineEntity.propertyDescriptions)
    {
        [repo removeDescription: desc];
    }
    [repo removeDescription: outlineEntity];

    outlineEntity.name = @"OutlineNode";

    for (ETPropertyDescription *desc in outlineEntity.propertyDescriptions)
    {
        [repo addDescription: desc];
    }
    [repo addDescription: outlineEntity];

    return [self validateModelDescriptionRepository: repo];
}

- (void)testEntityRenaming
{
    COSchemaMigration *testMigration = [self registerOutlineItemRenamingMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerOutlineItemRenamingInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    ETEntityDescription *outlineEntity =
        [migratedContext.modelDescriptionRepository descriptionForName: @"OutlineNode"];
    ETEntityDescription *tagEntity =
        [migratedContext.modelDescriptionRepository descriptionForName: @"Tag"];

    UKObjectsEqual(tagEntity, migratedTag.entityDescription);
    UKObjectsEqual(outlineEntity, migratedParent.entityDescription);
    UKObjectsEqual(outlineEntity, migratedChild.entityDescription);
    UKRaisesException([migrationCtx insertNewPersistentRootWithEntityName: @"OutlineItem"]);

    UKObjectsEqual(S(migratedTag), migratedParent.parentCollections);
    UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

- (COSchemaMigration *)registerOutlineItemMoveMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    COSchemaMigration *migration = [self registerMigrationWithTestPackageVersion: version
                                                                           block: block];
    COModelElementMove *outlineMove = [COModelElementMove new];

    outlineMove.name = @"OutlineItem";
    outlineMove.packageName = @"org.etoile-project.CoreObject";
    outlineMove.packageVersion = 0;

    migration.entityMoves = S(outlineMove);

    return migration;
}

- (ETModelDescriptionRepository *)registerOutlineItemMoveInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(version), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPackageDescription *coreObjectPackage =
        [repo descriptionForName: @"org.etoile-project.CoreObject"];

    for (ETPropertyDescription *desc in outlineEntity.propertyDescriptions)
    {
        [repo removeDescription: desc];
    }
    [repo removeDescription: outlineEntity];

    outlineEntity.owner = coreObjectPackage;

    for (ETPropertyDescription *desc in outlineEntity.propertyDescriptions)
    {
        [repo addDescription: desc];
    }
    [repo addDescription: outlineEntity];

    return [self validateModelDescriptionRepository: repo];
}

/**
 * We increment the version in Test package on entity deletion, but we don't 
 * increment the version CoreObject package, since an entity addition doesn't 
 * break the persistent schema (we consider entity names are protected by class 
 * prefixes).
 *
 * Note: For a property addition which can enter in conflict with a property
 * in a subentity, we would increment the CoreObject package version.
 */
- (void)testEntityMoveAccrossPackages
{
    // Entity deletion in Test package
    COSchemaMigration *migration = [self registerOutlineItemMoveMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerOutlineItemMoveInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(-1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(-1, [self checkObject: migratedChild versionForPackageName: @"Test"]);

    ETEntityDescription *outlineEntity =
        [migratedContext.modelDescriptionRepository descriptionForName: @"OutlineItem"];
    ETEntityDescription *tagEntity =
        [migratedContext.modelDescriptionRepository descriptionForName: @"Tag"];

    UKObjectsEqual(tagEntity, migratedTag.entityDescription);
    UKObjectsEqual(outlineEntity, migratedParent.entityDescription);
    UKObjectsEqual(outlineEntity, migratedChild.entityDescription);
    UKDoesNotRaiseException([migrationCtx insertNewPersistentRootWithEntityName: @"OutlineItem"]);

    UKObjectsEqual(S(migratedTag), migratedParent.parentCollections);
    UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

- (COSchemaMigration *)registerPackageRenamingMigrationWithVersion: (int64_t)version
{
    COMigrationBlock block =
        ^(COSchemaMigration *migration, NSArray *storeItems)
        {
            NSMutableArray *migratedItems = [NSMutableArray new];

            for (COMutableItem *oldItem in storeItems)
            {
                COMutableItem *newItem = [oldItem mutableCopy];

                newItem.packageVersion = migration.destinationVersion;

                [migratedItems addObject: newItem];
            }
            return migratedItems;
        };

    COSchemaMigration *migration = [self registerMigrationWithTestPackageVersion: version
                                                                           block: block];
    COModelElementMove *tagMove = [COModelElementMove new];
    COModelElementMove *outlineMove = [COModelElementMove new];

    tagMove.name = @"Tag";
    tagMove.packageName = @"RenamedTest";
    tagMove.packageVersion = 0;

    outlineMove.name = @"OutlineItem";
    outlineMove.packageName = @"RenamedTest";
    outlineMove.packageVersion = 0;

    migration.entityMoves = S(tagMove, outlineMove);

    return migration;
}

- (ETModelDescriptionRepository *)registerPackageRenamingInMetamodelWithVersion: (int64_t)version
{
    ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
        @{@"Test": @(version), @"org.etoile-project.CoreObject": @(0)}];
    ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
    ETPackageDescription *testPackage = [repo descriptionForName: @"Test"];
    ETPackageDescription *renamedTestPackage = [ETPackageDescription descriptionWithName: @"RenamedTest"];

    // NOTE: For CoreObject, we don't support property extensions (extending
    // entities with categories).
    ETAssert([testPackage.propertyDescriptions isEmpty]);

    for (ETEntityDescription *entity in testPackage.entityDescriptions)
    {
        for (ETPropertyDescription *property in entity.propertyDescriptions)
        {
            [repo removeDescription: property];
        }
        [repo removeDescription: entity];
    }

    renamedTestPackage.entityDescriptions = testPackage.entityDescriptions;
    ETAssert(testPackage.entityDescriptions.isEmpty);

    for (ETEntityDescription *entity in renamedTestPackage.entityDescriptions)
    {
        for (ETPropertyDescription *property in entity.propertyDescriptions)
        {
            [repo addDescription: property];
        }
        [repo addDescription: entity];
    }
    [repo addDescription: renamedTestPackage];

    return [self validateModelDescriptionRepository: repo];
}

/**
 * We don't support package deletion and renaming, but we can simulate renaming
 * by adding a new package and moving entities to it, while keeping their old
 * package around.
 *
 * We must keep the old package around to support migrating old items to this 
 * package version (this concerns items serialized before the package was 
 * "renamed" and not yet migrated).
 */
- (void)testPackageRenaming
{
    COSchemaMigration *testMigration =
        [self registerPackageRenamingMigrationWithVersion: 1];

    [ctx commit];
    [self prepareNewMigrationContextWithModelDescriptionRepository:
        [self registerPackageRenamingInMetamodelWithVersion: 1]];

    COObjectGraphContext *migratedContext =
        [migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
    Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
    OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
    OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

    UKNotNil([migratedContext.modelDescriptionRepository descriptionForName: @"Test"]);
    UKNotNil([migratedContext.modelDescriptionRepository descriptionForName: @"RenamedTest"]);
    UKNil([migratedContext.modelDescriptionRepository descriptionForName: @"Test.OutlineItem"]);
    UKNotNil([migratedContext.modelDescriptionRepository descriptionForName: @"RenamedTest.OutlineItem"]);
    UKNil([migratedContext.modelDescriptionRepository descriptionForName: @"Test.OutlineItem.label"]);
    UKNotNil([migratedContext.modelDescriptionRepository descriptionForName: @"RenamedTest.OutlineItem.label"]);

    UKIntsEqual(0,
                [self checkObject: migratedTag
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedParent
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    UKIntsEqual(0,
                [self checkObject: migratedChild
            versionForPackageName: @"org.etoile-project.CoreObject"]);
    /* The 'Test' package has been removed in the migrated items */
    UKIntsEqual(-1, [self checkObject: migratedTag versionForPackageName: @"Test"]);
    UKIntsEqual(-1, [self checkObject: migratedParent versionForPackageName: @"Test"]);
    UKIntsEqual(-1, [self checkObject: migratedChild versionForPackageName: @"Test"]);
    UKIntsEqual(0, [self checkObject: migratedTag versionForPackageName: @"RenamedTest"]);
    UKIntsEqual(0, [self checkObject: migratedParent versionForPackageName: @"RenamedTest"]);
    UKIntsEqual(0, [self checkObject: migratedChild versionForPackageName: @"RenamedTest"]);

    ETEntityDescription *outlineEntity =
        [migratedContext.modelDescriptionRepository descriptionForName: @"OutlineItem"];
    ETEntityDescription *tagEntity =
        [migratedContext.modelDescriptionRepository descriptionForName: @"Tag"];

    UKObjectsEqual(tagEntity, migratedTag.entityDescription);
    UKObjectsEqual(outlineEntity, migratedParent.entityDescription);
    UKObjectsEqual(outlineEntity, migratedChild.entityDescription);
    UKDoesNotRaiseException([migrationCtx insertNewPersistentRootWithEntityName: @"OutlineItem"]);

    UKObjectsEqual(S(migratedTag), migratedParent.parentCollections);
    UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

@end


@implementation OutlineNode

- (NSString *)contentKey
{
    return @"contents";
}

@end
