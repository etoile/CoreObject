/*
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import "COSchemaMigration.h"

@implementation COSchemaMigration

@synthesize destinationVersion, migrationBlock;

static NSMutableDictionary *migrations;

+ (void)initialize
{
	if (self != [COSchemaMigration class])
		return;

	migrations = [NSMutableDictionary new];
}

+ (void)registerMigration: (COSchemaMigration *)migration
{
	migrations[@(migration.destinationVersion)] = migration;
}

+ (COSchemaMigration *)migrationForDestinationVersion: (NSInteger)version
{
	return migrations[@(version)];
}

- (NSUInteger)sourceVersion
{
	return (self.destinationVersion == 0 ? 0 : self.destinationVersion - 1);
}

- (NSArray *) migrateItems: (NSArray *)storeItems
{
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
