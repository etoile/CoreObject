/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COStore.h>

@class FMDatabase;

@interface COSQLStore : COStore
{
	//FMDatabase *db;
}

/** @taskunit Private */

- (BOOL)setupDB;
- (NSNumber*)keyForUUID: (ETUUID*)uuid;
- (ETUUID*)UUIDForKey: (int64_t)key;
- (NSNumber*)keyForProperty: (NSString*)property;
- (NSString*)propertyForKey: (int64_t)key;

@end
