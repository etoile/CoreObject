/*
    Copyright (C) 2014 Quentin Mathe

    Date:  December 2014
    License:  MIT  (see COPYING)
 */

#import "COSchemaMigrationDriver.h"
#import "CODictionary.h"
#import "COModelElementMove.h"
#import "COSchemaMigration.h"

@interface ETEntityDescription (COSchemaMigration)

- (NSArray *)persistentPropertyDescriptionNamesForPackageDescription: (ETPackageDescription *)aPackage;

@end


@implementation COSchemaMigrationDriver

@synthesize modelDescriptionRepository = _modelDescriptionRepository;


#pragma mark Initialization -


- (instancetype)initWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
    NILARG_EXCEPTION_TEST(repo);
    SUPERINIT;
    _modelDescriptionRepository = repo;
    return self;
}

- (instancetype)init
{
    return [self initWithModelDescriptionRepository: nil];
}


#pragma mark Grouping Item by Packages -


static inline void addObjectForKey(NSMutableDictionary *dict, id object, NSString *key)
{
    id value = dict[key];

    if (value == nil)
    {
        value = [NSMutableArray new];
        dict[key] = value;
    }
    [value addObject: object];
}

/**
 * Returns some info on the metamodel state that the item package/version
 * comes from, namely the package/version pairs for the entity and all of its
 * superclasses.
 */
- (NSDictionary *)versionsByPackageNameForItem: (COItem *)item
{
    for (COSchemaMigration *migration in [COSchemaMigration migrations])
    {
        if ([item.packageName isEqual: migration.packageName]
            && item.packageVersion == migration.sourceVersion)
        {
            NSDictionary *versionsByPackageName = [migration.dependentSourceVersionsByPackageName
                dictionaryByAddingEntriesFromDictionary:
                    @{migration.packageName: @(migration.sourceVersion)}];
            return versionsByPackageName;
        }
    }
    return @{};
}

- (NSSet *)packagesToMigrateForItem: (COItem *)item
{
    ETEntityDescription *entity = [_modelDescriptionRepository descriptionForName: item.entityName];
    const BOOL isDeletedEntity = (entity == nil);

    /* For a deleted entity, the package versions match between item and packages */
    if (isDeletedEntity)
    {
        // NOTE: CODictionary hits this case because it doesn't have an entity description
        return S(item.packageName);
    }

    /* Early exit, the item has no version specified, or no package, (i.e.
       saved with an old version of CO) so we can't do any migration. */
    if (item.packageVersion == -1 || item.packageName == nil)
    {
        return [NSSet set];
    }

    /* Early exit, common case: the version in the item matches the package verion
       in the model description repository. In that case we have no migration to do */
    if (entity.owner != nil
        && entity.owner.version == item.packageVersion
        && [entity.owner.name isEqualToString: item.packageName])
    {
        return [NSSet set];
    }

    /* At this point we are doing a migration for some packages for sure. */

    NSDictionary *versionsByPackageName = [self versionsByPackageNameForItem: item];

    if (versionsByPackageName == nil
        || versionsByPackageName[@"org.etoile-project.CoreObject"] == nil
        || ![versionsByPackageName[item.packageName] isEqual: @(item.packageVersion)])
    {
        // TODO: Test that we get this exception when needed
        [NSException raise: NSInternalInconsistencyException
                    format: @"Item with entityName '%@' package '%@' version %d needs a migration, "
                             "but -versionsByPackageNameForItem: returned an incomplete "
                             "snapshot of the past version of the metamodel we need. "
                             "It returned: %@. \n"
                             "We require it to be a non-nil dictionary, have a "
                             "version set for the org.etoile-project.CoreObject "
                             "package, and include the same package/version as "
                             "the item being migrated. Probably, you forgot to "
                             "set COSchemaMigration.dependentSourceVersionsByPackageName.",
                            item.entityName,
                            item.packageName,
                            (int)item.packageVersion,
                            versionsByPackageName];
    }

    NSMutableSet *packagesToMigrate = [NSMutableSet new];

    for (NSString *package in versionsByPackageName.allKeys)
    {
        /* We migrate even when we encounter these special cases too:
           - deleted packages (packageDesc == nil)
           - removed package dependencies (versionsByPackageName[package] == nil)
           - up-to-date packages (version == packageDesc.version)
           
           Note: packageDesc = [_modelDescriptionRepository descriptionForName: package]
           
           For up-to-date packages, no migration will occur, but we must include 
           them, otherwise their properties would be omitted in -combineMigratedItems:. */
        [packagesToMigrate addObject: package];
    }
    return packagesToMigrate;
}

- (BOOL)addItem: (COItem *)item
{
    ETAssert(_modelDescriptionRepository != nil);
    NSSet *packagesToMigrate = [self packagesToMigrateForItem: item];

    for (NSString *package in packagesToMigrate)
    {
        addObjectForKey(itemsToMigrate, item, package);
    }
    return ![packagesToMigrate isEmpty];
}


#pragma mark Triggering a Migration -


- (NSArray *)prepareMigrationForItems: (NSArray *)storeItems
{
    NSMutableArray *upToDateItems = [NSMutableArray new];

    for (COItem *item in storeItems)
    {
        BOOL migrate = [self addItem: item];

        if (!migrate)
        {
            [upToDateItems addObject: item];
        }
    }
    return upToDateItems;
}

- (NSArray *)migrateItems: (NSArray *)storeItems
{
    itemsToMigrate = [NSMutableDictionary new];
    NSArray *upToDateItems = [self prepareMigrationForItems: storeItems];

    for (NSString *packageName in itemsToMigrate.allKeys)
    {
        ETPackageDescription *package = [_modelDescriptionRepository descriptionForName: packageName];
        ETAssert(package != nil);

        [self migrateItemsBoundToPackageNamed: packageName
                                    toVersion: (int64_t)package.version];
    }

    return [upToDateItems arrayByAddingObjectsFromArray: [self combineMigratedItems: itemsToMigrate]];
}


#pragma mark Ungrouping Items by Packages -


static inline void copyAttributesFromItemTo(NSArray *attributes,
                                            COItem *sourceItem,
                                            COMutableItem *destinationItem)
{
    for (NSString *attribute in attributes)
    {
        [destinationItem setValue: [sourceItem valueForAttribute: attribute]
                     forAttribute: attribute
                             type: [sourceItem typeForAttribute: attribute]];
    }
}

static inline COMutableItem *pristineMutableItemFrom(COItem *item)
{
    COMutableItem *pristineItem = [COMutableItem itemWithUUID: item.UUID];

    [pristineItem setValue: item.entityName
              forAttribute: kCOItemEntityNameProperty
                      type: [item typeForAttribute: kCOItemEntityNameProperty]];

    return pristineItem;
}

- (NSArray *)attributesForPackage: (ETPackageDescription *)package inItem: (COItem *)item
{
    if (item.isAdditionalItem)
    {
        return [item.attributeNames arrayByRemovingObjectsInArray:
            @[kCOItemEntityNameProperty,
              kCOItemPackageNameProperty,
              kCOItemPackageVersionProperty]];
    }

    ETEntityDescription *entity = [_modelDescriptionRepository descriptionForName: item.entityName];
    ETAssert(entity != nil);
    return [entity persistentPropertyDescriptionNamesForPackageDescription: package];
}

static inline void copySchemaAttributesFromItemWhenOwnedByPackageToItem(COItem *sourceItem,
                                                                        ETPackageDescription *package,
                                                                        COMutableItem *destinationItem)
{
    BOOL isOwningPackage = [sourceItem.packageName isEqualToString: package.name];

    if (!isOwningPackage)
        return;

    if (sourceItem.packageVersion != package.version)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"A migrated item doesn't match its owning package current version "
                                "%lu. You probably forgot to update COItem.packageVersion in some "
                                "migration applied to this item: %@",
                            (unsigned long)package.version,
                            sourceItem];
    }
    assert([sourceItem.packageName isEqualToString: package.name]);

    destinationItem.packageVersion = sourceItem.packageVersion;
    destinationItem.packageName = sourceItem.packageName;
}

/**
 * Combines migrated items with the same UUID.
 *
 * For each package, items are enumerated, and properties that belong to this
 * package are merged into a final item per item UUID.
 */
- (NSArray *)combineMigratedItems: (NSDictionary *)migratedItems
{
    NSMutableDictionary *combinedItems = [NSMutableDictionary new];

    for (NSString *packageName in migratedItems)
    {
        ETPackageDescription *package = [_modelDescriptionRepository descriptionForName: packageName];

        for (COItem *item in migratedItems[packageName])
        {
            NSArray *attributes = [self attributesForPackage: package
                                                      inItem: item];
            ETAssert(attributes != nil);
            COMutableItem *combinedItem = combinedItems[item.UUID];

            if (combinedItem == nil)
            {
                combinedItem = pristineMutableItemFrom(item);
                combinedItems[item.UUID] = combinedItem;
            }

            copyAttributesFromItemTo(attributes, item, combinedItem);
            copySchemaAttributesFromItemWhenOwnedByPackageToItem(item, package, combinedItem);
        }
    }

    return combinedItems.allValues;
}


#pragma mark Migrating Items in a Package to a Future Version -


- (void)migrateItemsBoundToPackageNamed: (NSString *)packageName
                              toVersion: (int64_t)destinationVersion
{
    COItem *randomItem = [itemsToMigrate[packageName] firstObject];
    int64_t proposedVersion = [[self versionsByPackageNameForItem: randomItem][packageName] longLongValue];

    if (proposedVersion < 0)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Invalid negative schema version %lld", proposedVersion];
    }
    if (proposedVersion > destinationVersion)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Backward migration from %lld to %lld is not supported by CoreObject",
                            proposedVersion, destinationVersion];
    }

    while (proposedVersion < destinationVersion)
    {
        proposedVersion++;

        COSchemaMigration *migration =
            [COSchemaMigration migrationForPackageName: packageName
                                    destinationVersion: proposedVersion];

        if (migration == nil)
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Missing schema migration from %lld to %lld in %@",
                                proposedVersion - 1, proposedVersion, packageName];
        }

        [self runDependentMigrationsForMigration: migration];

        migration.migrationDriver = self;
        itemsToMigrate[packageName] = [migration migrateItems: itemsToMigrate[packageName]];

        /* Moving entities and properties after -[COSchemaMigration migrateItems:]
           ensures that:
           - an incorrect package/version increment on a entity concerned by a 
             move is discarded
           - a moved entity or property can be changed (without requiring
             another migration bound to the destination package). */
        [self moveEntitiesForMigration: migration];
        [self movePropertiesForMigration: migration];
    }
}


#pragma mark Moving Entities and Properties Accross Packages -


- (void)moveEntitiesForMigration: (COSchemaMigration *)migration
{
    NSMutableArray *sourceItems = (NSMutableArray *)itemsToMigrate[migration.packageName];

    for (COModelElementMove *move in migration.entityMoves)
    {
        ETAssert(move.name != nil);
        ETAssert(move.ownerName == nil);
        ETAssert(move.packageName != nil);
        ETAssert(move.packageVersion != -1);
        NSMutableArray *destinationItems = (NSMutableArray *)itemsToMigrate[move.packageName];

        if (destinationItems == nil)
        {
            destinationItems = [NSMutableArray new];
            itemsToMigrate[move.packageName] = destinationItems;
        }
        NSUInteger initialItemCount = sourceItems.count + destinationItems.count;

        for (COItem *item in [NSArray arrayWithArray: sourceItems])
        {
            if (![item.entityName isEqualToString: move.name])
                continue;

            // TODO: This code path is not tested
            COMutableItem *newItem = [item mutableCopy];

            if ([newItem.packageName isEqual: migration.packageName])
            {
                newItem.packageName = move.packageName;
                newItem.packageVersion = move.packageVersion;
            }

            [destinationItems addObject: newItem];
            [sourceItems removeObject: item];
        }

        ETAssert(initialItemCount == sourceItems.count + destinationItems.count);
    }
}

- (void)movePropertiesForMigration: (COSchemaMigration *)migration
{
    NSMutableArray *sourceItems = (NSMutableArray *)itemsToMigrate[migration.packageName];

    for (COModelElementMove *move in migration.propertyMoves)
    {
        ETAssert(move.name != nil);
        ETAssert(move.ownerName != nil);
        ETAssert(move.packageName != nil);
        ETAssert(move.packageVersion != -1);
        NSMutableArray *destinationItems = (NSMutableArray *)itemsToMigrate[move.packageName];
        NSMutableArray *selectedSourceItems = [NSMutableArray new];
        NSMutableDictionary *selectedDestItems = [NSMutableDictionary new];

        for (COItem *item in sourceItems)
        {
            if (![item.entityName isEqualToString: move.ownerName])
                continue;

            [selectedSourceItems addObject: item];
        }

        for (COItem *item in destinationItems)
        {
            if (![item.entityName isEqualToString: move.ownerName])
                continue;

            selectedDestItems[item.UUID] = item;
        }

        for (COItem *sourceItem in selectedSourceItems)
        {
            COMutableItem *destinationItem = [selectedDestItems[sourceItem.UUID] mutableCopy];

            [destinationItem setValue: [sourceItem valueForAttribute: move.name]
                         forAttribute: move.name];

            NSUInteger index =
                [destinationItems indexOfObject: selectedDestItems[sourceItem.UUID]];

            destinationItems[index] = destinationItem;
        }
    }
}

- (void)runDependentMigrationsForMigration: (COSchemaMigration *)aMigration
{
    ETKeyValuePair *pair = [ETKeyValuePair pairWithKey: aMigration.packageName
                                                 value: @(aMigration.destinationVersion)];
    NSArray *dependencies = [COSchemaMigration dependencies][pair];

    for (COSchemaMigration *migration in dependencies)
    {
        /* Run enumerated migration and all preceding migrations not yet run */
        [self migrateItemsBoundToPackageNamed: migration.packageName
                                    toVersion: migration.destinationVersion];
    }
}

@end


#pragma mark Migration Conveniency  -


@implementation ETEntityDescription (COSchemaMigration)

- (NSArray *)persistentPropertyDescriptionNamesForPackageDescription: (ETPackageDescription *)aPackage
{
    NSMutableArray *descs = [self.allPersistentPropertyDescriptions mutableCopy];
    [[[[descs filter] owner] owner] isEqual: aPackage];
    return (id)[[descs mappedCollection] name];
}

@end
