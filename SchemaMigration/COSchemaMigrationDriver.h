/**
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COItem;


/**
 * @group Schema Migration
 * @abstract A migration driver is a schema update mechanism operating on the 
 * "semi-serialized" representation of COObject instances.
 *
 * @section Conceptual Model
 *
 * The driver processes a collection of COItem (representing a a partial or 
 * entire object graph) with -migrateItems: through multiple COSchemaMigration.
 *
 * @section Common Use Cases
 *
 * You should almost never need to use this class directly. COSchemaMigration 
 * can be used to write most migration cases in a way that is easier and safer.
 *
 * In some edge cases, like changing item entities/properties accross packages
 * without altering the metamodel, COSchemaMigrationDriver can be subclassed 
 * to override -migrateItems:, then set as -[COEditingContext migrationDriverClass].
 *
 * For example, this makes possible to recover from item graph creation mistakes
 * when the metamodel doesn't require changes (e.g. forgetting to subclass an 
 * entity located in another package).
 */
@interface COSchemaMigrationDriver : NSObject
{
	@private
	ETModelDescriptionRepository *_modelDescriptionRepository;
	NSMutableDictionary *itemsToMigrate;
}


/** @taskunit Initialization */


/** 
 * <init />
 * Initializes a driver to migrate items to the metamodel in the given model 
 * description repository.
 *
 * For a nil repository, raises a NSInvalidArgumentException.
 */
- (instancetype)initWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo;


/** @taskunit Metamodel Access */


/**
 * Returns the model description repository, that holds the metamodel to which
 * items must be migrated to.
 */
@property (nonatomic, readonly) ETModelDescriptionRepository *modelDescriptionRepository;


/** @taskunit Triggering a Migration */


/**
 * Migrates the items to lastest package versions found in -modelDescriptionRepository.
 *
 * Can be overriden to implement a custom migration strategy.
 */
- (NSArray *)migrateItems: (NSArray *)storeItems;


/** @taskunit Framework private */


- (NSDictionary *) versionsByPackageNameForItem: (COItem *)item;

@end
