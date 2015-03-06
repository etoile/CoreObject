/*
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import "COSchemaMigrationDriver.h"
#import "CODictionary.h"
#import "COItem.h"
#import "COModelElementMove.h"
#import "COSchemaMigration.h"

@interface ETEntityDescription (COSchemaMigration)
- (NSArray *)persistentPropertyDescriptionNamesForPackageDescription: (ETPackageDescription *)aPackage;
@end


@implementation COSchemaMigrationDriver

#pragma mark Initialization -

- (instancetype)initWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	NILARG_EXCEPTION_TEST(repo);
	SUPERINIT;
	_modelDescriptionRepository = repo;
	return self;
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
 * Returns some info on the metamodel state that the item entity/package/version
 * comes from, namely the package/version pairs for the entity and all of its
 * superclasses.
 */
- (NSDictionary *) versionsByDomainForItem: (COItem *)item
{
	NSDictionary *versionsByDomainByEntityTuple = [COSchemaMigration versionsByDomainByEntityTuple];
	NSArray *key = @[item.packageName, @(item.entityVersion), item.entityName];
	return versionsByDomainByEntityTuple[key];
}



- (NSSet *)domainsToMigrateForItem: (COItem *)item
{
	ETEntityDescription *entity = [_modelDescriptionRepository descriptionForName: item.entityName];
	BOOL isDeletedEntity = (entity == nil);
	
	/* For a deleted entity, the domain versions match between item and packages */
	if (isDeletedEntity)
	{
		// FIXME: We hit this line when loading a CODictionary during the test suite,
		// something must be wrong (but no tests fail).
		return S(item.packageName);
	}
	
	/* Early exit, the item has no version specified, or no package, (i.e.
	   saved with an old version of CO) so we can't do any migration. */
	if (item.entityVersion == -1 || item.packageName == nil)
	{
		return [NSSet set];
	}
	
	/* Early exit, common case: the version in the item matches the package verion
	   in the model description repository. In that case we have no migration to do */
	if (entity.owner != nil
		&& entity.owner.version == item.entityVersion)
	{
		return [NSSet set];
	}
	
	/* At this point we are doing a migration for some domains for sure. */

	NSDictionary *versionsByDomain = [self versionsByDomainForItem: item];
	
	if (versionsByDomain == nil
		|| versionsByDomain[@"org.etoile-project.CoreObject"] == nil
		|| ![versionsByDomain[item.packageName] isEqual: @(item.entityVersion)])
	{
		// TODO: Test that we get this exception when forgetting to call  +[COSchemaMigration recordVersionsByDomain:...]
		[NSException raise: NSInternalInconsistencyException
					format: @"Item with entityName '%@' version %d needs a migration, "
							"but -versionsByDomainForItem: returned an incomplete "
							"snapshot of the past version of the metamodel we need. "
							"It returned: %@. \n"
							"We require it to be a non-nil dictionary, have a "
							"version set for the org.etoile-project.CoreObject "
							"package, and include the same package/version as "
							"the item being migrated. Probably, you forgot to "
							"call +[COSchemaMigration recordVersionsByDomain:...]",
							item.entityName, (int)item.entityVersion, versionsByDomain];
	}
	
	NSMutableSet *domainsToMigrate = [NSMutableSet new];
	
	for (NSString *domain in [versionsByDomain allKeys])
	{
		ETPackageDescription *package = [_modelDescriptionRepository descriptionForName: domain];
		BOOL isDeletedPackage = (package == nil);
		int64_t version = versionsByDomain[domain] != nil
			? (int64_t)[versionsByDomain[domain] longLongValue]
			: (int64_t)-1;

		if (isDeletedPackage || version != (int64_t)package.version)
		{
			[domainsToMigrate addObject: domain];
		}
	}
	return domainsToMigrate;
}

- (BOOL)addItem: (COItem *)item
{
	ETAssert(_modelDescriptionRepository != nil);
	NSSet *domainsToMigrate = [self domainsToMigrateForItem: item];

	for (NSString *domain in domainsToMigrate)
	{
		addObjectForKey(itemsToMigrate, item, domain);
	}
	return ![domainsToMigrate isEmpty];
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

	for (NSString *packageName in [itemsToMigrate allKeys])
	{
		ETPackageDescription *package = [_modelDescriptionRepository descriptionForName: packageName];
		ETAssert(package != nil);

		// NOTE: Or -migrateItems:boundToPackageNamed:inRepository:
		[self migrateItemsInDomain: packageName
						 toVersion: (int64_t)package.version];
	}

	return [upToDateItems arrayByAddingObjectsFromArray: [self combineMigratedItems: itemsToMigrate]];
}

#pragma mark Ungrouping Items by Packages -

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
	[pristineItem setValue: [item valueForAttribute: kCOObjectPackageNameProperty]
	          forAttribute: kCOObjectPackageNameProperty
	                  type: [item typeForAttribute: kCOObjectPackageNameProperty]];
	[pristineItem setValue: [item valueForAttribute: kCOObjectEntityVersionProperty]
	          forAttribute: kCOObjectEntityVersionProperty
	                  type: [item typeForAttribute: kCOObjectEntityVersionProperty]];

	return pristineItem;
}

- (NSArray *)attributesForPackage: (ETPackageDescription *)package inItem: (COItem *)item
{
	if ([item isAdditionalItem])
	{
		return [item.attributeNames arrayByRemovingObjectsInArray:
			@[kCOObjectEntityNameProperty, kCOObjectPackageNameProperty, kCOObjectEntityVersionProperty]];
	}

	ETEntityDescription *entity = [_modelDescriptionRepository descriptionForName: item.entityName];
	ETAssert(entity != nil);
	return [entity persistentPropertyDescriptionNamesForPackageDescription: package];
}

/**
 * Combines migrated items with the same UUID.
 *
 * For each domain, items are enumerated, and properties that belong to this
 * domain are merged into a final item per item UUID.
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
			//[combinedItem setVersion: package.version
			//               forDomain: packageName];
		}
	}

	return [combinedItems allValues];
}

#pragma mark Migrating an Item Domain to a Future Version -

- (void)migrateItemsInDomain: (NSString *)packageName
                   toVersion: (int64_t)destinationVersion
{
	COItem *randomItem = [itemsToMigrate[packageName] firstObject];
	int64_t proposedVersion = [[self versionsByDomainForItem: randomItem][packageName] longLongValue];
	
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

		[self runDependentMigrationsForMigration: migration];

		migration.migrationDriver = self;
		itemsToMigrate[packageName] = [migration migrateItems: itemsToMigrate[packageName]];
		
		/* Moving entities and properties after -[COSchemaMigration migrateItems:]
		   ensures that:
		   - an incorrect domain/version increment on a entity concerned by a 
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
	NSMutableArray *sourceItems = (NSMutableArray *)itemsToMigrate[migration.domain];

	for (COModelElementMove *move in migration.entityMoves)
	{
		ETAssert(move.name != nil);
		ETAssert(move.ownerName == nil);
		ETAssert(move.domain != nil);
		ETAssert(move.version != -1);
		NSMutableArray *destinationItems = (NSMutableArray *)itemsToMigrate[move.domain];

		if (destinationItems == nil)
		{
			destinationItems = [NSMutableArray new];
			itemsToMigrate[move.domain] = destinationItems;
		}
		NSUInteger initialItemCount = sourceItems.count + destinationItems.count;

		for (COItem *item in [NSArray arrayWithArray: sourceItems])
		{
			if (![item.entityName isEqualToString: move.name])
				continue;

			// TODO: This code path is not tested
			COMutableItem *newItem = [item mutableCopy];
			
			if ([newItem.packageName isEqual: migration.domain])
			{
				newItem.packageName = move.domain;
				newItem.entityVersion = move.version;
			}

			[destinationItems addObject: newItem];
			[sourceItems removeObject: item];
		}
		
		ETAssert(initialItemCount == sourceItems.count + destinationItems.count);
	}
}

- (void)movePropertiesForMigration: (COSchemaMigration *)migration
{
	NSMutableArray *sourceItems = (NSMutableArray *)itemsToMigrate[migration.domain];

	for (COModelElementMove *move in migration.propertyMoves)
	{
		ETAssert(move.name != nil);
		ETAssert(move.ownerName != nil);
		ETAssert(move.domain != nil);
		ETAssert(move.version != -1);
		NSMutableArray *destinationItems = (NSMutableArray *)itemsToMigrate[move.domain];
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
			
			[destinationItems replaceObjectAtIndex: index
								        withObject: destinationItem];
		}
	}
}

- (void)runDependentMigrationsForMigration: (COSchemaMigration *)aMigration
{
	ETKeyValuePair *pair = [ETKeyValuePair pairWithKey: aMigration.domain
	                                             value: @(aMigration.destinationVersion)];
	NSArray *dependencies = [COSchemaMigration dependencies][pair];
	
	for (COSchemaMigration *migration in dependencies)
	{
		/* Run enumerated migration and all preceding migrations not yet run */
		[self migrateItemsInDomain: migration.domain
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
