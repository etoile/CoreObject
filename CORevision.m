#import "CORevision.h"
#import "FMDatabase.h"
#import "COStore.h"

@implementation CORevision

- (id)initWithStore: (COStore*)aStore revisionNumber: (uint64_t)aRevision
{
	self = [super init];
	store = aStore;
	revisionNumber = aRevision;
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (COStore*)store
{
	return store;
}

- (uint64_t)revisionNumber
{
	return revisionNumber;
}

- (NSDictionary*)metadata
{
	FMResultSet *rs = [store->db executeQuery:@"SELECT plist FROM commitMetadata WHERE revisionnumber = ?",
						[NSNumber numberWithUnsignedLongLong: revisionNumber]];
	if ([rs next])
	{
		NSData *data = [rs dataForColumnIndex: 0];
		id plist = [NSPropertyListSerialization propertyListFromData: data
													mutabilityOption: NSPropertyListImmutable
															  format: NULL
													errorDescription: NULL];
		[rs close];
		return plist;
	}
	[rs close];	
	[NSException raise: NSInternalInconsistencyException format: @"COCommit -metadata failed"];
	return nil;
}

- (NSArray*)changedObjects
{
	NSMutableSet *result = [NSMutableSet set];
	FMResultSet *rs = [store->db executeQuery:@"SELECT objectuuid FROM commits WHERE revisionnumber = ?",
					   [NSNumber numberWithUnsignedLongLong: revisionNumber]];
	while ([rs next])
	{
		[result addObject: [store UUIDForKey: [rs longLongIntForColumnIndex: 0]]];
	}
	[rs close];
	return [result allObjects];
}

- (NSDictionary*)valuesAndPropertiesForObject: (ETUUID*)object
{
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	FMResultSet *rs = [store->db executeQuery:@"SELECT property, value FROM commits WHERE revisionnumber = ? AND objectuuid = ?",
					   [NSNumber numberWithUnsignedLongLong: revisionNumber],
					   [store keyForUUID: object]];
	while ([rs next])
	{
		NSString *property = [store propertyForKey: [rs longLongIntForColumnIndex: 0]];
		NSData *data = [rs dataForColumnIndex: 1];
		id plist = [NSPropertyListSerialization propertyListFromData: data
													mutabilityOption: NSPropertyListImmutable
															  format: NULL
													errorDescription: NULL];
		if (plist == nil)
		{
			[NSException raise: NSInternalInconsistencyException format: @"Store contained an invalid property list"];
		}
		
		[result setObject: plist forKey: property];
	}
	[rs close];	
	return [NSDictionary dictionaryWithDictionary: result];
}

@end
