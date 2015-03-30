/**
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COSchemaMigration;
@class COSchemaMigrationDriver;

typedef NSArray *(^COMigrationBlock)(COSchemaMigration *migration, NSArray *storeItems);

/**
 * @group Schema Migration
 * @abstract Schema migration model operating at storage data model level.
 *
 * COSchemaMigration supports arbitrary complex migrations such as reorganizing 
 * relationships, or even ditching the entire metamodel used previously.
 *
 * COObjectGraphContext can transparenly migrate inner objects to more recent
 * schema version at loading time, by accessing registered migrations when there
 * is a mismatch between the version declared in the store items and the
 * metamodel one.
 *
 * @section Migration Process Overview
 *
 * Migrations are run per object graph context. For each persistent root's 
 * branch, a migration can occur in two situations:
 *
 * <list>
 * <item>at loading time, the entire item graph is migrated just before 
 * instantiating any inner objects</item>
 * <item>when applying an item diff, a partial item graph is migrated and
 * inserted into the object graph causing the matching inner objects to be reloaded</item>
 * </list>
 *
 * A migration process is triggered by -[COObjectGraphContext insertOrUpdatedItems:] 
 * or -[COObjectGraphContext setItemGraph:], the item domain versions are checked 
 * and compared to the package versions present in -[COObjectGraphContext modelDescriptionRepository], 
 * when there is a mismatch the item is selected to be migrated.
 *
 * For each package, all the items related to it share the same schema version,
 * these items are migrated sequentially by executing one or more migrations 
 * bound to this package. We start with the present item version, and continue 
 * until the item version reaches the current version in use in the object graph
 * context.
 *
 * Note: Migrations are supported on transient object graph contexts for 
 * applying item diffs.
 *
 * @section Migration Phases
 *
 * An item can belong to one ore more packages, since the parent entities can 
 * belong to other packages than the one owning its entity (see -[COItem entityName]).
 * All inner objects inherits from COObject, and thereby all inner objects 
 * belong to the CoreObject package (package names are encoded in a reverse 
 * DNS notation e.g. 'org.etoile-project.CoreObject'). 
 *
 * For an entity belonging to a package A in addition to the CoreObject package, 
 * the item based on this entity will undergo two migration phases: CoreObject 
 * and A. For each object graph context that undergoes a migration, there is a 
 * migration phase per package, and a phase is made of multiple 
 * COSchemaMigration.
 *
 * This migration model supports to mix and and match multiple metamodels
 * in the same document or database, and run insulated schema migrations per 
 * metamodel. 
 *
 * @section Design Rules for Migratable Metamodel
 *
 * A package (see ETPackageDescription) regroups related entities. A package 
 * can depend on other packages. A package and all its dependencies makes up
 * a metamodel.
 *
 * The metamodel describes a persistency schema. COItem includes a copy of the
 * persistency schema along its property values, that's why items can be
 * migrated towards the metamodel attached to a COObjectGraphContext without 
 * requiring older metamodel verions to be present in memory.
 *
 * When using entities from other packages (outside of your control), the inner 
 * object arrangment can define an implicit schema. For example, a tree of
 * COContainer can be used to model a structured document. However you won't be 
 * able to evolve it with a COSchemaMigration, since COContainer is a CoreObject 
 * entity (the items will only be handed to migrations registered by the
 * CoreObject package).
 *
 * So it is important to create your own package and entities to control the 
 * metamodel and schema, unless you extend an existing metamodel over which you 
 * don't want full control.
 *
 * As a result, model classes bundled in CoreObject such as COContainer, 
 * COGroup, COObject etc. should be subclassed. In few cases, you might want to 
 * use some classes/entities as is, for instance COTag or COTagGroup which are 
 * both pretty generic, but still nothing prevents you to subclass them to 
 * support migrating them later on.
 *
 * @section Libary Versioning and Metamodel Compatibility
 *
 * For example, Diagram or PageLayout frameworks can be built on top of a 
 * StructuredGraphics framework, itself built on top of CoreObject. Diagram and 
 * PageLayout includes persistent entities that extend entities in 
 * StructuredGraphics. All the four frameworks can evolve their persistency 
 * schema independently. When new framework versions with compatible API are
 * installed, a CoreObject store will be migrated transparently, the next time
 * it is loaded.
 *
 * A store is read and written by compatible libraries/frameworks loaded in 
 * memory. When libraries are loaded in memory, we assume these libraries are 
 * schema compatible (and not just API compatible). The versioning at the
 * library level is responsible to ensure the schema remains compatible with 
 * existing libraries depending on it. If a library introduces a breaking change, 
 * it must be bump its major version to prevent the loading of libraries that
 * are not compatible with this new schema without an update.
 *
 * @section Schema Breaking Changes
 *
 * To explain how CoreObject can support breaking changes cleanly, we will 
 * consider two packages A and B and bundled in two respective libraries AL and 
 * BL.
 *
 * B depends on A and AL depends on BL.
 *
 * For a breaking change in A, we must:
 *
 * <list>
 * <item>increment A version and increment AL major version</item>
 * <item>increment B version and increment BL minor version (or major version if 
 * we introduce a breaking change to cope with the breaking change in A)</item>
 * <item>bundle the breaking-change migration targeting A in AL</item>
 * <item>bundle a migration targeting B in BL to cope with the breaking change 
 * in A</item>
 * <list>
 *
 * For properties related operations in A, although they are potentially 
 * breaking changes, in most cases they won't interfer with B, so incrementing B 
 * package version, and bundling a migration that simply updates the B version 
 * stored in the items is all what is needed.
 *
 * For a breaking change, incrementing the library major version is important to
 * prevent loading incompatible package versions present in other libraries. 
 * See Libary Versioning and Metamodel Compatibility section on this topic.
 *
 * To understand precisely what is a breaking change, see Supported Migration
 * Operations section.
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
 * migration.domain = @"com.company.PackageName"
 * migration.destinationVersion = 3
 * migration.migrationBlock = ^(COSchemaMigration *migration, NSArray *storeItems)
 * {
 *     NSMutableArray *newItems = [NSMutableArray new];
 *
 *     for (COItem *item in storeItems)
 *     {
 *         newItem = [item mutableCopy];
 *         [newItem removeValueForAttribute: @"whatever"];
 *         [newItem setVersion: migration.destinationVersion
 *                   forDomain: kCOObjectVersionsProperty];
 *         [newItems addObject: newItem];
 *     }
 *
 *     return newItems;
 * };
 *
 * [COSchemaMigration registerMigration: migration];
 *
 * // Now COEditingContext or COObjectGraphContext can be created.
 * </example>
 *
 * You are responsible to update domain/package versions correctly for all the 
 * items in a migrated package.
 *
 * @section Supported Migration Operations
 *
 * A migration can be broken into primitive operations that alter persistent 
 * entities and properties inside the package they belong to (not considering 
 * the packages owning their parent entities):
 *
 * <list>
 * <item>Entity Addition</item>
 * <item>Entity Deletion</item>
 * <item>Entity Renaming</item>
 * <item>Property Addition</item>
 * <item>Property Deletion</item>
 * <item>Property Renaming</item>
 * </list>
 *
 * For a persistency schema, breaking changes are not the same than the ones
 * for an API.
 *
 * Entity addition and property deletion are non-breaking changes that don't
 * require to increment the package version, all the other operations are 
 * breaking changes (the package version must be incremented).
 *
 * Both property addition and renaming can cause a parent property to be
 * overriden/overshadowed, so property addition or renaming are breaking changes.
 *
 * Persistent properties must not depend on each other (-[ETPropertyDescription 
 * isDerived] is NO), so property deletion is a non-breaking change.
 *
 * All other the other package operations can break the schema compatibility, 
 * and requires every dependent package to be checked and migrated to accept the
 * changes (incrementing the dependent schema version will be enough in many
 * cases).
 *
 * Based on these migration operations, CoreObject supports to move entities
 * and properties accross packages as described in the next section.
 *
 * @section Moving Entities and Properties accross Packages
 *
 * You can declare entity or property moves with COModelElementMove. A move
 * object describes the destination package explicitly, and is attached to a
 * migration in the source package with -[COSchemaMigration entityMoves] or 
 * -[COSchemaMigration propertyMoves].
 *
 * The migration process will run the migration in the source package, then 
 * execute the moves, then run the migration in the destination package (where 
 * the moved items or properties will now appear among the migrated items for 
 * this package).
 *
 * Declaring moves accross packages, implicitly create dependencies between
 * migrations since the destination migration requires the source migration to 
 * be executed (including attached moves), otherwise items or properties would
 * appear to be missing when the destination migration is run.
 *
 * Before starting, the migration process examines all the dependencies among
 * the migrations and schedules them in the correct order. Basically a migration
 * phase can be run until it reaches a migration that depends on another one.
 * In this case, the dependent migration (including migrations preceding it in
 * the phase it belongs to) is executed before, and the dependent migration is
 * examined in turn in case it depends on other migrations too, and so on. Once 
 * dependent migrations are exhausted, the interrupted migration phase continue.
 *
 * Here is an example that shows how to move the entity Person from a Contact
 * package to another one named AddressBook. Contact will go from version 2 
 * to 3 with this migration, while AddressBook version remains 5:
 *
 * <example>
 * COSchemaMigration *migration = [COSchemaMigration new];
 *
 * migration.domain = @"com.company.Contact"
 * migration.destinationVersion = 3
 * migration.migrationBlock = ^(COSchemaMigration *migration, NSArray *storeItems)
 * {
 *     NSMutableArray *newItems = [NSMutableArray new];
 *
 *     for (COItem *item in storeItems)
 *     {
 *         COItem *newItem = [item mutableCopy];
 *         [newItem setVersion: migration.destinationVersion
 *                   forDomain: migration.domain];
 *         [newItems addObject: newItem];
 *     }
 *
 *     return newItems;
 * };
 *
 * COModelElementMove *move = [COModelElementMove new];
 *
 * move.name = @"Person";
 * move.domain = @"com.company.AddressBook";
 * move.version = 5;
 * migration.entityMoves = S(move);
 *
 * [COSchemaMigration registerMigration: migration];
 * </example>
 */
@interface COSchemaMigration : NSObject
{
	@private
	NSString *_domain;
	int64_t _destinationVersion;
	COMigrationBlock _migrationBlock;
	__weak COSchemaMigrationDriver *migrationDriver;
	NSDictionary *_dependentSourceVersionsByDomain;
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
/**
 * Returns a dictionary that contains dependent migrations to be run before a 
 * specific migration. 
 *
 * The dictionary keys are key-value pair, where -[ETKeyValue key] returns the 
 * domain and -[ETKeyValue value] returns the destination version.
 */
+ (NSDictionary *)dependencies;

/**
 * Returns an array of all registered migrations.
 */
+ (NSArray *)migrations;


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
/**
 * Domains depended on by the -sourceVersion of -domain, along with
 * their versions.
 *
 * This acts as a snapshot of the necessary parts of the metamodel at 
 * -sourceVersion.
 */
@property (nonatomic, copy) NSDictionary *dependentSourceVersionsByDomain;

/** @task Move Operations Accross Domains */


@property (nonatomic, copy) NSSet *entityMoves;
@property (nonatomic, copy) NSSet *propertyMoves;


/** @taskunit Migration Process */


/**
 * <override-dummy />
 * Returns new store items at -destinationVersion migrated from old store items
 * at -sourceVersion.
 *
 * You must not call the superclass implementation.
 */
- (NSArray *)migrateItems: (NSArray *)storeItems;



/** @taskunit Private */

@property (nonatomic, readwrite, weak) COSchemaMigrationDriver *migrationDriver;

@end
