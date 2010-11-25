#import "CONamedBranch.h"
#import "COStore.h"

@implementation CONamedBranch

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

- (NSString*)name
{
	FMResultSet *rs = [store->db executeQuery:@"SELECT name FROM namedBranches WHERE branchuuid = ?",
		[store keyForUUID: uuid]];
	if ([rs next])
	{
		NSString *name = [[rs stringForColumnIndex: 0] retain];
		[rs close];
		return [name autorelease];
	}
	[rs close];	
	[NSException raise: NSInternalInconsistencyException format: @"CONamedBranch -name failed"];
	return nil;
}
- (void)setName: (NSString*)name
{
	[store->db executeUpdate: @"UPDATE namedBranches SET name = ? WHERE branchuuid = ?",
	 name,
	 [store keyForUUID: uuid]];
	if ([store->db hadError])
	{
		[NSException raise: NSInternalInconsistencyException format: @"CONamedBranch -setName: failed"];
	}
}

- (NSDictionary*)metadata
{
	FMResultSet *rs = [store->db executeQuery:@"SELECT plist FROM namedBranches WHERE branchuuid = ?",
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
- (void)setMetadata: (NSDictionary*)meta
{
	NSData *data = [NSPropertyListSerialization dataFromPropertyList: meta
															  format: NSPropertyListXMLFormat_v1_0
													errorDescription: NULL];
	
	[store->db executeUpdate: @"UPDATE namedBranches SET plist = ? WHERE branchuuid = ?",
	 data,
	 [store keyForUUID: uuid]];
	if ([store->db hadError])
	{
		[NSException raise: NSInternalInconsistencyException format: @"CONamedBranch -setMetadata: failed"];
	}
}

@end
