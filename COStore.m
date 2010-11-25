#import "COStore.h"


@implementation COStore

- (id)initWithURL: (NSURL*)aURL
{
	self = [super init];
	url = [aURL retain];
	db = [[FMDatabase alloc] initWithPath: [url path]];
	commitObjectForUUID = [[NSMutableDictionary alloc] init];
	branchObjectForUUID = [[NSMutableDictionary alloc] init];
	if (![self setupDB])
	{
		NSLog(@"DB Create Failed");
		[self release];
		return nil;
	}
	return self;
}

- (void)dealloc
{
	[commitObjectForUUID release];
	[branchObjectForUUID release];
	[url release];
	[db release];
	[super dealloc];
}

- (NSURL*)URL
{
	return url;
}

/* DB Setup */

void CHECK(id db)
{
	if ([db hadError]) { 
		NSLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]); 
	}
}

- (BOOL)setupDB
{
	// FIXME: Not sure whether to use or not.
	//[db setShouldCacheStatements: YES];
	
	if (![db open])
	{
		NSLog(@"couldn't open db at %@", url);
		return NO;
	}
	
	BOOL success = YES;

	// Should improve performance
#if 0	
	FMResultSet *setToWAL = [db executeQuery: @"PRAGMA journal_mode=WAL"];
	[setToWAL next];
	if (![@"wal" isEqualToString: [setToWAL stringForColumnIndex: 0]])
	{
		NSLog(@"Enabling WAL mode failed.");
	}
	[setToWAL close];
#endif	
	
	FMResultSet *storeVersionRS = [db executeQuery: @"SELECT version FROM storemetadata"];
	if ([storeVersionRS next])
	{
		int ver = [storeVersionRS intForColumnIndex: 0];
		[storeVersionRS close];
		
		if (ver != 1)
		{
			NSLog(@"Error: unsupported store version %d", ver);
			return NO;
		}
		// DB is already set up.
		return YES;
	}
	else
	{
		[storeVersionRS close];
	}
	
	
	// Otherwise, set up the DB
	
	success = success && [db executeUpdate: @"CREATE TABLE storemetadata(version INTEGER)"]; CHECK(db);
	success = success && [db executeUpdate: @"INSERT INTO storemetadata(version) VALUES(1)"]; CHECK(db);
	
	// Instead of storing UUIDs and property names thoughout the database,
	// we store them in two tables, and use integer ID's to refer to those
	// UUIDs/property names.
	
	success = success && [db executeUpdate: @"CREATE TABLE uuids(uuidIndex INTEGER PRIMARY KEY, uuid STRING)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX uuidsIndex ON uuids(uuid)"]; CHECK(db);

	success = success && [db executeUpdate: @"CREATE TABLE properties(propertyIndex INTEGER PRIMARY KEY, property STRING)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX propertiesIndex ON properties(property)"]; CHECK(db);
	
	// One table for storing the actual commit data (values/keys modified in each commit)
	//
	// Explanation of full-text search:
	// The FTS3 table actually has two columns: rowid, which is an integer primary key,
	// and content, which is the string content which will be indexed.
	//
	// Each row inserted in to the commits table will specifies a {property : value} tuple
	// for a given object modified in a given commit, and the rows are identified by the
	// commitrow column. So when we insert a row in to commits that we want to be searchable,
	// we also insert into the commitsTextSearch table (commitrow, <text to be indexed>).
	// 
	// To get full-text search results, we search for text in the commitsTextSearch table, which
	// gives us a table of commitrow integers, which we can look up in the commits table for the
	// actual search results. 
	
	
	success = success && [db executeUpdate: @"CREATE TABLE commits(commitrow INTEGER PRIMARY KEY, commituuid INTEGER, objectuuid INTEGER, property INTEGER, value BLOB)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX commitsIndex ON commits(commituuid)"]; CHECK(db);	
	success = success && [db executeUpdate: @"CREATE VIRTUAL TABLE commitsTextSearch USING fts3()"];	 CHECK(db);
	
	// One table for storing commit metadata
	
	success = success && [db executeUpdate: @"CREATE TABLE commitMetadata(commituuid INTEGER PRIMARY KEY, plist BLOB)"];CHECK(db);
	
	// One table for storing per-object commit metadata. This is the history graph.
	
	success = success && [db executeUpdate: @"CREATE TABLE perObjectCommitMetadata(commituuid INTEGER, objectuuid INTEGER, branchuuid INTEGER, parentcommituuid INTEGER, mergedcommituuid INTEGER)"];		CHECK(db); 
	success = success && [db executeUpdate: @"CREATE INDEX perObjectCommitMetadataIndex ON perObjectCommitMetadata(commituuid)"];CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX childCommitsIndex ON perObjectCommitMetadata(parentcommituuid)"];CHECK(db); // To make -[COCommit childCommitsForObject:] fast
	//
	// The preceeding tables are append-only.
	// The following are the mutable state part of COStore:
	//
	
	// A simple table for named branches
	
	success = success && [db executeUpdate: @"CREATE TABLE namedBranches(branchuuid INTEGER PRIMARY KEY, name STRING, plist BLOB)"]; CHECK(db);

	// A simple table for storing the current branch of each object
	
	success = success && [db executeUpdate: @"CREATE TABLE currentBranchForObject(objectuuid INTEGER PRIMARY KEY, branchuuid INTEGER)"]; CHECK(db);
	
	
	// Finally, a table for storing the current state of objects on various branches
	
	success = success && [db executeUpdate: @"CREATE TABLE objectState(objectuuid INTEGER, branchuuid INTEGER, tipcommituuid INTEGER, currentcommituuid INTEGER)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX objectStateIndex ON objectState(objectuuid)"];CHECK(db);
	
	// And a table for storing entity names.
	
	success = success && [db executeUpdate: @"CREATE TABLE objectEntity(objectuuid INTEGER PRIMARY KEY, entityname STRING)"]; CHECK(db);	
	
	return success;
}

- (NSNumber*)keyForUUID: (ETUUID*)uuid
{
	if (uuid == nil)
	{
		return nil;
	}
	
	int64_t key;
	NSString *string = [uuid stringValue];
	assert([string isKindOfClass: [NSString class]]);
    FMResultSet *rs = [db executeQuery:@"SELECT uuidIndex FROM uuids WHERE uuid = ?", string];
	if ([rs next])
	{
		key = [rs longLongIntForColumnIndex: 0];
		[rs close];
	}
	else
	{
		[rs close];
		[db executeUpdate: @"INSERT INTO uuids VALUES(NULL, ?)", [uuid stringValue]];
		key = [db lastInsertRowId];
	}
	return [NSNumber numberWithLongLong: key];
}

- (NSNumber*)keyForProperty: (NSString*)property
{
	if (property == nil)
	{
		return nil;
	}
	
	int64_t key;
    FMResultSet *rs = [db executeQuery:@"SELECT propertyIndex FROM properties WHERE property = ?", property];
	if ([rs next])
	{
		key = [rs longLongIntForColumnIndex: 0];
		[rs close];
	}
	else
	{
		[rs close];
		[db executeUpdate: @"INSERT INTO properties VALUES(NULL, ?)", property];
		key = [db lastInsertRowId];
	}  
	return [NSNumber numberWithLongLong: key];
}

- (ETUUID*)UUIDForKey: (int64_t)key
{
	ETUUID *result = nil;
    FMResultSet *rs = [db executeQuery:@"SELECT uuid FROM uuids WHERE uuidIndex = ?",
					   [NSNumber numberWithLongLong: key]];
	if ([rs next])
	{
		result = [ETUUID UUIDWithString: [rs stringForColumnIndex: 0]];
	}
	[rs close];
	return result;
}

- (NSString*)propertyForKey: (int64_t)key
{
	NSString *result = nil;
    FMResultSet *rs = [db executeQuery:@"SELECT property FROM properties WHERE propertyIndex = ?",
					   [NSNumber numberWithLongLong: key]];
	if ([rs next])
	{
		result = [rs stringForColumnIndex: 0];
	}
	[rs close];
	return result;
}

/* Named branches */

- (CONamedBranch*)createNamedBranch
{
	ETUUID *uuid = [ETUUID UUID];
	[db executeUpdate: @"INSERT INTO namedbranches VALUES(?, NULL, NULL)", 
	 [self keyForUUID: uuid]];
	
	CONamedBranch *branchObject = [[[CONamedBranch alloc] initWithStore: self uuid: uuid] autorelease];
	[branchObjectForUUID setObject: branchObject
							forKey: uuid];
	return branchObject;
}

- (CONamedBranch*)namedBranchForUUID: (ETUUID*)uuid
{
	CONamedBranch *result = [branchObjectForUUID objectForKey: uuid];
	if (result == nil)
	{
		FMResultSet *rs = [db executeQuery:@"SELECT branchuuid FROM namedBranches WHERE branchuuid = ?",
						  [self keyForUUID: uuid]];
		if ([rs next])
		{
			CONamedBranch *branchObject = [[[CONamedBranch alloc] initWithStore: self uuid: uuid] autorelease];
			[branchObjectForUUID setObject: branchObject
									forKey: uuid];
			result = branchObject;
		}
		[rs close];
	}
	return result;
}

/* Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary*)meta
{
	if (commitInProgress != nil)
	{
		[NSException raise: NSGenericException format: @"Attempt to call -beginCommitWithMetadata: while a commit is already in progress."];
	}
	commitInProgress = [[ETUUID alloc] init];
	
	NSData *data = [NSPropertyListSerialization dataFromPropertyList: meta
															  format: NSPropertyListXMLFormat_v1_0
													errorDescription: NULL];
	
	[db beginTransaction];
	
	[db executeUpdate: @"INSERT INTO commitMetadata VALUES(?, ?)",
		[self keyForUUID: commitInProgress],
		data];
}

- (void)beginChangesForObject: (ETUUID*)object
				onNamedBranch: (CONamedBranch*)namedBranch
			updateObjectState: (BOOL)updateState
				 parentCommit: (COCommit*)parent
				 mergedCommit: (COCommit*)mergedBranch
{
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	if (objectInProgress != nil)
	{
		[NSException raise: NSGenericException format: @"Finish the current object first"];
	}
	objectInProgress = [object retain];
	
	[db executeUpdate: @"INSERT INTO perObjectCommitMetadata(commituuid, objectuuid, branchuuid, parentcommituuid, mergedcommituuid) VALUES(?, ?, ?, ?, ?)",
		[self keyForUUID: commitInProgress],
		[self keyForUUID: objectInProgress],
		[self keyForUUID: [namedBranch UUID]],
		[self keyForUUID: [parent UUID]],
		[self keyForUUID: [mergedBranch UUID]]];
	CHECK(db);
	
	if (updateState)
	{
		ETUUID *tipUUID = [self tipForObjectUUID:object onBranch:namedBranch];
		ETUUID *currentUUID = [self currentCommitForObjectUUID:object onBranch: namedBranch];
		
		if ([tipUUID isEqual: currentUUID])
		{
			[self setTip: commitInProgress forObjectUUID:object onBranch:namedBranch];
			[self setCurrentCommit: commitInProgress forObjectUUID:object onBranch:namedBranch];
		}
		else
		{
			[self setTip: commitInProgress forObjectUUID:object onBranch:namedBranch];
			if (currentUUID == nil)
			{
				[self setCurrentCommit: commitInProgress forObjectUUID:object onBranch:namedBranch];
			}
		}
	}
}

- (void)setValue: (id)value
	 forProperty: (NSString*)property
		ofObject: (ETUUID*)object
	 shouldIndex: (BOOL)shouldIndex
{
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	if (![objectInProgress isEqual: object])
	{
		[NSException raise: NSGenericException format: @"Object in progress doesn't match"];
	}

	NSData *data = [NSPropertyListSerialization dataFromPropertyList: value
															  format: NSPropertyListXMLFormat_v1_0
													errorDescription: NULL];	
	if (data == nil && value != nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Error serializing object %@", value];
	}
	
	[db executeUpdate: @"INSERT INTO commits(commitrow, commituuid, objectuuid, property, value) VALUES(NULL, ?, ?, ?, ?)",
		[self keyForUUID: commitInProgress],
		[self keyForUUID: objectInProgress],
		[self keyForProperty: property],
		data];
	CHECK(db);
	
	if (shouldIndex)
	{
		if ([value isKindOfClass: [NSString class]])
		{
			int64_t commitrow = [db lastInsertRowId];
			
			[db executeUpdate: @"INSERT INTO commitsTextSearch(docid, content) VALUES(?, ?)",
			 [NSNumber numberWithLongLong: commitrow],
			 value];
			CHECK(db);
		}
		else
		{
			NSLog(@"Error, only strings can be indexed.");
		}
	}
}

- (void)finishChangesForObject: (ETUUID*)object
{
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	if (![objectInProgress isEqual: object])
	{
		[NSException raise: NSGenericException format: @"Object in progress doesn't match"];
	}
	[objectInProgress release];
	objectInProgress = nil;
}

- (COCommit*)finishCommit
{
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	[db commit];
	
	COCommit *result = [self commitForUUID: commitInProgress];
	
	[commitInProgress release];
	commitInProgress = nil;

	return result;
}

/* Accessing History Graph and Committed Changes */

- (COCommit*)commitForUUID: (ETUUID*)uuid;
{
	COCommit *result = [commitObjectForUUID objectForKey: uuid];
	if (result == nil)
	{
		FMResultSet *rs = [db executeQuery:@"SELECT commituuid FROM commitMetadata WHERE commituuid = ?",
						   [self keyForUUID: uuid]];
		if ([rs next])
		{
			COCommit *commitObject = [[[COCommit alloc] initWithStore: self uuid: uuid] autorelease];
			[commitObjectForUUID setObject: commitObject
									forKey: uuid];
			result = commitObject;
		}
		[rs close];
	}
	return result;
}

/* Object State */

- (NSArray*)branchesForObjectUUID: (ETUUID*)object
{
	NSMutableArray *result = [NSMutableArray array];
	FMResultSet *rs = [db executeQuery:@"SELECT branchuuid FROM objectState WHERE objectuuid = ?",
					   [self keyForUUID: object]];
	while ([rs next])
	{
		CONamedBranch *branch = [self namedBranchForUUID: [self UUIDForKey: [rs longLongIntForColumnIndex: 0]]];
		[result addObject: branch];
	}
	[rs close];
	return result;
}

- (CONamedBranch*)activeBranchForObjectUUID: (ETUUID*)object
{
	CONamedBranch *result = nil;
	FMResultSet *rs = [db executeQuery:@"SELECT branchuuid FROM currentBranchForObject WHERE objectuuid = ?",
					   [self keyForUUID: object]];
	if ([rs next])
	{
		result = [self namedBranchForUUID: [self UUIDForKey: [rs longLongIntForColumnIndex: 0]]];
	}
	[rs close];
	return result;
}

- (void)setActiveBranch: (CONamedBranch*)branch forObjectUUID: (ETUUID*)object
{
	BOOL createTransaction = ![db inTransaction];
	if (createTransaction) { [db beginTransaction]; }
	
	if (nil != [self activeBranchForObjectUUID: object])
	{
		[db executeUpdate: @"UPDATE currentBranchForObject SET branchuuid = ? WHERE objectuuid = ?",
		 [self keyForUUID: [branch UUID]],
		 [self keyForUUID: object]];
		CHECK(db);
	}
	else
	{
		[db executeUpdate: @"INSERT INTO currentBranchForObject(objectuuid, branchuuid) VALUES(?, ?)",
		 [self keyForUUID: [branch UUID]],
		 [self keyForUUID: object]];
		CHECK(db);
	}
	
	if (createTransaction) { [db commit]; }
}

- (ETUUID*)currentCommitForObjectUUID: (ETUUID*)uuid onBranch: (CONamedBranch*)branch
{
	ETUUID *result = nil;
	NSString *query;
	if (branch == nil)
	{
		query = @"SELECT currentcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid IS NULL";
	}
	else
	{
		query = @"SELECT currentcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid = ?";
	}

	FMResultSet *rs = [db executeQuery: query,
					   [self keyForUUID: uuid],
					   [self keyForUUID: [branch UUID]]];
	if ([rs next])
	{
		result = [self UUIDForKey: [rs longLongIntForColumnIndex: 0]];
	}
	[rs close];
	return result;
}

- (BOOL)setCurrentCommit: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch
{
	BOOL createTransaction = ![db inTransaction];
	if (createTransaction) { [db beginTransaction]; }
	
	NSString *query;
	if (branch == nil)
	{
		query = @"SELECT tipcommituuid, currentcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid IS NULL";
	}
	else
	{
		query = @"SELECT tipcommituuid, currentcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid = ?";
	}
	
	FMResultSet *rs = [db executeQuery: query,
					   [self keyForUUID: object],
					   [self keyForUUID: [branch UUID]]];
	if ([rs next])
	{		
		NSString *query2;
		if (branch == nil)
		{
			query2 = @"UPDATE objectState SET currentcommituuid = ? WHERE objectuuid = ? AND branchuuid IS NULL";
		}
		else
		{
			query2 = @"UPDATE objectState SET currentcommituuid = ? WHERE objectuuid = ? AND branchuuid = ?";
		}
		[db executeUpdate: query2,
		 [self keyForUUID: commit],
		 [self keyForUUID: object],
		 [self keyForUUID: [branch UUID]]];
		CHECK(db);			
	}
	else
	{
		[db executeUpdate: @"INSERT INTO objectState(objectuuid, branchuuid, tipcommituuid, currentcommituuid) VALUES(?, ?, ?, ?)",
		 [self keyForUUID: object],
		 [self keyForUUID: [branch UUID]],
		 [self keyForUUID: commit],
		 [self keyForUUID: commit]];
		CHECK(db);
	}
	[rs close];
	
	if (createTransaction) { [db commit]; }
	return YES;
}

- (ETUUID*)tipForObjectUUID: (ETUUID*)uuid onBranch: (CONamedBranch*)branch
{
	ETUUID *result = nil;
	NSString *query;
	if (branch == nil)
	{
		query = @"SELECT tipcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid IS NULL";
	}
	else
	{
		query = @"SELECT tipcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid = ?";
	}
	
	FMResultSet *rs = [db executeQuery: query,
					   [self keyForUUID: uuid],
					   [self keyForUUID: [branch UUID]]];
	if ([rs next])
	{
		result = [self UUIDForKey: [rs longLongIntForColumnIndex: 0]];
	}
	[rs close];
	return result;
}

- (BOOL)setTip: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch
{
	BOOL createTransaction = ![db inTransaction];
	if (createTransaction) { [db beginTransaction]; }
	
	NSString *query;
	if (branch == nil)
	{
		query = @"SELECT tipcommituuid, currentcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid IS NULL";
	}
	else
	{
		query = @"SELECT tipcommituuid, currentcommituuid FROM objectState WHERE objectuuid = ? AND branchuuid = ?";
	}
	
	FMResultSet *rs = [db executeQuery: query,
					   [self keyForUUID: object],
					   [self keyForUUID: [branch UUID]]];
	if ([rs next])
	{		
		NSString *query2;
		if (branch == nil)
		{
			query2 = @"UPDATE objectState SET tipcommituuid = ? WHERE objectuuid = ? AND branchuuid IS NULL";
		}
		else
		{
			query2 = @"UPDATE objectState SET tipcommituuid = ? WHERE objectuuid = ? AND branchuuid = ?";
		}
		[db executeUpdate: query2,
		 [self keyForUUID: commit],
		 [self keyForUUID: object],
		 [self keyForUUID: [branch UUID]]];
		CHECK(db);			
	}
	else
	{
		[db executeUpdate: @"INSERT INTO objectState(objectuuid, branchuuid, tipcommituuid, currentcommituuid) VALUES(?, ?, ?, ?)",
		 [self keyForUUID: object],
		 [self keyForUUID: [branch UUID]],
		 [self keyForUUID: commit],
		 [self keyForUUID: commit]];
		CHECK(db);
	}
	[rs close];
	
	if (createTransaction) { [db commit]; }
	return YES;
}

- (NSString*)entityNameForObjectUUID: (ETUUID*)object
{
	NSString *result = nil;
	FMResultSet *rs = [db executeQuery:@"SELECT entityname FROM objectEntity WHERE objectuuid = ?",
					   [self keyForUUID: object]];
	if ([rs next])
	{
		result = [rs stringForColumnIndex: 0];
	}
	[rs close];
	return result;	
}
- (void)setEntityName: (NSString*)name forObjectUUID: (ETUUID*)object
{
	BOOL ok = [db executeUpdate: @"INSERT INTO objectEntity(objectuuid, entityname) VALUES(?,?)",
		[self keyForUUID: object],
		name];
	
	if (!ok)
	{
		[NSException raise: NSGenericException format: @"Attempt to change the entity name of object %@", object];
	}
}

/* Full-text Search */

- (NSArray*)resultDictionariesForQuery: (NSString*)query
{
	NSMutableArray *results = [NSMutableArray array];
	FMResultSet *rs = [db executeQuery:@"SELECT rowid FROM commitsTextSearch WHERE content MATCH ?", query];
	CHECK(db);
	while ([rs next])
	{
		int64_t rowIndex = [rs longLongIntForColumnIndex: 0];
		FMResultSet *commitRs = [db executeQuery:@"SELECT commituuid, objectuuid, property FROM commits WHERE commitrow = ?", 
			[NSNumber numberWithLongLong: rowIndex]];
		if ([commitRs next])
		{
			int64_t commitKey = [commitRs longLongIntForColumnIndex: 0];
			int64_t objectKey = [commitRs longLongIntForColumnIndex: 1];
			int64_t propertyKey = [commitRs longLongIntForColumnIndex: 2];
			
			ETUUID *commitUUID = [self UUIDForKey: commitKey];
			ETUUID *objectUUID = [self UUIDForKey: objectKey];
			NSString *property = [self propertyForKey: propertyKey];
			
			assert(commitUUID != nil);
			assert(objectUUID != nil);
			assert(property != nil);
			
			[results addObject: 
				[NSDictionary dictionaryWithObjectsAndKeys:
					commitUUID, @"commitUUID",
					objectUUID, @"objectUUID",
					property, @"property",
					nil]];
		}
		else
		{
			[NSException raise: NSInternalInconsistencyException format: @"FTS table refers to a non-existent commit"];
		}
		[commitRs close];
	}
	[rs close];
	
	return results;
}

@end
