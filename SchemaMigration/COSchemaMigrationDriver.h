/**
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COItem;

@interface COSchemaMigrationDriver : NSObject
{
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
