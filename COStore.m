#import "COStore.h"
#import "FMDatabase.h"


@implementation COStore

- (id)initWithURL: (NSURL*)aURL
{
	self = [super init];
	url = [aURL retain];
	db = [[FMDatabase alloc] initWithPath: [url path]];
	commitObjectForID = [[NSMutableDictionary alloc] init];

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
	[commitObjectForID release];
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
	
	FMResultSet *storeVersionRS = [db executeQuery: @"SELECT version FROM storeMetadata"];
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
	
	success = success && [db executeUpdate: @"CREATE TABLE storeMetadata(version INTEGER)"]; CHECK(db);
	success = success && [db executeUpdate: @"INSERT INTO storeMetadata(version) VALUES(1)"]; CHECK(db);
	
	// Instead of storing UUIDs and property names thoughout the database,
	// we store them in two tables, and use integer ID's to refer to those
	// UUIDs/property names.
	
	success = success && [db executeUpdate: @"CREATE TABLE uuids(uuidIndex INTEGER PRIMARY KEY, uuid STRING, rootIndex INTEGER)"]; CHECK(db);
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
	
	
	success = success && [db executeUpdate: @"CREATE TABLE commits(commitrow INTEGER PRIMARY KEY, revisionnumber INTEGER, objectuuid INTEGER, property INTEGER, value BLOB)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX commitsIndex ON commits(revisionnumber)"]; CHECK(db);	
	success = success && [db executeUpdate: @"CREATE VIRTUAL TABLE commitsTextSearch USING fts3()"];	 CHECK(db);
	
	// One table for storing commit metadata
	
	success = success && [db executeUpdate: @"CREATE TABLE commitMetadata(revisionnumber INTEGER PRIMARY KEY, plist BLOB)"];CHECK(db);
		
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
		if (rootInProgress != nil)
		{
			[db executeUpdate: @"INSERT INTO uuids VALUES(NULL, ?, ?)", 
			                   [uuid stringValue], rootInProgress];
		}
		else
		{
			// TODO: Not really pretty... Try to merge -insertRootUUID: with 
			// -keyForUUID: to eliminate this branch
			[db executeUpdate: @"INSERT INTO uuids VALUES(NULL, ?, NULL)", [uuid stringValue]];
		}
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

/* Content  */

- (BOOL)isRootObjectUUID: (ETUUID *)uuid
{
	NILARG_EXCEPTION_TEST(uuid);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE uuidIndex = ? AND rootIndex = uuidIndex",
	                                    [self keyForUUID: uuid]];
	BOOL result = [rs next];
	[rs close];
	return result;
}

- (NSSet *)rootObjectUUIDs
{
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE rootIndex = uuidIndex"];
	NSMutableSet *result = [NSMutableSet set];

	while ([rs next])
	{
		[result addObject: [ETUUID UUIDWithString: [rs stringForColumn: @"uuid"]]];
	}

	[rs close];
	return result;
}

- (NSSet *)UUIDsForRootObjectUUID: (ETUUID *)aUUID
{
	NILARG_EXCEPTION_TEST(aUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE rootIndex = ?", [self keyForUUID: aUUID]];
	NSMutableSet *result = [NSMutableSet set];

	while ([rs next])
	{
		[result addObject: [ETUUID UUIDWithString: [rs stringForColumn: @"uuid"]]];
	}
	ETAssert([result containsObject: aUUID]);

	[rs close];
	return result;
}

- (ETUUID *)rootObjectUUIDForUUID: (ETUUID *)aUUID
{
	NILARG_EXCEPTION_TEST(aUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE uuidIndex = "
		"(SELECT rootIndex FROM uuids WHERE uuid = ?)", aUUID];
	ETUUID *result = nil;
	
	if ([rs next])
	{
		result = [ETUUID UUIDWithString: [rs stringForColumn: @"uuid"]];
		/* We expect a single result */
		ETAssert([rs next] == NO);
	}

	[rs close];
	return result;
}

- (void)insertRootObjectUUID: (ETUUID *)uuid
{
	NILARG_EXCEPTION_TEST(uuid);
	
	NSString *uuidString = [uuid stringValue];
	assert([uuidString isKindOfClass: [NSString class]]);
    FMResultSet *rs = [db executeQuery: @"SELECT uuidIndex FROM uuids WHERE uuid = ?", uuidString];
	BOOL wasInsertedPreviously = [rs next];

	[rs close];

	if (wasInsertedPreviously)
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"The persistent root UUID %@ was inserted previously.", uuid];
		return;
	}
	
	// TODO: Merge UPDATE into INSERT if possible
	[db executeUpdate: @"INSERT INTO uuids VALUES(NULL, ?, NULL)", [uuid stringValue]];
	int64_t key = [db lastInsertRowId];
	[db executeUpdate: @"UPDATE uuids SET rootIndex = ? WHERE uuidIndex = ?", 
		[NSNumber numberWithLongLong: key], [NSNumber numberWithLongLong: key]];
}

// TODO: Rewrite to be handled in two transactions (SELECT and INSERT)
- (void) insertRootObjectUUIDs: (NSSet *)UUIDs
{
	for (ETUUID *uuid in UUIDs)
	{
		[self insertRootObjectUUID: uuid];
	}
}

/* Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary *)meta
                 rootObjectUUID: (ETUUID *)rootUUID
				 
{
	if (commitInProgress != nil)
	{
		[NSException raise: NSGenericException format: @"Attempt to call -beginCommitWithMetadata: while a commit is already in progress."];
	}
	if ([self isRootObjectUUID: rootUUID] == NO)
	{
		[NSException raise: NSGenericException format: @"The object UUID %@ is not listed among the root objects.", rootUUID];	
	}

	NSData *data = [NSPropertyListSerialization dataFromPropertyList: meta
															  format: NSPropertyListXMLFormat_v1_0
													errorDescription: NULL];
	
	[db beginTransaction];
	
	[db executeUpdate: @"INSERT INTO commitMetadata(plist) VALUES(?)",
		data];

	commitInProgress = [[NSNumber numberWithUnsignedLongLong: [db lastInsertRowId]] retain];
	ASSIGN(rootInProgress, [self keyForUUID: rootUUID]);
}

- (void)beginChangesForObjectUUID: (ETUUID*)object
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
	//NSLog(@"STORE WRITE (%@) object %@, property %@, value %@", commitInProgress, object, property, value);

	[db executeUpdate: @"INSERT INTO commits(commitrow, revisionnumber, objectuuid, property, value) VALUES(NULL, ?, ?, ?, ?)",
		commitInProgress,
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

	hasPushedChanges = YES;
}

- (void)finishChangesForObjectUUID: (ETUUID*)object
{
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	if (![objectInProgress isEqual: object])
	{
		[NSException raise: NSGenericException format: @"Object in progress doesn't match"];
	}
	if (!hasPushedChanges)
	{
		// TODO: Turn on this exception
		//[NSException raise: NSGenericException format: @"Push changes before finishing the commit"];
	}
	[objectInProgress release];
	objectInProgress = nil;
	hasPushedChanges = NO;
}

- (CORevision*)finishCommit
{
	if (objectInProgress != nil)
	{
		[NSException raise: NSGenericException format: @"Object still in progress"];
	}
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	[db commit];
	
	CORevision *result = [self revisionWithRevisionNumber: [commitInProgress unsignedLongLongValue]];
	
	DESTROY(commitInProgress);
	DESTROY(rootInProgress);
	return result;
}

/* Accessing History Graph and Committed Changes */

- (CORevision*)revisionWithRevisionNumber: (uint64_t)anID
{
	NSNumber *idNumber = [NSNumber numberWithUnsignedLongLong: anID];
	CORevision *result = [commitObjectForID objectForKey: idNumber];
	if (result == nil)
	{
		FMResultSet *rs = [db executeQuery:@"SELECT revisionnumber FROM commitMetadata WHERE revisionnumber = ?",
						   idNumber];
		if ([rs next])
		{
			CORevision *commitObject = [[[CORevision alloc] initWithStore: self revisionNumber: anID] autorelease];
			[commitObjectForID setObject: commitObject
								  forKey: idNumber];
			result = commitObject;
		}
		[rs close];
	}
	return result;
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
		FMResultSet *commitRs = [db executeQuery:@"SELECT revisionnumber, objectuuid, property FROM commits WHERE commitrow = ?", 
			[NSNumber numberWithLongLong: rowIndex]];
		if ([commitRs next])
		{
			int64_t commitKey = [commitRs longLongIntForColumnIndex: 0];
			int64_t objectKey = [commitRs longLongIntForColumnIndex: 1];
			int64_t propertyKey = [commitRs longLongIntForColumnIndex: 2];
			
			NSNumber *revisionNumber = [NSNumber numberWithLongLong: commitKey];
			ETUUID *objectUUID = [self UUIDForKey: objectKey];
			NSString *property = [self propertyForKey: propertyKey];
			NSString *value = [[[self revisionWithRevisionNumber: commitKey] valuesAndPropertiesForObject: objectUUID] objectForKey: property];
			
			assert(revisionNumber != nil);
			assert(objectUUID != nil);
			assert(property != nil);
			assert(value != nil && [value isKindOfClass: [NSString class]]);
					
			[results addObject: 
				[NSDictionary dictionaryWithObjectsAndKeys:
					revisionNumber, @"revisionNumber",
					objectUUID, @"objectUUID",
					property, @"property",
				    value, @"value",
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

/* Revision history */

- (uint64_t) latestRevisionNumber
{
	FMResultSet *rs = [db executeQuery:@"SELECT MAX(revisionnumber) FROM commitMetadata"];
	uint64_t num = 0;
	if ([rs next])
	{
		num = [rs longLongIntForColumnIndex: 0];
	}
	[rs close];
	return num;
}

@end
