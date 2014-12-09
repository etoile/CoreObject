/*
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import "COSchemaMigration.h"
#import "COItem.h"

@implementation COSchemaMigration

@synthesize domain, destinationVersion, migrationBlock;

static NSMutableDictionary *migrations;

+ (void)initialize
{
	if (self != [COSchemaMigration class])
		return;

	migrations = [NSMutableDictionary new];
}

#pragma mark Schema Migration Registration -

+ (void)registerMigration: (COSchemaMigration *)migration
{
	INVALIDARG_EXCEPTION_TEST(migration, migration.domain != nil);
	INVALIDARG_EXCEPTION_TEST(migration, migration.destinationVersion > 0);

	migrations[S(migration.domain, @(migration.destinationVersion))] = migration;
}

+ (COSchemaMigration *)migrationForDomain: (NSString *)domain destinationVersion: (NSInteger)version
{
	NILARG_EXCEPTION_TEST(domain);
	INVALIDARG_EXCEPTION_TEST(version, version > 0);

	return migrations[S(domain, @(version))];
}

#pragma mark Targeted Versions -

- (int64_t)sourceVersion
{
	return (self.destinationVersion == 0 ? 0 : self.destinationVersion - 1);
}

#pragma mark Migration Process -

// TODO: Perhaps replace this by -[COItem schemaVersion]
static inline int64_t versionFromItem(COItem *item)
{
	return [[item valueForAttribute: kCOObjectSchemaVersionProperty] longLongValue];
}

- (void)validateItems: (NSArray *)storeItems
{
	for (COItem *item in storeItems)
	{
		if (versionFromItem(item) != self.sourceVersion)
		{
			[NSException raise: NSInvalidArgumentException
		                format: @"Item version %lld doesn't match migration source version %lld",
			                    versionFromItem(item), self.sourceVersion];
		}
	}
}

- (NSArray *)migrateItems: (NSArray *)storeItems
{
	[self validateItems: storeItems];

	if (self.migrationBlock != NULL)
	{
		return self.migrationBlock(self, storeItems);
	}
	else
	{
		return storeItems;
	}
}

#pragma mark - Triggering and Preparing a Migration

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

+ (void)      addItem: (COItem *)item
withEntityDescription: (ETEntityDescription *)anEntity
      toItemsByDomain: (NSMutableDictionary *)itemsToMigrate
{
	ETEntityDescription *entity = anEntity;
	ETPackageDescription *package = nil;

	while (![entity isRoot])
	{
		if (package == nil || entity.owner != package)
		{
			package = entity.owner;
			addObjectForKey(itemsToMigrate, item, package.name);
		}
		entity = entity.parent;
	}
}

+ (NSArray *)migrateItems: (NSArray *)storeItems withModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	NSMutableDictionary *itemsToMigrate = [NSMutableDictionary new];

	for (COItem *item in storeItems)
	{
		NSString *entityName = [item valueForAttribute: kCOObjectEntityNameProperty];
		ETEntityDescription *entity = [repo descriptionForName: entityName];
		ETPackageDescription *package = entity.owner;
	
		if (versionFromItem(item) == (int64_t)package.version)
			continue;
		
		        [self addItem: item
		withEntityDescription: entity
		      toItemsByDomain: itemsToMigrate];
	}
	
	return [self migrateItemsByDomain: itemsToMigrate
	   withModelDescriptionRepository: repo];
}

+ (NSArray *)flattenedItemsFromMigratedItems: (NSDictionary *)migratedItems
{
	NSMutableSet *flattenedItems = [NSMutableSet new];
	
	for (NSArray *items in migratedItems)
	{
		[flattenedItems addObjectsFromArray: items];
	}
	return flattenedItems.allObjects;
}

+ (NSArray *)migrateItemsByDomain: (NSDictionary *)itemsToMigrate
   withModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	NSMutableDictionary *migratedItems = [NSMutableDictionary new];

	for (NSString *packageName in itemsToMigrate)
	{
		ETPackageDescription *package = [repo descriptionForName: packageName];

		// NOTE: Or -migrateItems:boundToPackageNamed:inRepository:
		migratedItems[packageName] = [self migrateItems: itemsToMigrate[packageName]
		                                       inDomain: packageName
											  toVersion: (int64_t)package.version];
	}

	return [self flattenedItemsFromMigratedItems: migratedItems];
}

+ (NSArray *)migrateItems: (NSArray *)storeItems
				 inDomain: (NSString *)packageName
                toVersion: (int64_t)destinationVersion
{
	int64_t proposedVersion = versionFromItem(storeItems.firstObject);
	NSArray *proposedItems = storeItems;

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
			[COSchemaMigration migrationForDomain: packageName
			                   destinationVersion: proposedVersion];
		
		proposedItems = [migration migrateItems: proposedItems];
	}

	return proposedItems;
}

@end
