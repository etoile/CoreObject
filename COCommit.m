#import "COCommit.h"
#import "COStore.h"

@implementation COCommit

- (id)initWithStore: (COStore*)aStore uuid: (ETUUID*)aUUID
{
	self = [super init];
	store = aStore;
	uuid = [aUUID retain];
	return self;
}

- (void)dealloc
{
	[uuid release];
	[super dealloc];
}

- (ETUUID*)UUID
{
	return uuid;
}

- (NSDictionary*)metadata
{
	FMResultSet *rs = [store->db executeQuery:@"SELECT plist FROM commitMetadata WHERE commituuid = ?",
						[store keyForUUID: uuid]];
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
	[NSException raise: NSInternalInconsistencyException format: @"CONamedBranch -metadata failed"];
	return nil;
}

- (NSArray*)changedObjects
{
	NSMutableArray *result = [NSMutableArray array];
	FMResultSet *rs = [store->db executeQuery:@"SELECT objectuuid FROM commits WHERE commituuid = ?",
					   [store keyForUUID: uuid]];
	while ([rs next])
	{
		[result addObject: [store UUIDForKey: [rs longLongIntForColumnIndex: 0]]];
	}
	[rs close];
	return result;
}

- (CONamedBranch*)namedBranchForObject: (ETUUID*)object
{
	CONamedBranch *result = nil;
	FMResultSet *rs = [store->db executeQuery:@"SELECT branchuuid FROM perObjectCommitMetadata WHERE commituuid = ? AND objectuuid = ?",
					   [store keyForUUID: uuid],
					   [store keyForUUID: object]];
	if ([rs next])
	{
		ETUUID *u = [store UUIDForKey: [rs longLongIntForColumnIndex: 0]];	
		result = [store namedBranchForUUID: u];
	}
	[rs close];	
	return result;
}

- (COCommit*)parentCommitForObject: (ETUUID*)object
{
	COCommit *result = nil;
	FMResultSet *rs = [store->db executeQuery:@"SELECT parentcommituuid FROM perObjectCommitMetadata WHERE commituuid = ? AND objectuuid = ?",
					   [store keyForUUID: uuid],
					   [store keyForUUID: object]];
	if ([rs next])
	{
		ETUUID *u = [store UUIDForKey: [rs longLongIntForColumnIndex: 0]];	
		result = [store commitForUUID: u];
	}
	[rs close];
	return result;
}

- (COCommit*)mergedCommitForObject: (ETUUID*)object
{
	COCommit *result = nil;
	FMResultSet *rs = [store->db executeQuery:@"SELECT mergedcommituuid FROM perObjectCommitMetadata WHERE commituuid = ? AND objectuuid = ?",
					   [store keyForUUID: uuid],
					   [store keyForUUID: object]];
	if ([rs next])
	{
		ETUUID *u = [store UUIDForKey: [rs longLongIntForColumnIndex: 0]];	
		result = [store commitForUUID: u];
	}
	[rs close];	
	return result;
}

- (NSArray*)childCommitsForObject: (ETUUID*)object
{
	NSMutableArray *result = [NSMutableArray array];
	
	// FIXME: Verify that this query executes quickly (it doesn' need to do a linear scan, and it shouldn't)
	FMResultSet *rs = [store->db executeQuery:@"SELECT commituuid FROM perObjectCommitMetadata WHERE parentcommituuid = ? AND objectuuid = ?",
					   [store keyForUUID: uuid],
					   [store keyForUUID: object]];
	while ([rs next])
	{
		ETUUID *cu = [store UUIDForKey: [rs longLongIntForColumnIndex: 0]];
		[result addObject: [store commitForUUID: cu]];
	}
	[rs close];	
	return result;
}

- (NSDictionary*)valuesAndPropertiesForObject: (ETUUID*)object
{
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	FMResultSet *rs = [store->db executeQuery:@"SELECT property, value FROM commits WHERE commituuid = ? AND objectuuid = ?",
					   [store keyForUUID: uuid],
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
	return result;
}

@end
