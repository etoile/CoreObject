/**
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COSchemaMigration;

typedef NSArray *(^COMigrationBlock)(COSchemaMigration *migration, NSArray *storeItems);

/**
 * @group Schema Migration
 * @abstract Schema migration model operating at storage data model level.
 *
 * COSchemaMigration supports arbitrary complex migrations such as reorganizing 
 * relationships, or even ditching the entire metamodel used previously.
 *
 * @section Forward Linear Updates
 *
 * CoreObject migrations are always applied in a linear fashion to ensure
 * there is only a single migration code path between two versions (even when 
 * they are separated by ten intermediate versions). This prevents multiplying
 * the potential migration paths every time the version is incremented.
 *
 * In other words, to migrate from version 2 to 5, the following migrations
 * occur sequentially:
 *
 * <list>
 * <item>2 to 3</item>
 * <item>3 to 4</item>
 * <item>4 to 5</item>
 * </list>
 *
 * Backward migration (e.g. 3 to 2) is unsupported.
 *
 * @section Creation and Registration
 *
 * The main migration method is -migrateItems:.
 *
 * You create a migration by overriding -migrateItems: in a subclass, or setting 
 * a migration block, finally you must register it at launch time.
 *
 * <example>
 * COSchemaMigration *migration = [COSchemaMigration new];
 *
 * [migration setMigrationBlock: ^(COSchemaMigration *migration, NSArray *storeItems)
 * {
 *     NSMutableArray *newItems = [NSMutableArray new];
 *
 *     for (COItem *item in storeItems)
 *     {
 *         newItem = [item mutableCopy];
 *         [newItem removeValueForAttribute: @"whatever"];
 *         [newItem setValue: migration.destinationVersion
 *              forAttribute: kCOSchemaVersion];
 *     }
 *
 *     return newItems;
 * }];
 *
 * [COSchemaMigration registerMigration: migration];
 *
 * // Now COEditingContext or COObjectGraphContext can be created.
 * </example>
 *
 * @section Integration with Object Graph Contexts
 *
 * COObjectGraphContext can transparenly migrate inner objects to more recent 
 * schema version at loading time, by accessing registered migrations when there 
 * is a mismatch between the version declared in the store items and the 
 * metamodel one.
 */
@interface COSchemaMigration : NSObject
{
	@private
	NSString *_domain;
	int64_t _destinationVersion;
	COMigrationBlock _migrationBlock;
}


/** @taskunit Schema Migration Registration */


/**
 * Registers a schema migration.
 *
 * See +migrationForVersion:.
 */
+ (void)registerMigration: (COSchemaMigration *)migration;
/**
 * Returns a schema migration to update store items to a newer schema version.
 *
 * The returned migration applies to store items one version behind, items using 
 * an older schema version must be first migrated to <em>version - 1</em>.
 *
 * See +registerMigration: and -destinationVersion.
 */
+ (COSchemaMigration *)migrationForDomain: (NSString *)domain
                       destinationVersion: (NSInteger)version;


/** @taskunit Migrating to Future Versions */


+ (NSArray *)migrateItems: (NSArray *)storeItems
withModelDescriptionRepository: (ETModelDescriptionRepository *)repo;


/** @taskunit Targeted Versions */


/**
 * The domain that must correspond to a package name in the metamodel.
 *
 * See -[ETPackageDescription name] and -[COCommitDescriptor domain].
 */
@property (nonatomic, copy) NSString *domain;
/**
 * The new schema version.
 *
 * By default, returns 0.
 *
 * See -sourceVersion.
 */
@property (nonatomic, assign) int64_t destinationVersion;
/**
 * The old schema version, one version behind -destinationVersion.
 *
 * By default, returns 0.
 *
 * A source schema version is included in each item passed to -migrateItems:,
 * both values must match to carry the migration out.
 */
@property (nonatomic, readonly) int64_t sourceVersion;
/**
 * A migration block called by -migrateItems:.
 *
 * You can put the migration logic in this block, rather than creating a 
 * subclass and overriding -migrateItems:.
 */
@property (nonatomic, copy) COMigrationBlock migrationBlock;


/** @taskunit Migration Process */


/**
 * <override-dummy />
 * Returns new store items at -destinationVersion migrated from old store items
 * at -sourceVersion.
 *
 * You must not call the superclass implementation.
 */
- (NSArray *)migrateItems: (NSArray *)storeItems;

@end
