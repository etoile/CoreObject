#import <Cocoa/Cocoa.h>
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
