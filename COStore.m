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

- (NSURL *)URL
{
	return url;
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

	success = success && [db executeUpdate: @"CREATE TABLE storeUUID(uuid STRING)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE TABLE storeMetadata(version INTEGER, plist BLOB)"]; CHECK(db);

	success = success && [db executeUpdate: @"INSERT INTO storeUUID(uuid) VALUES(?)", [[ETUUID UUID] stringValue]]; CHECK(db);
	success = success && [db executeUpdate: @"INSERT INTO storeMetadata(version) VALUES(1)"]; CHECK(db);

	// Instead of storing UUIDs and property names thoughout the database,
	// we store them in two tables, and use integer ID's to refer to those
	// UUIDs/property names.
	
	success = success && [db executeUpdate: @"CREATE TABLE uuids(uuidIndex INTEGER PRIMARY KEY, uuid STRING, rootIndex INTEGER)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX uuidsIndex ON uuids(uuid)"]; CHECK(db);

	success = success && [db executeUpdate: @"CREATE TABLE properties(propertyIndex INTEGER PRIMARY KEY, property STRING)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX propertiesIndex ON properties(property)"]; CHECK(db);

	// One table for storing commit metadata
	
	success = success && [db executeUpdate: @"CREATE TABLE commitMetadata(revisionnumber INTEGER PRIMARY KEY, baserevisionnumber INTEGER, plist BLOB)"]; CHECK(db);
	success = success && [db executeUpdate: @"CREATE INDEX commitsIndex ON commitMetadata(revisionnumber)"]; CHECK(db);	

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
	success = success && [db executeUpdate: @"CREATE VIRTUAL TABLE commitsTextSearch USING fts3()"];	 CHECK(db);
		
	// Commit Track node table
	success = success && [db executeUpdate: @"CREATE TABLE commitTrackNode(committracknodeid INTEGER PRIMARY KEY, objectuuid INTEGER, revisionnumber INTEGER, nextnode INTEGER, prevnode INTEGER)"]; CHECK(db);
	// Commit Track table 
	success = success && [db executeUpdate: @"CREATE TABLE commitTrack(objectuuid INTEGER PRIMARY KEY, currentnode INTEGER)"]; CHECK(db);
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

- (NSSet*)UUIDsForRootObjectUUID: (ETUUID*)aUUID atRevision: (CORevision*)revision
{
	// FIXME: This may need to be optimised by storing a list of object UUIDs
	// at some revisions.
	NSMutableSet *uuids = [NSMutableSet set];
	while (revision != nil)
	{
    		FMResultSet *rs = [db executeQuery: @"SELECT uuid FROM uuids JOIN commits ON uuids.uuidindex = commits.objectuuid "
			"WHERE rootindex = ? AND revisionnumber = ?", 
			[self keyForUUID: aUUID], [NSNumber numberWithLongLong: [revision revisionNumber]]]; CHECK(db);
		while ([rs next])
		{
			[uuids addObject: [ETUUID UUIDWithString: [rs stringForColumn: @"uuid"]]];
		}
		revision = [revision baseRevision];
	}
	return uuids;
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

- (void)beginCommitWithMetadata: (NSDictionary *)metadata
                 rootObjectUUID: (ETUUID *)rootUUID
		   baseRevision: (CORevision*)baseRevision
				 
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
	if ([self isRootObjectUUID: rootUUID] == NO)
	{
		[NSException raise: NSGenericException format: @"The object UUID %@ is not listed among the root objects.", rootUUID];	
	}

	commitInProgress = [[NSNumber numberWithUnsignedLongLong: [self latestRevisionNumber] + 1] retain];
	ASSIGN(rootInProgress, [self keyForUUID: rootUUID]);

	NSMutableDictionary *commitMetadata = [NSMutableDictionary dictionaryWithDictionary: metadata];

	[commitMetadata addEntriesFromDictionary: 
		D([[ETUUID UUID] stringValue], @"UUID", [NSDate date], @"date", [rootUUID stringValue], @"objectUUID")];

	NSData *data = [NSPropertyListSerialization dataFromPropertyList: commitMetadata
															  format: NSPropertyListXMLFormat_v1_0
													errorDescription: NULL];
	
	[db beginTransaction];

	[db executeUpdate: @"INSERT INTO commitMetadata(revisionnumber, baserevisionnumber, plist) VALUES(?, ?, ?)",
		commitInProgress, baseRevisionNumber, data];
	CHECK(db);
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

	NSData *data = [NSPropertyListSerialization 
		dataFromPropertyList: value
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

	CORevision *result = [self revisionWithRevisionNumber: [commitInProgress unsignedLongLongValue]];

	[self addRevision: result toTrackUUID: [self UUIDForKey: [rootInProgress longLongValue]]];
	[db commit];
	
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
		FMResultSet *rs = [db executeQuery:@"SELECT revisionnumber, baserevisionnumber FROM commitMetadata WHERE revisionnumber = ?",
						   idNumber];
		if ([rs next])
		{
			int64_t baseRevisionNumber = [rs longLongIntForColumnIndex: 1];
			CORevision *commitObject = [[[CORevision alloc] initWithStore: self revisionNumber: anID baseRevisionNumber: baseRevisionNumber] autorelease];
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
		uint64_t result = [rs longLongIntForColumnIndex: 0];
		uint64_t baseRevision = [rs longLongIntForColumnIndex: 1];
		CORevision *rev = [[[CORevision alloc] 
			     initWithStore: self 
			    revisionNumber: result 
			baseRevisionNumber: baseRevision] 
				autorelease];

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

- (CORevision*)createCommitTrackForRootObjectUUID: (NSNumber*)uuidIndex
                                         revision: (CORevision *)aRevision
                                    currentNodeId: (int64_t*)pCurrentNodeId
{
	int64_t currentNodeId;
	// TODO: (Chris) Determine if we should use the latest revision number of the store
	// or the last revision number the object occurs in. Really, if we create
	// a commit track for every object, this issue shouldn't arise.
	CORevision *revision = (aRevision != nil ? aRevision : [self revisionWithRevisionNumber: [self latestRevisionNumber]]);
#ifdef GNUSTEP
	NSDebugLLog(@"COStore", @"Creating commit track for object %@", [self UUIDForKey: [uuidIndex longLongValue]]);
#endif
	[db executeUpdate: @"INSERT INTO commitTrackNode(committracknodeid, objectuuid, revisionnumber, nextnode, prevnode) VALUES (NULL, ?, ?, NULL, NULL)",
		uuidIndex, [NSNumber numberWithLongLong: [revision revisionNumber]]]; CHECK(db);
	currentNodeId = [db lastInsertRowId];
	[db executeUpdate: @"INSERT INTO commitTrack(objectuuid, currentnode) VALUES (?, ?)", 
		uuidIndex, [NSNumber numberWithLongLong: currentNodeId]]; CHECK(db);
	if (pCurrentNodeId)
		*pCurrentNodeId = currentNodeId;
	return revision;
}

- (CORevision*)createCommitTrackForRootObjectUUID: (NSNumber*)uuidIndex
                                    currentNodeId: (int64_t*)pCurrentNodeId
{
	return [self createCommitTrackForRootObjectUUID: uuidIndex revision: nil currentNodeId: pCurrentNodeId];
}

- (CORevision*)commitTrackForRootObject: (NSNumber*)objectUUIDIndex
                            currentNode: (int64_t*)pCurrentNode
                           previousNode: (int64_t*)pPreviousNode
                               nextNode: (int64_t*)pNextNode
{
	FMResultSet *rs = [db executeQuery: @"SELECT commitTrack.objectuuid, currentnode, revisionnumber, nextnode, prevnode FROM commitTrack JOIN commitTrackNode ON committracknodeid = currentnode WHERE commitTrack.objectuuid = ?", objectUUIDIndex]; CHECK(db);
	if ([rs next])
	{
		if (pCurrentNode)
			*pCurrentNode = [rs longLongIntForColumnIndex: 1];

		if (pPreviousNode) 
			*pPreviousNode = [rs longLongIntForColumnIndex: 4];
		if (pNextNode)
			*pNextNode =[rs longLongIntForColumnIndex: 3];
		int64_t revisionnumber = [rs longLongIntForColumnIndex: 2];
		return [self revisionWithRevisionNumber: revisionnumber];
	}
	return nil;
}

/**
  * Load the revision numbers for a root object along its commit track.
  * The resulting array of revisions will be (forward + backward + 1) elements
  * long, with the revisions ordered from oldest to last.
  * revision may optionally be nil to find a commit track for an object
  * (or create one if it doesn't exist).
  * 
  * The current implementation is quite inefficient in that it hits the
  * database (forward + backward + 1) time, once for each
  * revision on the commit track.
 */
- (NSArray *)revisionsForTrackUUID: (ETUUID *)objectUUID
                  currentNodeIndex: (NSUInteger *)currentNodeIndex
                     backwardLimit: (NSUInteger)backward
                      forwardLimit: (NSUInteger)forward;
{
	NILARG_EXCEPTION_TEST(objectUUID);
	// TODO: The check below is disabled to support COCustomTrack. We need to 
	// rework the API and database schema to support both commit and custom 
	// tracks cleanly.
	//if (![self isRootObjectUUID: objectUUID])
	//	[NSException raise: NSInvalidArgumentException format: @"The object with UUID %@ does not exist!", objectUUID];

	NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity: (1 + forward + backward)];
	NSNumber *objectUUIDIndex = [self keyForUUID: objectUUID];
	int64_t currentNode = 0;
	int64_t nextNode = 0;
	int64_t prevNode = 0;
	CORevision *revision = [self commitTrackForRootObject: objectUUIDIndex currentNode: &currentNode previousNode: &prevNode nextNode: &nextNode];

	if (nil == revision)
	{
		revision = [self createCommitTrackForRootObjectUUID: objectUUIDIndex currentNodeId: &currentNode];
	}

	// Insert the middle mode (revision)
	[nodes addObject: revision];
	
	// Retrieve the backward revisions along the track (starting at the middle node)
	for (int i = 0; i < backward; i++)
	{
		FMResultSet *rs = [db executeQuery: @"SELECT revisionnumber, prevnode FROM commitTrackNode WHERE objectuuid = ? AND committracknodeid = ?", objectUUIDIndex, [NSNumber numberWithLongLong: prevNode]]; CHECK(db);
		if ([rs next])
		{
			prevNode = [rs longLongIntForColumnIndex: 1];
			revision = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
			[nodes insertObject: revision atIndex: 0];
		}
		else
		{
			BOOL insertNullMarker = (backward != NSUIntegerMax);

			if (insertNullMarker)
			{
				for (int j = i; j < backward; j++)
				{
					[nodes insertObject: [NSNull null] atIndex: 0];
				}
			}
			break;
		}
	}

	if (currentNodeIndex != NULL)
	{
		*currentNodeIndex = [nodes count] - 1;
	}

	// Retrieve the forward revisions on the track
	for (int i = 0; i < forward; i++)
	{
		FMResultSet *rs = [db executeQuery: @"SELECT revisionnumber, nextnode FROM commitTrackNode WHERE objectuuid = ? AND committracknodeid = ?", objectUUIDIndex, [NSNumber numberWithLongLong: nextNode]]; CHECK(db);
		if ([rs next])
		{
			nextNode = [rs longLongIntForColumnIndex: 1];
			revision = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
			[nodes addObject: revision];
		}
		else
		{
			BOOL insertNullMarker = (forward != NSUIntegerMax);

			if (insertNullMarker)
			{
				for (int j = i; j < forward; j++)
				{
					[nodes addObject: [NSNull null]];
				}
			}
			break;
		}
	}
	return [nodes autorelease];
}

- (CORevision *) currentRevisionForTrackUUID: (ETUUID *)aTrackUUID
{
	NSArray *revs = [self revisionsForTrackUUID: aTrackUUID
	                           currentNodeIndex: NULL
	                              backwardLimit: 0
	                               forwardLimit: 0];
	assert([revs count] == 1);
	return [revs firstObject];
}

- (void)setCurrentRevision: (CORevision *)newRev 
              forTrackUUID: (ETUUID *)aTrackUUID
{
	CORevision *oldRev = [self currentRevisionForTrackUUID: aTrackUUID];
	FMResultSet *resultSet = [db executeQuery: @"SELECT committracknodeid "
		"FROM commitTrackNode WHERE objectuuid = ? AND revisionnumber = ?", 
		[self keyForUUID: aTrackUUID], [NSNumber numberWithLongLong: [newRev revisionNumber]]]; CHECK(db);
	NSNumber *node = nil;

	if ([resultSet next])
	{
		node = [NSNumber numberWithLongLong: [resultSet longLongIntForColumnIndex: 0]];
	}
	else
	{
		[NSException raise: NSInternalInconsistencyException
					format: @"Unable to find revision number %q in track %@ to retrieve the current node", 
		                    [newRev revisionNumber], aTrackUUID]; 
	}
	[db executeUpdate: @"UPDATE commitTrack SET currentnode = ? WHERE objectuuid = ?",
		node, [self keyForUUID: aTrackUUID]]; CHECK(db);

	[self didChangeCurrentNodeFromRevision: oldRev toNode: node revision: newRev onTrackUUID: aTrackUUID];
}

// TODO: Or should we name it -pushRevision:onTrackUUID:...
- (void)addRevision: (CORevision *)newRevision toTrackUUID: (ETUUID *)aTrackUUID
{
	NSNumber *track = [self keyForUUID: aTrackUUID];
	int64_t oldNodeId;
	CORevision *oldRev = 
		[self commitTrackForRootObject: track
		                   currentNode: &oldNodeId
				  previousNode: NULL
		                      nextNode: NULL];
	if (oldRev != nil)
	{
		NSNumber *oldNode = [NSNumber numberWithLongLong: oldNodeId];
		NSNumber *prevNode = [NSNumber numberWithLongLong: [newRevision revisionNumber]];
		
		[db executeUpdate: @"INSERT INTO commitTrackNode(committracknodeid, objectuuid, revisionnumber, prevnode, nextnode) "
			"VALUES (NULL, ?, ?, ?, NULL)", 
			track, prevNode, oldNode]; CHECK(db);
	
		NSNumber *newNode = [NSNumber numberWithLongLong: [db lastInsertRowId]];

		[db executeUpdate: @"UPDATE commitTrackNode SET nextnode = ? WHERE committracknodeid = ? AND objectuuid = ?",
			newNode, oldNode, track]; CHECK(db);
		[db executeUpdate: @"UPDATE commitTrack SET currentnode = ? WHERE objectuuid = ?",
			newNode, track]; CHECK(db);

#ifdef GNUSTEP
		NSDebugLLog(@"COStore", @"Updated commit track for %@ - created new commit track node %@ pointed to by %@ for revision %@",
			aTrackUUID, newNode, oldNode, newRevision); 
#endif

		[self didChangeCurrentNodeFromRevision: oldRev toNode: newNode revision: newRevision onTrackUUID: aTrackUUID];
	}
	else
	{
		[self createCommitTrackForRootObjectUUID: track revision: newRevision currentNodeId: NULL];
	}
}
- (CORevision*)undoOnCommitTrack: (ETUUID*)rootObjectUUID
{
	CORevision *oldRev = [self commitTrackForRootObject: [self keyForUUID: rootObjectUUID]
		                   currentNode: NULL
				  previousNode: NULL
		                      nextNode: NULL];
 	NSNumber *rootObjectIndex = [self keyForUUID: rootObjectUUID];
	FMResultSet *rs = [db executeQuery: @"SELECT prevnode FROM commitTrack ct "
		"JOIN commitTrackNode ctn ON ct.currentNode = ctn.committracknodeid "
		"WHERE ct.objectuuid = ?", rootObjectIndex]; CHECK(db);

	if ([rs next])
	{
		NSNumber *prevNode = [NSNumber numberWithLongLong: [rs longLongIntForColumnIndex: 0]];

		if ([prevNode longLongValue] == 0)
		{
			[NSException raise: NSInvalidArgumentException
			            format: @"Root Object UUID %@ is already at the beginning of its commit track and cannot be undone.", rootObjectUUID];
		}

		[db executeUpdate: @"UPDATE commitTrack SET currentnode = ? WHERE objectuuid = ?",
			prevNode, rootObjectIndex]; CHECK(db);
		rs = [db executeQuery: @"SELECT revisionnumber FROM committracknode WHERE committracknodeid = ?", 
		   prevNode]; CHECK(db);

		if ([rs next])
		{
			CORevision *newRev = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];

			[self didChangeCurrentNodeFromRevision: oldRev toNode: prevNode revision: newRev onTrackUUID: rootObjectUUID];
			return newRev;
		}
		else
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Unable to find node %q in Commit Track %@ to retrieve revision number", 
				prevNode, rootObjectUUID]; 
		}
	}
	else
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Commit Track not found for object %@!", rootObjectUUID];
	}
	return nil;
}
- (CORevision*)redoOnCommitTrack: (ETUUID*)rootObjectUUID
{
	CORevision *oldRev = [self commitTrackForRootObject:[self keyForUUID: rootObjectUUID]
		                   currentNode: NULL
				  previousNode: NULL
		                      nextNode: NULL];
	NSNumber *rootObjectIndex = [self keyForUUID: rootObjectUUID];
	FMResultSet *rs = [db executeQuery: @"SELECT nextNode FROM commitTrack ct "
		"JOIN commitTrackNode ctn ON ct.currentNode = ctn.committracknodeid "
		"WHERE ct.objectuuid = ?", rootObjectIndex]; CHECK(db);

	if ([rs next])
	{
		NSNumber *nextNode = [NSNumber numberWithLongLong: [rs longLongIntForColumnIndex: 0]];
	
		if ([nextNode longLongValue] == 0)
		{
			[NSException raise: NSInvalidArgumentException
			            format: @"Root Object UUID %@ is already at the end of its commit track and cannot be redone.", rootObjectUUID];
		}

		[db executeUpdate: @"UPDATE commitTrack SET currentnode = ? WHERE objectuuid = ?",
			nextNode, rootObjectIndex]; CHECK(db);
		rs = [db executeQuery: @"SELECT revisionnumber FROM committracknode WHERE committracknodeid = ?", 
			nextNode]; CHECK(db);

		if ([rs next])
		{
			CORevision *newRev = [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
			[self didChangeCurrentNodeFromRevision: oldRev toNode: nextNode revision: newRev onTrackUUID: rootObjectUUID];
			return newRev;
		}
		else
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Unable to find node %q in Commit Track %@ to retrieve revision number", 
				nextNode, rootObjectUUID]; 
		}
	}
	else
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Commit Track not found for object %@!", rootObjectUUID];
	}
	return nil;
}
- (CORevision*)maxRevision: (int64_t)maxRevNumber forRootObjectUUID: (ETUUID*)uuid
{
	if (maxRevNumber <= 0)
		maxRevNumber = [self latestRevisionNumber];
	FMResultSet *rs = [db executeQuery: @"SELECT MAX(revisionnumber) FROM uuids "
		"JOIN commits ON uuids.uuidIndex = commits.objectuuid "
		"WHERE revisionnumber <= ? AND uuids.rootIndex = ?",
		[NSNumber numberWithLongLong: maxRevNumber], [self keyForUUID: uuid]]; CHECK(db);
	if ([rs next])
	{
		return [self revisionWithRevisionNumber: [rs longLongIntForColumnIndex: 0]];
	}
	else
	{
		return nil;
	}
}

- (BOOL)isTrackUUID: (ETUUID *)uuid
{
	NILARG_EXCEPTION_TEST(uuid);
    FMResultSet *rs = [db executeQuery: @"SELECT objectuuid FROM committrack WHERE objectuuid = ?",
	                                    [self keyForUUID: uuid]];
	BOOL result = [rs next];
	[rs close];
	return result;
}

@end

NSString *COStoreDidChangeCurrentNodeOnTrackNotification = @"COStoreDidChangeCurrentNodeOnTrackNotification";
NSString *kCONewCurrentNodeIDKey = @"kCONewCurrentNodeIDKey";
NSString *kCONewCurrentNodeRevisionNumberKey = @"kCONewCurrentNodeRevisionNumberKey";
NSString *kCOOldCurrentNodeRevisionNumberKey = @"kCOOldCurrentNodeRevisionNumberKey";
NSString *kCOStoreUUIDStringKey = @"kCOStoreUUIDStringKey";

@implementation CORecord

- (id)initWithDictionary: (NSDictionary *)aDict
{
	SUPERINIT;
	ASSIGN(dictionary, aDict);
	return self;
}

- (void)dealloc
{
	DESTROY(dictionary);
	[super dealloc];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		[dictionary allKeys]];
}

- (id) valueForProperty: (NSString *)aKey
{
	id value = [dictionary objectForKey: aKey];

	if (value == nil)
	{
		value = [super valueForProperty: aKey];
	}
	return value;
}

- (BOOL) setValue: (id)value forProperty: (NSString *)aKey
{
	if ([[dictionary allKeys] containsObject: aKey])
	{
		if ([dictionary isMutable])
		{
			[(NSMutableDictionary *)dictionary setObject: value forKey: aKey];
			return YES;
		}
		else
		{
			return NO;
		}
	}
	return [super setValue: value forProperty: aKey];
}

@end
