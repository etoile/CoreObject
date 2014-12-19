/**
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@interface COSchemaMigrationDriver : NSObject
- (NSArray *)migrateItems: (NSArray *)storeItems
withModelDescriptionRepository: (ETModelDescriptionRepository *)repo;
@end
