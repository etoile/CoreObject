/*
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import "COSchemaMigration.h"
#import "COItem.h"
#import "COSchemaMigrationDriver.h"

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

#pragma mark - Triggering a Migration

+ (NSArray *)migrateItems: (NSArray *)storeItems withModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	return [[COSchemaMigrationDriver new] migrateItems: storeItems
						withModelDescriptionRepository: repo];
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

@end
