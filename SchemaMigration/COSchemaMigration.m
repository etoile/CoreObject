/*
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import "COSchemaMigration.h"
#import "COItem.h"

@interface ETEntityDescription (COSchemaMigration)
- (NSArray *)persistentPropertyDescriptionNamesForPackageDescription: (ETPackageDescription *)aPackage;
@end

@interface COItem (COSchemaMigration)
@property (nonatomic, readonly) NSString *entityName;
@end


@implementation COSchemaMigration

@synthesize domain = _domain, destinationVersion = _destinationVersion, migrationBlock = _migrationBlock;

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

- (void)validateItems: (NSArray *)storeItems
{
	for (COItem *item in storeItems)
	{
		int64_t itemVersion = [item.versionsByDomain[self.domain] longLongValue];

		if (itemVersion != self.sourceVersion)
		{
			[NSException raise: NSInvalidArgumentException
		                format: @"Item version %lld doesn't match migration source version %lld",
			                    itemVersion, self.sourceVersion];
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

+ (BOOL)needsMigrationForItem: (COItem *)item
        withEntityDescription: (ETEntityDescription *)anEntity
{
	for (ETPackageDescription *package in anEntity.allPackageDescriptions)
	{
		if ([item.versionsByDomain[package.name] longLongValue] != (int64_t)package.version)
			return YES;
	}
	return NO;
}

+ (BOOL)      addItem: (COItem *)item
withEntityDescription: (ETEntityDescription *)anEntity
      toItemsByDomain: (NSMutableDictionary *)itemsToMigrate
{
	if (![self needsMigrationForItem: item withEntityDescription: anEntity])
		return NO;
	
	for (ETPackageDescription *package in anEntity.allPackageDescriptions)
	{
		addObjectForKey(itemsToMigrate, item, package.name);
	}
	return YES;
}

+ (NSArray *)migrateItems: (NSArray *)storeItems withModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	NSMutableDictionary *itemsToMigrate = [NSMutableDictionary new];
	NSMutableArray *upToDateItems = [NSMutableArray new];

	for (COItem *item in storeItems)
	{
		BOOL migrated = [self addItem: item
		        withEntityDescription: [repo descriptionForName: item.entityName]
		              toItemsByDomain: itemsToMigrate];
		
		if (!migrated)
		{
			[upToDateItems addObject: item];
		}
	}
	
	NSArray *migratedItems = [self migrateItemsByDomain: itemsToMigrate
	                     withModelDescriptionRepository: repo];
	return [upToDateItems arrayByAddingObjectsFromArray: migratedItems];
}

static inline void copyAttributesFromItemTo(NSArray *attributes, COItem *sourceItem, COMutableItem *destinationItem)
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

	[pristineItem setValue: [item valueForAttribute: kCOObjectEntityNameProperty]
	          forAttribute: kCOObjectEntityNameProperty
	                  type: [item typeForAttribute: kCOObjectEntityNameProperty]];
	[pristineItem setValue: [item valueForAttribute: kCOObjectDomainsProperty]
	          forAttribute: kCOObjectDomainsProperty
	                  type: [item typeForAttribute: kCOObjectDomainsProperty]];
	[pristineItem setValue: [item valueForAttribute: kCOObjectVersionsProperty]
	          forAttribute: kCOObjectVersionsProperty
	                  type: [item typeForAttribute: kCOObjectVersionsProperty]];

	return pristineItem;
}

+ (NSArray *)combineMigratedItems: (NSDictionary *)migratedItems
   withModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	NSMutableDictionary *combinedItems = [NSMutableDictionary new];
	
	for (NSString *packageName in migratedItems)
	{
		ETPackageDescription *package = [repo descriptionForName: packageName];

		for (COItem *item in migratedItems[packageName])
		{
			ETEntityDescription *entity = [repo descriptionForName: item.entityName];
			NSArray *attributes = [entity persistentPropertyDescriptionNamesForPackageDescription: package];

			COMutableItem *combinedItem = combinedItems[item.UUID];
			
			if (combinedItem == nil)
			{
				combinedItem = pristineMutableItemFrom(item);
				combinedItems[item.UUID] = combinedItem;
			}
			
			copyAttributesFromItemTo(attributes, item, combinedItem);
			//[combinedItem setVersion: package.version
			//               forDomain: packageName];
		}
	}

	return [combinedItems allValues];
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

	return [self combineMigratedItems: migratedItems
	   withModelDescriptionRepository: repo];
}

+ (NSArray *)migrateItems: (NSArray *)storeItems
				 inDomain: (NSString *)packageName
                toVersion: (int64_t)destinationVersion
{
	int64_t proposedVersion = [[storeItems.firstObject versionsByDomain][packageName] longLongValue];
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
		
		if (migration == nil)
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Missing schema migration from %lld to %lld in %@",
			                    proposedVersion - 1, proposedVersion, packageName];
		}

		proposedItems = [migration migrateItems: proposedItems];
	}

	return proposedItems;
}

@end


@implementation ETEntityDescription (COSchemaMigration)

- (NSArray *)persistentPropertyDescriptionNamesForPackageDescription: (ETPackageDescription *)aPackage
{
	NSMutableArray *descs = [self.allPersistentPropertyDescriptions mutableCopy];
	[[[[descs filter] owner] owner] isEqual: aPackage];
	return (id)[[descs mappedCollection] name];
}

@end


@implementation COItem (COSchemaMigration)

- (NSString *)entityName
{
	return [self valueForAttribute: kCOObjectEntityNameProperty];
}

@end
