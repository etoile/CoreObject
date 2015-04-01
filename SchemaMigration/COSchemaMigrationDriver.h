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


- (instancetype)initWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo;


/** @taskunit Triggering a Migration */


- (NSArray *)migrateItems: (NSArray *)storeItems;


/** @taskunit Framework private */

- (NSDictionary *) versionsByPackageNameForItem: (COItem *)item;

@end
