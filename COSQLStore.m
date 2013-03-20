#import "COSQLStore.h"
#import "FMDatabase.h"


@implementation COSQLStore

- (id)initWithURL: (NSURL*)aURL
{
	self = [super initWithURL: aURL];
	if (self == nil)
		return nil;

	db = [[FMDatabase alloc] initWithPath: [url path]];
	if (![self setupDB])
	{
		[NSException raise: NSInternalInconsistencyException
				 	format: _(@"WARNING: Failed to create DB at %@"), aURL];
		[self release];
		return nil;
	}
	return self;
}

- (void)dealloc
{
	[db release];
	[super dealloc];
}

- (ETUUID *)UUID
{
	FMResultSet *resultSet = [db executeQuery: @"SELECT uuid FROM storeUUID"];
	ETUUID *uuid = nil;

	if ([resultSet next])
	{
		uuid = [ETUUID UUIDWithString: [resultSet stringForColumnIndex: 0]];
	}
	[resultSet close];

	return uuid;
}

/* DB Setup */

void CHECK(id db)
{
	if ([db hadError]) { 
		NSLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]); 
	}
}

/**
 * Returns the latest schema version.
 *
 * For each new store at the current URL, the returned version is set as the store version.
 */
- (int64_t)version
{
	return 2;
}

- (void)adjustDBForPerformance
{
	// FIXME: Not sure whether to use or not.
	//[db setShouldCacheStatements: YES];

#if 0
	FMResultSet *setToWAL = [db executeQuery: @"PRAGMA journal_mode=WAL"];
	[setToWAL next];
	if (![@"wal" isEqualToString: [setToWAL stringForColumnIndex: 0]])
	{
		NSLog(@"Enabling WAL mode failed.");
	}
	[setToWAL close];
#endif
}

- (int64_t)schemaVersionFromExistingDB
{
	FMResultSet *storeVersionRS = [db executeQuery: @"SELECT version FROM storeMetadata"];
	
	if ([storeVersionRS next])
	{
		int64_t ver = [storeVersionRS longLongIntForColumnIndex: 0];
		[storeVersionRS close];
		return ver;
	}
	else
	{
		[storeVersionRS close];
	}
	return 0;
}


/* Explanation of full-text search

   The FTS3 table actually has two columns: rowid, which is an integer primary
   key, and content, which is the string content which will be indexed.

   Each row inserted in to the commits table will specifies a {property : value} 
   tuple for a given object modified in a given commit, and the rows are 
   identified by the commitrow column. So when we insert a row in to commits 
   that we want to be searchable, we also insert into the commitsTextSearch 
   table (commitrow, <text to be indexed>).

   To get full-text search results, we search for text in the commitsTextSearch
   table, which gives us a table of commitrow integers, which we can look up in 
   the commits table for the actual search results. */
- (BOOL)setUpTablesForCurrentSchema
{
	BOOL success = YES;

	/* Store Metadata tables (including schema version) */

	success = success && [db executeUpdate: @"CREATE TABLE storeUUID(uuid STRING  PRIMARY KEY)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE TABLE storeMetadata(version INTEGER PRIMARY KEY, plist BLOB)"]; CHECK(db);
	
	success = success && [db executeUpdate: @"INSERT INTO storeUUID(uuid) VALUES(?)", [[ETUUID UUID] stringValue]]; CHECK(db);
	success = success && [db executeUpdate: @"INSERT INTO storeMetadata(version) VALUES(?)", [NSNumber numberWithLongLong: [self version]]]; CHECK(db);
	
	/* Main Index Tables 
	 
	   Instead of storing UUIDs and property names thoughout the database, we
	   store them in two tables, and use integer ID's to refer to those 
	   UUIDs/property names. */
	
	// UUID Index table
	success = success && [db executeUpdate: @"CREATE TABLE uuids(uuidIndex INTEGER PRIMARY KEY, uuid STRING UNIQUE, rootIndex INTEGER)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX uuidsIndex ON uuids(uuid)"]; CHECK(db);
	
	// Property Index table
	success = success && [db executeUpdate: @"CREATE TABLE properties(propertyIndex INTEGER PRIMARY KEY, property STRING UNIQUE)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX propertiesIndex ON properties(property)"]; CHECK(db);
	
	/* Persistent Root and Branch Tables */
	
	// Persistent Root table (cheap copies share the same root object UUID
	// than the persistent root that owns their parent track)
	success = success && [db executeUpdate: @"CREATE TABLE persistentRoots(uuid INTEGER PRIMARY KEY, rootobjectuuid INTEGER, mainbranchuuid INTEGER, deleted BOOLEAN)"]; CHECK(db);
	
	// Branch and Cheap Copy table
	success = success && [db executeUpdate: @"CREATE TABLE branches(uuid INTEGER PRIMARY KEY, persistentrootuuid INTEGER, parentrevisionnumber INTEGER, name STRING, copied BOOLEAN, deleted BOOLEAN)"]; CHECK(db);
	
	/* Commit Tables */
	
	// Commit Metadata Table
	success = success && [db executeUpdate: @"CREATE TABLE commitMetadata(revisionnumber INTEGER PRIMARY KEY, baserevisionnumber INTEGER, plist BLOB)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX commitsIndex ON commitMetadata(revisionnumber)"]; CHECK(db);
	
	// Commit table for storing the actual commit data (values/keys modified in each commit)
	success = success && [db executeUpdate: @"CREATE TABLE commits(commitrow INTEGER PRIMARY KEY, revisionnumber INTEGER, committrackuuid INTEGER, objectuuid INTEGER, property INTEGER, value BLOB)"]; CHECK(db);
	// Full-Text Search table (see method comment at the beginning)
	success = success && [db executeUpdate: @"CREATE VIRTUAL TABLE commitsTextSearch USING fts3()"];	 CHECK(db);
	
	/* Track Tables */
	
	// Track Node table
	success = success && [db executeUpdate: @"CREATE TABLE trackNodes(id INTEGER PRIMARY KEY, trackuuid INTEGER, revisionnumber INTEGER, nextnode INTEGER, prevnode INTEGER)"]; CHECK(db);
	// Track table
	success = success && [db executeUpdate: @"CREATE TABLE tracks(uuid INTEGER PRIMARY KEY, currentnode INTEGER)"]; CHECK(db);
	
	return success;
}

- (BOOL)setupDB
{
	if (![db open])
	{
		NSLog(@"WARNING: couldn't open db at %@", url);
		return NO;
	}
	[self adjustDBForPerformance];
	
	/* DB creation and schema version check */

	int64_t existingSchemaVersion = [self schemaVersionFromExistingDB];
	BOOL isNewDB = (existingSchemaVersion == 0);

	if (isNewDB)
	{
		return [self setUpTablesForCurrentSchema];
	}
	else if (existingSchemaVersion != [self version])
	{
		NSLog(@"ERROR: unsupported store version %" PRId64 " (supported version is %" PRId64 ")",
			  existingSchemaVersion, [self version]);
		return NO;
	}

	/* DB exists and matches our schema version */
	return YES;
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


- (int) currentStoreVersion
{
	FMResultSet *resultSet = [db executeQuery: @"SELECT MAX(version) FROM storeMetadata"];
	int version = -1;

	if ([resultSet next])
	{
		version = [resultSet intForColumnIndex: 0];
	}
	else
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Missing store version"]; 	
	}
	[resultSet close];

	return version;
}

- (NSDictionary *)metadata
{
	FMResultSet *resultSet = 
		[db executeQuery: @"SELECT plist FROM storeMetadata WHERE version == (SELECT MAX(version) FROM storeMetadata)"];
	NSData *plistData = nil;
	
	if ([resultSet next])
	{
		plistData = [resultSet dataForColumnIndex: 0];
	}
	[resultSet close];

	if (plistData == nil)
	{
		return [NSDictionary dictionary];
	}

	id plist = [NSPropertyListSerialization propertyListFromData: plistData
	                                            mutabilityOption: NSPropertyListImmutable
	                                                      format: NULL
	                                            errorDescription: NULL];

	ETAssert([plist isKindOfClass: [NSDictionary class]]);
	return plist;
}

- (void)setMetadata: (NSDictionary *)plist
{
	NILARG_EXCEPTION_TEST(plist);

	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList: plist
	                                                               format: NSPropertyListXMLFormat_v1_0
	                                                     errorDescription: NULL];

	if (plistData == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Failed to serialize metadata plist %@", plist];
	}

	[db executeUpdate: @"UPDATE storeMetadata SET plist = ? WHERE version == (SELECT MAX(version) FROM storeMetadata)", 
		plistData]; CHECK(db);
}

/* Persistent Roots */

- (BOOL)isRootObjectUUID: (ETUUID *)uuid
{
	NILARG_EXCEPTION_TEST(uuid);
    FMResultSet *rs = [db executeQuery: @"SELECT rootobjectuuid FROM persistentRoots WHERE rootobjectuuid = ?",
	                                    [self keyForUUID: uuid]];
	BOOL result = [rs next];
	[rs close];
	return result;
}

- (NSSet *)rootObjectUUIDs
{
    FMResultSet *rs = [db executeQuery: @"SELECT DISTINCT uuids.uuid FROM uuids JOIN persistentRoots ON uuids.uuidindex = persistentRoots.rootobjectuuid"];
	NSMutableSet *result = [NSMutableSet set];

	while ([rs next])
	{
		[result addObject: [ETUUID UUIDWithString: [rs stringForColumn: @"uuid"]]];
	}

	[rs close];
	return result;
}

- (NSArray *)keysForUUIDs: (NSArray *)UUIDs
{
	NSMutableArray *keys = [NSMutableArray arrayWithCapacity: [UUIDs count]];

	for (ETUUID *uuid in UUIDs)
	{
		[keys addObject: [self keyForUUID: uuid]];
	}
	return keys;
}

- (NSSet *)objectUUIDsOutsideOfParentTracksForCommitTrackUUID: (ETUUID *)aUUID
                                                   atRevision: (CORevision *)revision
{
	NSString *query = [NSString stringWithFormat: @"SELECT DISTINCT uuids.uuid FROM uuids JOIN commits ON uuids.uuidindex = commits.objectuuid WHERE commits.committrackuuid  = %@", [self keyForUUID: aUUID]];
	
	if (revision != nil)
	{
		NSNumber *revNumber = [NSNumber numberWithLongLong: [revision revisionNumber]];
		query = [query stringByAppendingString:
				 [NSString stringWithFormat: @" and revisionnumber <= %@", revNumber]];
	}
	
	FMResultSet *rs = [db executeQuery: query]; CHECK(db);
	NSMutableSet *result = [NSMutableSet set];
	
	while ([rs next])
	{
		[result addObject: [ETUUID UUIDWithString: [rs stringForColumn: @"uuid"]]];
	}
	ETAssert([result containsObject: aUUID] == NO);
	
	[rs close];
	return result;
}

// TODO: This may need to be optimised by storing a list of object UUIDs at some revisions.
- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID atRevision: (CORevision *)revision
{
	NILARG_EXCEPTION_TEST(aUUID);

	NSArray *trackUUIDs = [[self parentTrackUUIDsForCommitTrackUUID: aUUID] arrayByAddingObject: aUUID];
	NSMutableSet *result = [NSMutableSet set];
	CORevision *rev = revision;

	for (ETUUID *trackUUID in [trackUUIDs reverseObjectEnumerator])
	{
		CORevision *parentRev = [self parentRevisionForCommitTrackUUID: trackUUID];
		[result unionSet: [self objectUUIDsOutsideOfParentTracksForCommitTrackUUID: trackUUID
		                                                                atRevision: rev]];
		rev = parentRev;
	}
	return result;
}

- (NSNumber *)anyTrackIndexForObjectUUID: (ETUUID *)aUUID
{
	FMResultSet *rs = [db executeQuery: @"SELECT committrackuuid FROM commits WHERE objectuuid = ? LIMIT 1", [self keyForUUID: aUUID]]; CHECK(db);
	NSNumber *result = nil;
	
	if ([rs next])
	{
		result = [NSNumber numberWithLongLong: [rs longLongIntForColumn: @"committrackuuid"]];
		/* We expect a single result */
		ETAssert([rs next] == NO);
	}

	[rs close];
	return result;
}

- (ETUUID *)rootObjectUUIDForObjectUUID: (ETUUID *)aUUID
{
	NILARG_EXCEPTION_TEST(aUUID);

    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE uuidindex = (SELECT rootobjectuuid FROM persistentRoots WHERE uuid = (SELECT persistentrootuuid FROM branches WHERE uuid = ?))", [self anyTrackIndexForObjectUUID: aUUID]]; CHECK(db);
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

- (ETUUID *)rootObjectUUIDForPersistentRootUUID: (ETUUID *)aPersistentRootUUID
{
	NILARG_EXCEPTION_TEST(aPersistentRootUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE uuidIndex = (SELECT rootobjectuuid FROM persistentRoots WHERE uuid = ?)", [self keyForUUID: aPersistentRootUUID]]; CHECK(db);
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

- (BOOL)isPersistentRootUUID: (ETUUID *)uuid
{
	NILARG_EXCEPTION_TEST(uuid);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM persistentRoots WHERE uuid = ?",
					   [self keyForUUID: uuid]];
	BOOL result = [rs next];
	[rs close];
	return result;
}

- (ETUUID *)persistentRootUUIDForCommitTrackUUID: (ETUUID *)aTrackUUID
{
	NILARG_EXCEPTION_TEST(aTrackUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE uuidIndex = (SELECT persistentrootuuid FROM branches WHERE uuid = ?)", [self keyForUUID: aTrackUUID]]; CHECK(db);
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

- (ETUUID *)mainBranchUUIDForPersistentRootUUID: (ETUUID *)aUUID
{
	NILARG_EXCEPTION_TEST(aUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE uuidIndex = (SELECT mainbranchuuid FROM persistentRoots WHERE uuid = ?)", [self keyForUUID: aUUID]]; CHECK(db);
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

- (ETUUID *)persistentRootUUIDForRootObjectUUID: (ETUUID *)aUUID
{
	NILARG_EXCEPTION_TEST(aUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids WHERE uuidIndex = (SELECT uuid FROM persistentRoots WHERE rootobjectuuid = ?)", [self keyForUUID: aUUID]]; CHECK(db);
	ETUUID *result = nil;
	
	if ([rs next])
	{
		result = [ETUUID UUIDWithString: [rs stringForColumn: @"uuid"]];
		/* We expect a single result */
		ETAssert([rs next] == NO);
	}
	
	[rs close];
	return result;
	return nil;
}

- (void)insertPersistentRootUUID: (ETUUID *)aPersistentRootUUID
				 commitTrackUUID: (ETUUID *)aMainBranchUUID
				  rootObjectUUID: (ETUUID *)aRootObjectUUID
{
	NILARG_EXCEPTION_TEST(aPersistentRootUUID);
	NILARG_EXCEPTION_TEST(aMainBranchUUID);
	NILARG_EXCEPTION_TEST(aRootObjectUUID);
	
	NSString *uuidString = [aPersistentRootUUID stringValue];
	assert([uuidString isKindOfClass: [NSString class]]);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM persistentRoots WHERE uuid = ?",
		[self keyForUUID: aPersistentRootUUID]];
	BOOL wasInsertedPreviously = [rs next];

	[rs close];

	// TODO: Check root object was not inserted previously
	if (wasInsertedPreviously)
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"The persistent root UUID %@ was inserted previously.", aPersistentRootUUID];
		return;
	}

	// TODO: Remove
	NSNumber *rootIndex = [self keyForUUID: aRootObjectUUID];
	[db executeUpdate: @"UPDATE uuids SET rootIndex = ? WHERE uuidIndex = ?", rootIndex, rootIndex]; CHECK(db);

	// TODO: Merge multiple INSERT into a single one

	NSNumber *persistentRootIndex = [self keyForUUID: aPersistentRootUUID];
	// TODO: Should we use NSNumber *rootObjectIndex = [self keyForUUID: aRootObjectUUID];
	NSNumber *rootObjectIndex = rootIndex;
	NSNumber *trackIndex = [self keyForUUID: aMainBranchUUID];

	[db executeUpdate: @"INSERT INTO persistentRoots VALUES(?, ?, ?, NULL)", persistentRootIndex, rootObjectIndex, trackIndex]; CHECK(db);
	[db executeUpdate: @"INSERT INTO branches VALUES(?, ?, NULL, '', NULL, NULL)", trackIndex, persistentRootIndex]; CHECK(db);
}

/* Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary *)metadata
			 persistentRootUUID: (ETUUID *)aPersistentRootUUID
				commitTrackUUID: (ETUUID *)aTrackUUID
                   baseRevision: (CORevision *)baseRevision
				 
{
	NSNumber *baseRevisionNumber = nil;
	if (nil != baseRevision)
	{
		baseRevisionNumber = [NSNumber numberWithLongLong: [baseRevision revisionNumber]];
	}
	if (nil == metadata)
	{
		// Needed because GNUstep persists nil so that it loads again as @"nil"
		metadata = [NSDictionary dictionary];
	}
	if (commitInProgress != nil)
	{
		[NSException raise: NSGenericException format: @"Attempt to call -beginCommitWithMetadata: while a commit is already in progress."];
	}
	/*if ([self isRootObjectUUID: rootUUID] == NO)
	{
		[NSException raise: NSGenericException format: @"The object UUID %@ is not listed among the root objects.", rootUUID];	
	}*/

	commitInProgress = [[NSNumber numberWithUnsignedLongLong: [self latestRevisionNumber] + 1] retain];
	ASSIGN(rootInProgress, [self keyForUUID: aPersistentRootUUID]);
	ASSIGN(trackInProgress, [self keyForUUID: aTrackUUID]);

	NSMutableDictionary *commitMetadata = [NSMutableDictionary dictionaryWithDictionary: metadata];

	// TODO: Should we include the persistent root and commit track among the metadata...
	[commitMetadata addEntriesFromDictionary: 
		D([[ETUUID UUID] stringValue], @"UUID", [NSDate date], @"date", [aPersistentRootUUID stringValue], @"persistentRootUUID", [aTrackUUID stringValue], @"commitTrackUUID")];

	NSData *data = [NSPropertyListSerialization dataFromPropertyList: commitMetadata
															  format: NSPropertyListXMLFormat_v1_0
													errorDescription: NULL];
	
	[db beginTransaction];

	[db executeUpdate: @"INSERT INTO commitMetadata(revisionnumber, baserevisionnumber, plist) VALUES(?, ?, ?)",
		commitInProgress, baseRevisionNumber, data];
	CHECK(db);
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

	NSData *data = nil;

	if (value != nil)
	{
		data = [NSPropertyListSerialization dataFromPropertyList: value
		                                                  format: NSPropertyListXMLFormat_v1_0
		                                        errorDescription: NULL];
	}	
	if (data == nil && value != nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Error serializing object %@", value];
	}
	//NSLog(@"STORE WRITE (%@) object %@, property %@, value %@", commitInProgress, object, property, value);

	[db executeUpdate: @"INSERT INTO commits(commitrow, revisionnumber, committrackuuid, objectuuid, property, value) VALUES(NULL, ?, ?, ?, ?, ?)",
		commitInProgress,
		trackInProgress,
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
	
	CORevision *result = [self revisionWithRevisionNumber: [commitInProgress unsignedLongLongValue]];
	int64_t commitNodeID = [self addRevision: result
	                             toTrackUUID: [self UUIDForKey: [trackInProgress longLongValue]]];

	[db commit];
	
	DESTROY(commitInProgress);
	DESTROY(rootInProgress);
	DESTROY(trackInProgress);

	return [[[CORevision alloc] initWithStore: self
	                           revisionNumber: [result revisionNumber]
	                       baseRevisionNumber: [[result baseRevision] revisionNumber]
	                             commitNodeID: commitNodeID] autorelease];
}

/* Accessing History Graph and Committed Changes */

- (CORevision*)revisionWithRevisionNumber: (int64_t)anID
{
	NSNumber *idNumber = [NSNumber numberWithUnsignedLongLong: anID];
	CORevision *result = [commitObjectForID objectForKey: idNumber];
	if (result == nil)
	{
		FMResultSet *rs = [db executeQuery:@"SELECT revisionnumber, baserevisionnumber FROM commitMetadata WHERE revisionnumber = ?", idNumber]; CHECK(db);
		if ([rs next])
		{
			int64_t baseRevisionNumber = [rs longLongIntForColumnIndex: 1];
			CORevision *commitObject = [[[CORevision alloc] initWithStore: self revisionNumber: anID baseRevisionNumber: baseRevisionNumber commitNodeID: NSIntegerMax] autorelease];
			[commitObjectForID setObject: commitObject
								  forKey: idNumber];
			result = commitObject;
		}
		[rs close];
	}
	return result;
}

- (NSArray *)revisionsForObjectUUIDs: (NSSet *)uuids
{
	NSMutableArray *revs = [NSMutableArray array];
	NSMutableArray *idNumbers = [NSMutableArray array];

	// TODO: Slow and ugly... Can probably be eliminated with a Join-like operation.
	for (ETUUID *uuid in uuids)
	{
		[idNumbers addObject: [self keyForUUID: uuid]];
	}

	NSString *formattedIdNumbers = [[[idNumbers stringValue] 
		componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] 
		componentsJoinedByString: @""];
	// NOTE: We use a distinct query string because -executeQuery returns nil with 'WHERE xyz IN ?'
	NSString *query = [NSString stringWithFormat: 
		@"SELECT DISTINCT commitMetadata.revisionnumber, baserevisionnumber FROM commitMetadata "
		"JOIN commits ON commits.revisionnumber = commitMetadata.revisionNumber "
		"WHERE commits.objectUUID IN %@ ORDER BY commitMetadata.revisionnumber", formattedIdNumbers];
	FMResultSet *rs = [db executeQuery: query];

	while ([rs next])
	{
		int64_t result = [rs longLongIntForColumnIndex: 0];
		int64_t baseRevision = [rs longLongIntForColumnIndex: 1];
		CORevision *rev = [[[CORevision alloc] initWithStore: self
		                                      revisionNumber: result 
		                                  baseRevisionNumber: baseRevision
		                                        commitNodeID: NSIntegerMax] autorelease];

		[revs addObject: rev];
	}
	[rs close];

	return revs;
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
			NSString *value = [[[self revisionWithRevisionNumber: commitKey] valuesAndPropertiesForObjectUUID: objectUUID] objectForKey: property];
			
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

- (int64_t) latestRevisionNumber
{
	FMResultSet *rs = [db executeQuery:@"SELECT MAX(revisionnumber) FROM commitMetadata"];
	int64_t num = 0;
	if ([rs next])
	{
		num = [rs longLongIntForColumnIndex: 0];
	}
	[rs close];
	return num;
}

- (void)didChangeCurrentNodeFromRevision: (CORevision *)oldRev 
                                  toNode: (NSNumber *)newNode 
                                revision: (CORevision *)newRev
                             onTrackUUID: (ETUUID *)aTrackUUID
{
	// TODO: Should we compute kCONewCurrentNodeIndexKey to resync tracks more easily...
	NSDictionary *infos = D(newNode, kCONewCurrentNodeIDKey, 
		[NSNumber numberWithLongLong: [newRev revisionNumber]], kCONewCurrentNodeRevisionNumberKey, 
		[NSNumber numberWithLongLong: [oldRev revisionNumber]], kCOOldCurrentNodeRevisionNumberKey, 
		[[self UUID] stringValue], kCOStoreUUIDStringKey); 
	[(id)[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStoreDidChangeCurrentNodeOnTrackNotification 
	                                                               object: [aTrackUUID stringValue]
	                                                             userInfo: infos
	                                                   deliverImmediately: YES];
}

- (CORevision *)createCommitTrackWithUUID: (ETUUID *)aBranchUUID
							         name: (NSString *)aBranchName
                           parentRevision: (CORevision *)aRevision
				           rootObjectUUID: (ETUUID *)aRootObjectUUID
                       persistentRootUUID: (ETUUID *)aPersistentRootUUID
                      isNewPersistentRoot: (BOOL)isNewPersistentRoot
{
	NILARG_EXCEPTION_TEST(aPersistentRootUUID);
	NILARG_EXCEPTION_TEST(aBranchUUID);

	ETUUID *parentTrackUUID = [aRevision trackUUID];
	
	if ([[self persistentRootUUIDForCommitTrackUUID: parentTrackUUID] isEqual: aPersistentRootUUID] == NO)
	{
		[NSException raise: NSInvalidArgumentException
		            format: _(@"Persistent root UUID %@ doesn't match the parent "
		                       "revision persistent root UUID %@. The parent "
		                       "revision belongs to a commit track bound to "
		                       "another persistent root UUID."), aPersistentRootUUID,
		                    [self persistentRootUUIDForCommitTrackUUID: parentTrackUUID]];
	}

	// TODO: Record the commit track creation details in the metadata
	[self beginCommitWithMetadata: nil
	           persistentRootUUID: nil
	              commitTrackUUID: [self UUID]
	                 baseRevision: aRevision];

	NSNumber *persistentRootIndex = [self keyForUUID: aPersistentRootUUID];
	NSNumber *trackIndex = [self keyForUUID: aBranchUUID];
	NSNumber *rootObjectIndex = [self keyForUUID: aRootObjectUUID];

	if (isNewPersistentRoot)
	{
		ETAssert([self isPersistentRootUUID: aPersistentRootUUID] == NO);

		[db executeUpdate: @"INSERT INTO persistentRoots VALUES(?, ?, ?, NULL)", persistentRootIndex, rootObjectIndex, trackIndex]; CHECK(db);
	}
	else
	{
		ETAssert([[self rootObjectUUIDForPersistentRootUUID: aPersistentRootUUID]
			isEqual: aRootObjectUUID]);
	}


	BOOL isCheapCopy = (isNewPersistentRoot && aRevision != nil);
	NSString *branchName = (aBranchName != nil ? aBranchName : @"");
	NSNumber *parentRevNumber = nil;

	if (aRevision != nil)
	{
		parentRevNumber = [NSNumber numberWithLongLong: [aRevision revisionNumber]];
	}
	[db executeUpdate: @"INSERT INTO branches VALUES(?, ?, ?, ?, ?, NULL)", trackIndex, persistentRootIndex, parentRevNumber, branchName, [NSNumber numberWithBool: isCheapCopy]]; CHECK(db);

	return [self finishCommit];
}

- (CORevision *)parentRevisionForCommitTrackUUID: (ETUUID *)aTrackUUID
{
	NILARG_EXCEPTION_TEST(aTrackUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT parentrevisionnumber FROM branches WHERE uuid = ?",
		[self keyForUUID: aTrackUUID]]; CHECK(db);
	CORevision *rev = nil;

	if ([rs next])
	{
		rev = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
	}
	[rs close];
	return rev;
}

- (NSString *)nameForCommitTrackUUID: (ETUUID *)aTrackUUID
{
	NILARG_EXCEPTION_TEST(aTrackUUID);
    FMResultSet *rs = [db executeQuery: @"SELECT name FROM branches WHERE uuid = ?", [self keyForUUID: aTrackUUID]]; CHECK(db);
	NSString *result;
	
	if ([rs next])
	{
		result = [rs stringForColumn: @"name"];
		/* We expect a single result */
		ETAssert([rs next] == NO);
	}
	
	[rs close];
	return result;
}

- (CORevision *)maxRevision: (int64_t)maxRevNumber forCommitTrackUUID: (ETUUID *)aTrackUUID
{
	BOOL hasMaxRev = (maxRevNumber > 0);

	if (hasMaxRev == NO)
	{
		maxRevNumber = [self latestRevisionNumber];
	}

	FMResultSet *rs = [db executeQuery: @"SELECT MAX(revisionnumber) FROM uuids "
		"JOIN commits ON uuids.uuidIndex = commits.committrackuuid "
		"WHERE revisionnumber <= ? AND commits.committrackuuid = ?",
		[NSNumber numberWithLongLong: maxRevNumber], [self keyForUUID: aTrackUUID]]; CHECK(db);

	if ([rs next])
	{
		return [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
	}
	return nil;
}

- (CORevision *)currentRevisionForTrackIndex: (NSNumber *)aTrackIndex
                               currentNodeID: (int64_t *)currentNodeID
                              previousNodeID: (int64_t *)previousNodeID
                                  nextNodeID: (int64_t *)nextNodeID
{
	FMResultSet *rs = [db executeQuery: @"SELECT tracks.uuid, currentnode, revisionnumber, nextnode, prevnode FROM tracks JOIN trackNodes ON id = currentnode WHERE tracks.uuid = ?", aTrackIndex]; CHECK(db);

	if ([rs next])
	{
		if (currentNodeID != NULL)
		{
			*currentNodeID = [rs longLongIntForColumnIndex: 1];
		}
		if (previousNodeID != NULL)
		{
			*previousNodeID = [rs longLongIntForColumnIndex: 4];
		}
		if (nextNodeID != NULL)
		{
			*nextNodeID =[rs longLongIntForColumnIndex: 3];
		}
		return [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 2]];
	}
	return nil;
}

- (NSArray *)nodesForTrackUUID: (ETUUID *)aTrackUUID
                   nodeBuilder: (id <COTrackNodeBuilder>)aNodeBuilder
              currentNodeIndex: (NSUInteger *)currentNodeIndex
                 backwardLimit: (NSUInteger)backward
                  forwardLimit: (NSUInteger)forward
{
	NILARG_EXCEPTION_TEST(aTrackUUID);
	NILARG_EXCEPTION_TEST(aNodeBuilder);

	NSUInteger capacity = (forward + backward + 1);

	if (backward == NSUIntegerMax || forward == NSUIntegerMax)
	{
		capacity = 1000;
	}
	if (capacity == NSUIntegerMax)
	{
		[NSException raise: NSInvalidArgumentException
					format: @"Forward and backward limit sum must be below NSUIntegerMax."];
	}
	NSMutableArray *nodes = [NSMutableArray arrayWithCapacity: capacity];
	NSNumber *trackIndex = [self keyForUUID: aTrackUUID];
	int64_t currentNodeID = 0;
	int64_t trackNodeID = 0;
	int64_t nextNodeID = 0;
	int64_t prevNodeID = 0;
	CORevision *revision = [self currentRevisionForTrackIndex: trackIndex
	                                            currentNodeID: &currentNodeID
	                                           previousNodeID: &prevNodeID
	                                               nextNodeID: &nextNodeID];

	/* Insert the middle mode (revision) or return */

	BOOL isEmptyTrack = (revision == nil);
	
	if (isEmptyTrack)
	{
		if (currentNodeIndex != NULL)
		{
			*currentNodeIndex = NSNotFound;
		}

		/* Fall back on the parent track content in case the track table doesn't 
		   exist yet for the commit track (no revisions yet) */
		CORevision *parentRev = [self parentRevisionForCommitTrackUUID: aTrackUUID];
		ETUUID *parentTrackUUID = [parentRev trackUUID];

		if (parentTrackUUID == nil)
			return nodes;
		
		revision = parentRev;
		currentNodeID = [parentRev commitNodeID];
		prevNodeID = [[parentRev baseRevision] commitNodeID];
		/* Same as setting forward argument to 0 */
		nextNodeID = NSIntegerMax;
		ETAssert(currentNodeID != NSIntegerMax && prevNodeID != NSIntegerMax);
	}

	[nodes addObject: [aNodeBuilder makeNodeWithID: currentNodeID revision: revision]];

	/* Retrieve the backward revisions along the track (starting at the middle node) */

	for (int i = 0; i < backward; i++)
	{
		FMResultSet *rs = [db executeQuery: @"SELECT revisionnumber, prevnode FROM trackNodes WHERE id = ?", [NSNumber numberWithLongLong: prevNodeID]]; CHECK(db);

		if ([rs next] == NO)
			break;
	
		trackNodeID = prevNodeID;
		revision = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
		prevNodeID = [rs longLongIntForColumnIndex: 1];

		[nodes insertObject: [aNodeBuilder makeNodeWithID: trackNodeID revision: revision]
		            atIndex: 0];
	}

	if (currentNodeIndex != NULL)
	{
		*currentNodeIndex = ([nodes isEmpty] ? 0 : [nodes count] - 1);
	}

	/* Retrieve the forward revisions on the track */

	for (int i = 0; i < forward; i++)
	{
		FMResultSet *rs = [db executeQuery: @"SELECT revisionnumber, nextnode FROM trackNodes WHERE id = ?", [NSNumber numberWithLongLong: nextNodeID]]; CHECK(db);

		if ([rs next] == NO)
			break;

		trackNodeID = nextNodeID;
		revision = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
		nextNodeID = [rs longLongIntForColumnIndex: 1];
	
		[nodes addObject: [aNodeBuilder makeNodeWithID: trackNodeID revision: revision]];
	}

	return nodes;
}

- (void)setCurrentRevision: (CORevision *)newRev 
              forTrackUUID: (ETUUID *)aTrackUUID
{
	CORevision *oldRev = [self currentRevisionForTrackUUID: aTrackUUID];
	FMResultSet *resultSet = [db executeQuery: @"SELECT id "
		"FROM trackNode WHERE objectuuid = ? AND revisionnumber = ?", 
		[self keyForUUID: aTrackUUID], [NSNumber numberWithLongLong: [newRev revisionNumber]]]; CHECK(db);
	NSNumber *node = nil;

	if ([resultSet next])
	{
		node = [NSNumber numberWithLongLong: [resultSet longLongIntForColumnIndex: 0]];
	}
	else
	{
		[NSException raise: NSInternalInconsistencyException
					format: @"Unable to find revision number %qd in track %@ to retrieve the current node",
		                    [newRev revisionNumber], aTrackUUID]; 
	}
	[db executeUpdate: @"UPDATE tracks SET currentnode = ? WHERE uuid = ?",
		node, [self keyForUUID: aTrackUUID]]; CHECK(db);

	[self didChangeCurrentNodeFromRevision: oldRev toNode: node revision: newRev onTrackUUID: aTrackUUID];
}

- (int64_t)addRevision: (CORevision *)newRevision toTrackUUID: (ETUUID *)aTrackUUID
{
	NSNumber *trackIndex = [self keyForUUID: aTrackUUID];
	NSNumber *revNumber = [NSNumber numberWithLongLong: [newRevision revisionNumber]];
	NSNumber *newNode = nil;
	int64_t oldNodeID = 0;
	CORevision *oldRev = [self currentRevisionForTrackIndex: trackIndex
	                                          currentNodeID: &oldNodeID
	                                         previousNodeID: NULL
	                                             nextNodeID: NULL];
	BOOL isNewTrack = (oldRev == nil);

	if (isNewTrack)
	{
		//NSLog(@"Create track %@", aTrackUUID);

		[db executeUpdate: @"INSERT INTO trackNodes(id, trackuuid, revisionnumber, nextnode, prevnode) VALUES (NULL, ?, ?, NULL, NULL)", trackIndex, revNumber]; CHECK(db);

		NSNumber *newNode = [NSNumber numberWithLongLong: [db lastInsertRowId]];

		[db executeUpdate: @"INSERT INTO tracks(uuid, currentnode) VALUES (?, ?)", trackIndex, newNode]; CHECK(db);
	}
	else
	{
		NSNumber *oldNode = [NSNumber numberWithLongLong: oldNodeID];
		NSNumber *prevNode = revNumber;
		
		[db executeUpdate: @"INSERT INTO trackNodes(id, trackuuid, revisionnumber, prevnode, nextnode) VALUES (NULL, ?, ?, ?, NULL)", trackIndex, prevNode, oldNode]; CHECK(db);
	
		NSNumber *newNode = [NSNumber numberWithLongLong: [db lastInsertRowId]];

		[db executeUpdate: @"UPDATE trackNodes SET nextnode = ? WHERE id = ? AND trackuuid = ?", newNode, oldNode, trackIndex]; CHECK(db);
		[db executeUpdate: @"UPDATE tracks SET currentnode = ? WHERE uuid = ?", newNode, trackIndex]; CHECK(db);

		//NSLog(@"Add revision %@ bound to node %@ pointed to by %@ to track %@ ", newRevision, newNode, oldNode, aTrackUUID); 

		[self didChangeCurrentNodeFromRevision: oldRev toNode: newNode revision: newRevision onTrackUUID: aTrackUUID];
	}

	return [newNode longLongValue];
}

- (CORevision *)undoOnTrackUUID: (ETUUID *)aTrackUUID
{
	CORevision *oldRev = [self currentRevisionForTrackIndex: [self keyForUUID: aTrackUUID]
	                                          currentNodeID: NULL
	                                         previousNodeID: NULL
	                                             nextNodeID: NULL];
 	NSNumber *trackIndex = [self keyForUUID: aTrackUUID];

	/* Find the previous node */

	FMResultSet *rs = [db executeQuery: @"SELECT prevnode FROM tracks ct "
		"JOIN trackNodes ctn ON ct.currentNode = ctn.id "
		"WHERE ct.uuid = ?", trackIndex]; CHECK(db);

	if ([rs next] == NO)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Track not found for %@", aTrackUUID];
		return nil;
	}

	/* Update the track current node and return its revision */

	NSNumber *prevNode = [NSNumber numberWithLongLong: [rs longLongIntForColumnIndex: 0]];

	if ([prevNode longLongValue] == 0)
	{
		[NSException raise: NSInvalidArgumentException
					format: @"Track %@ is already at the beginning and undo is invalid.",
		                    aTrackUUID];
	}

	[db executeUpdate: @"UPDATE tracks SET currentnode = ? WHERE uuid = ?",
		prevNode, trackIndex]; CHECK(db);
	rs = [db executeQuery: @"SELECT revisionnumber FROM trackNodes WHERE id = ?",
		prevNode]; CHECK(db);

	if ([rs next])
	{
		CORevision *newRev = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
		[self didChangeCurrentNodeFromRevision: oldRev
		                                toNode: prevNode
		                              revision: newRev
		                           onTrackUUID: aTrackUUID];
		return newRev;
	}
	else
	{
		[NSException raise: NSInternalInconsistencyException
					format: @"Unable to find node %@ on track %@", prevNode, aTrackUUID]; 
	}

	return nil;
}

- (CORevision *)redoOnTrackUUID: (ETUUID *)aTrackUUID
{
	CORevision *oldRev = [self currentRevisionForTrackIndex: [self keyForUUID: aTrackUUID]
	                                          currentNodeID: NULL
				                             previousNodeID: NULL
		                                         nextNodeID: NULL];
	NSNumber *trackIndex = [self keyForUUID: aTrackUUID];

	/* Find the next node */

	FMResultSet *rs = [db executeQuery: @"SELECT nextNode FROM tracks ct "
		"JOIN trackNodes ctn ON ct.currentNode = ctn.id "
		"WHERE ct.uuid = ?", trackIndex]; CHECK(db);

	if ([rs next] == NO)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Track not found for %@", aTrackUUID];
		return nil;
	}

	NSNumber *nextNode = [NSNumber numberWithLongLong: [rs longLongIntForColumnIndex: 0]];

	if ([nextNode longLongValue] == 0)
	{
		[NSException raise: NSInvalidArgumentException
					format: @"Track %@ is already at the end and redo is invalid.", aTrackUUID];
	}
	
	/* Update the track current node and return its revision */

	[db executeUpdate: @"UPDATE tracks SET currentnode = ? WHERE uuid = ?",
		nextNode, trackIndex]; CHECK(db);
	rs = [db executeQuery: @"SELECT revisionnumber FROM trackNodes WHERE id = ?",
		nextNode]; CHECK(db);

	if ([rs next])
	{
		CORevision *newRev = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
		[self didChangeCurrentNodeFromRevision: oldRev
		                                toNode: nextNode
		                              revision: newRev
		                           onTrackUUID: aTrackUUID];
		return newRev;
	}
	else
	{
		[NSException raise: NSInternalInconsistencyException
					format: @"Unable to find node %@ on track %@", nextNode, aTrackUUID];
	}

	return nil;
}

- (BOOL)isTrackUUID: (ETUUID *)uuid
{
	NILARG_EXCEPTION_TEST(uuid);
    FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM tracks WHERE uuid = ?",
	                                    [self keyForUUID: uuid]];
	BOOL result = [rs next];
	[rs close];
	return result;
}

@end
