/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COMetadataServer.h"
#import "COUtility.h"

#define DEFAULTS [NSUserDefaults standardUserDefaults]
#define FM [NSFileManager defaultManager]

NSURL *CODefaultMetadataDBURL = nil;
//NSString *COStoreConfigurationFile = @"StoreConfiguration.plist";

static COMetadataServer *metadataServer = nil;


@implementation COMetadataServer

+ (void) initialize
{
	if (self == [COMetadataServer class])
	{
		CODefaultMetadataDBURL = [self defaultDBURL];
	}
}

/** Returns the URL used to initialize the default metadata server. 
	If a default is set for CODefaultMetadataDBURL, this value is returned, 
	otherwise +defaultDBURL value is.
	This URL is used to connect to the DB server (presently a 
	PostgreSQL server) where the metadatas are stored. */
+ (NSURL *) defaultStoreURL
{
	// FIXME: Use Defaults
	return CODefaultMetadataDBURL;
}

/** Returns the default metadata server. 
	For each user, CoreObject maintains a different default metadata store. 
	This method takes care of creating a new metadata store if none can be found
	at the default server URL. It typically happens when CoreObject is run for 
	for the first time. */
+ (id) defaultServer
{
	if (metadataServer == nil)
	{
		metadataServer = [[self alloc] initWithURL: [self defaultStoreURL]
		                    shouldCreateDBIfNeeded: YES];
	}

	return metadataServer;
}

/** <init />
	Instantiates and returns a new metadata server instance that will use the 
	metadata store located at storeURL. 
	If no metadata store exists at the given URL and canCreateDB equals NO, 
	returns nil if no DB can be accessed through this URL. A metadata DB can 
	be accessed if the DB server accepts our connection and finds a DB name 
	that matches the URL path. server accepts our connectionHowever if 
	canCreateDB equals YES and the DB cannot be reached, then tries to create 
	the DB if the DB server accepts our connection.
    Metadata DB URL format: pgsql://user:password@host/dbname */
- (id) initWithURL: (NSURL *)storeURL shouldCreateDBIfNeeded: (BOOL)canCreateDB
{
	SUPERINIT

	if (storeURL != nil)
	{
		ASSIGN(_storeURL, storeURL);
	}
	else
	{
		ASSIGN(_storeURL, [[self class] defaultStoreURL]);
	}
#ifdef DICT_METADATASERVER
	_URLsByUUIDs = [[NSMutableDictionary alloc] initWithCapacity: 10000];
#else
	if ([self setUpWithURL: _storeURL shouldCreateDBIfNeeded: canCreateDB] == NO)
		DESTROY(self);
#endif
	ASSIGN(_fm, [NSFileManager defaultManager]);

	return self;
}

- (void) dealloc
{
	DESTROY(_storeURL);
#ifdef DICT_METADATASERVER
	DESTROY(_URLsByUUIDs);
#else
	[self closeDBConnection];
#endif
	DESTROY(_fm);
	[super dealloc];
}

/* First opens a connection to the DB, if it fails returns NO, otherwise 
   returns YES. 
   If the connection is sucessfully established, asks the DB server for a DB 
   with a name matching the URL path. If none is found and canCreateDB equals 
   YES, sets up a new metadata DB on the server accessed through dbURL and 
   with a name equals to the URL path.
   If dbURL is nil, a local connection will be established. */
- (BOOL) setUpWithURL: (NSURL *)dbURL shouldCreateDBIfNeeded: (BOOL)canCreateDB
{
	if ([self openDBConnectionWithURL: dbURL] == NO)
	{
		// TODO: The connection will fail if the DB has not yet been created, 
		// but relying on this failure to know whether the DB exists or not is 
		// really crude. By connecting to the 'postgres' DB, we could issue a 
		// query to make this test. The query would be:
		// SELECT datname FROM pg_database WHERE datname = 'dbName';
		if (canCreateDB)
		{
			[self setUpDBWithURL: dbURL];
			// TODO: Handle DB creation failure with errors, may be exceptions or 
			// ETLog(@"WARNING: Failed to create DB on server at %@", dbURL);
		}
		if ([self openDBConnectionWithURL: dbURL] == NO)
		{
			ETLog(@"WARNING: Failed to connect to DB server at %@", dbURL);
			return NO;
		}
	}

	[self installDBEventListener];

	return YES;
}

/* DB Interaction */

/** Returns the name to use for the Metadata DB specific to the current user. */
+ (NSString *) defaultDBName
{
	return [NSString stringWithFormat: @"%@_%s", @"coreobject", getenv("USER")];
}

/** Returns the URL to use for the Metadata DB specific to the current user.
    This value is typically used when no DB URL is handed to 
    -initWithURL:shouldCreateDBIfNeeded:.
    See -initWithURL:shouldCreateDBIfNeeded: for the URL format. */
+ (NSURL *) defaultDBURL
{
	return [NSURL URLWithString: [NSString stringWithFormat: 
		@"pgsql://%s@localhost/%@", getenv("USER"), [self defaultDBName]]];
}

/* Trims the leading '/' from the path. */
- (NSString *) stringByTrimmingLeadingSlashInPath: (NSString *)path
{
	if ([path length] <= 1)
		return path;

	return [path substringFromIndex: 1];
}

/** Creates a new Metadata DB at the given URL specified.
    If dbURL is nil, tries to create a local metadata DB.
    If an existing DB connection is already opened, the connection will be lost 
    after calling this method, this shouldn't be a problem normally since the 
    connection to the metadata DB is opened only the DB has already been created.
    See -initWithURL:shouldCreateDBIfNeeded: for the URL format. */
- (void) setUpDBWithURL: (NSURL *)dbURL
{
	NSURL *theDBURL = (dbURL != nil) ? dbURL : [[self class] defaultStoreURL];
	NSString *dbName = [self stringByTrimmingLeadingSlashInPath: [dbURL path]];
	NSURL *pgsqlDBURL = [NSURL URLWithString: [NSString stringWithFormat: 
		@"pgsql://%s@localhost/%@", getenv("USER"), @"postgres"]];

	[self closeDBConnection]; /* In case a connection is already opened */

	// NOTE: The creation of the metadata DB for CoreObject can be done either 
	// in SQL or in the shell. In our case, we use SQL.
	// createdb -O username coreobject-username
	// CREATE DATABASE coreobject-username OWNER username

	/* Create the DB with the current user as the owner */

	[self openDBConnectionWithURL: pgsqlDBURL];
	[self executeDBRequest: [NSString stringWithFormat: @"CREATE DATABASE %@ OWNER %s;", dbName, getenv("USER")]];
	[self closeDBConnection];

	/* Create the DB schema */

	[self openDBConnectionWithURL: theDBURL];

	 // FIXME: UUID should of type UUID instead of text, but the format of
	// -[ETUUID stringValue] isn't understood by pgsql. -stringValue should 
	// return a canonical form or we should add -canonicalStringValue?
	[self executeDBRequest: @"CREATE TABLE UUID ( \
		UUID text PRIMARY KEY, \
		URL text, \
		inode integer, \
		volumeID integer, \
		lastURLModifDate timestamp, \
		objectVersion integer, \
		objectType text, \
		groupCache uuid[]);"];

	/* contextVersion is stored for conveniency, it could be easily found by 
	   selecting all rows for a given contextUUID and sorting them by globalVersion */
	[self executeDBRequest: @"CREATE TABLE History ( \
		objectUUID text, \
		objectVersion integer, \
		contextUUID text, \
		contextVersion integer, \
		date timestamp, \
		globalVersion serial PRIMARY KEY);"]; 
	// NOTE: Global version is mostly needed in case several rows are added in a 
	// few microseconds hence associated with identical timestamps.

	[self closeDBConnection];
}

/** Executes one or more SQL requests separated by colons in a single 
    transaction. Return YES if all the requests succeed, otherwise returns NO 
    and logs a warning for the first SQL request that failed without executing 
    the subsequent ones. */
- (BOOL) executeDBRequest: (NSString *)SQLRequest 
{
	PGresult *result = PQexec(conn, [SQLRequest UTF8String]);
	
	if (result == NULL || PQresultStatus(result) != PGRES_COMMAND_OK)
	{
		ETLog(@"WARNING: Failed to execute SQL request: %@ - %s - %s",
			SQLRequest, PQresStatus(PQresultStatus(result)), PQresultErrorMessage(result));
		[self handleDBRequestFailure];
		PQclear(result);
		return NO;
	}

	PQclear(result);
	return YES;
}

- (id) queryResultObjectWithPGResult: (PGresult *)result
{
	int nbOfRows = PQntuples(result);
	int nbOfCols = PQnfields(result);

	ETDebugLog(@"Query result: %d rows and %d colums", nbOfRows, nbOfCols);

	if (nbOfRows == 1 && nbOfCols == 1)
	{
		return [NSString stringWithUTF8String: PQgetvalue(result, 0, 0)];
	}
	else
	{
		// TODO: Implement. SQLClient returns a SQLRecord object which is an
		// an array. We may rely on SQLClient rather than writing our own code 
		// here. However turning the query result into an array of dictionaries 
		// seems to be pretty easy if we don't care about mapping PGSQL types
		// to ObjC types and we just return strings or data objects as values.
		// Having such a feature right in CoreObject would allow to build a
		// MetadataDB browser easily with EtoileUI and without a dependency on
		// SQLClient.
	}

	return nil;
}

/** Does the same as -executeDBRequest: but handles query result by returning 
    selected rows as a property list built in the following way: 
    - each row is turned into a dictionary
      - each column attribute into a key
      - each column value into a value
    - all rows are turned into an array.
   So the result is an array of dictionaries whose keys are column attributes 
   and values are colum values.
   If the SQL select is done on a single attribute, then no dictionaries are 
   used, the column values are put directly into the array. If a single row is 
   matched for a single attribute, no array is returned but only the matched 
   column value of the selected row. 
   TODO: only single value result are implemented, see 
   -queryResultObjectWithPGResult: for implementing what is described above. */
- (id) executeDBQuery: (NSString *)SQLRequest
{
	PGresult *result = PQexec(conn, [SQLRequest UTF8String]);
	id queryResultObject = nil;

	if (result == NULL || PQresultStatus(result) != PGRES_TUPLES_OK)
	{
		ETLog(@"WARNING: Failed to execute SQL request: %@", SQLRequest);
		[self handleDBRequestFailure];
		PQclear(result);
		return nil;
	}

	queryResultObject = [self queryResultObjectWithPGResult: result];

	PQclear(result);
	return queryResultObject;
}

/** Performs a SQL query and returns the query result in a PGresult data 
    structure specific to PostgreSQL.
    It's strongly advised to use -executeDBQuery: instead of this low-level 
    method, unless if you want to use PostgreSQL specific extensions to SQL. 
    However take in account the underlying metadata DB might not always be 
    driven by PostgreSQL.
    This method doesn't perform any checks on either SQLRequest or the returned 
    result. You are in charge of verifying the result, handling potential 
    failures of the query and freeing the returned structure. */
- (PGresult *) executeRawPGSQLQuery: (NSString *)SQLRequest
{
	return PQexec(conn, [SQLRequest UTF8String]);
}

/** We do nothing for now, we may close the connection, try to close and reopen 
    it, or implement some alternative fallback behaviors in future. */
- (void) handleDBRequestFailure
{

}

/** Destroys all the Metadata DB content by dropping the tables of the schema.
    However the Metadata DB itself isn't dropped. */
- (void) resetDB
{
	[self executeDBRequest: @"DROP TABLE UUID; DROP TABLE History;"];
}

- (void) installDBEventListener
{
	// TODO: Implement later depending on your needs. We could for example
	// listen to objectVersion changes so we can catch managed objects that 
	// become outdated immediately when concurrent write occurs on it, rather 
	// than handling it the next time a managed method is called.
}

/** Connects to the Metadata DB at the URL specified in Defaults and prepares 
    the receiver to read and write metadatas in the DB. 
    A metadata DB can be accessed if the DB server accepts our connection and 
    finds a DB name that matches the URL path.
    TODO: Handles dbURL as documented instead of ingoring it and just connecting 
    to the local server. */
- (BOOL) openDBConnectionWithURL: (NSURL *)dbURL
{
	NSURL *theDBURL = (dbURL != nil) ? dbURL : [[self class] defaultStoreURL];
	NSString *theDBName = [self stringByTrimmingLeadingSlashInPath: [theDBURL path]];

	/*
	* begin, by setting the parameters for a backend connection if the
	* parameters are null, then the system will try to use reasonable
	* defaults by looking up environment variables or, failing that,
	* using hardwired constants
	*/
	char *pghost = NULL; /* host name of the backend server */
	char *pgport = NULL;//[[theDBURL port] UTF8String]; /* port of the backend server */
	char *pgoptions = NULL; /* special options to start up the backend server */
	char *pgtty = NULL; /* debugging tty for the backend server */
	char *dbname = (char *)[theDBName UTF8String];

	/* Uses the URL host only if it doesn't refer to the localhost, because pgsql
	   handles local connection through a socket in tmp directory on Unix. */
	if ([[theDBURL host] isEqual: @"localhost"] == NO 
	 && [[theDBURL host] isEqual: @""] == NO)
	{
		pghost = (char *)[[theDBURL host] UTF8String];
	}

	/* make a connection to the database */
	conn = PQsetdb(pghost, pgport, pgoptions, pgtty, dbname);

	/* check to see that the backend connection was successfully made */
	if (PQstatus(conn) == CONNECTION_BAD)
	{
		ETLog(@"WARNING: Failed to connect to database '%s': %s", dbname, PQerrorMessage(conn));
		return NO;
	}

	return YES;
}

/** Closes the connection to the Metadata DB at the URL specified in Defaults 
    and clean up all infos related to the current DB interaction in the 
    receiver. */
- (void) closeDBConnection
{
	/* If status is CONNECTION_BAD, PQfinish() causes a double free */
	if (conn != NULL && PQstatus(conn) == CONNECTION_OK)
		PQfinish(conn);
}

/** Returns the property list that encodes the configuration of the metadata 
	server. This propery list can be edited to control the behavior of the 
	metadata server. */
- (NSMutableDictionary *) configurationDictionary
{
	// FIXME: Implement, but first figure out which settings should be exposed.
	return nil;
}

/** Returns the URL that was used to instantiate the receiver.*/
- (NSURL *) storeURL
{
	return _storeURL;
}

/** Returns the UUID bound to url by querying the Metadata database. If no such 
    asssociation is found, returns nil.
    The UUID can also be retrieved from the info.plist of the managed object 
    bundle at url, if EtoileSerialize uses the filesystem as store backend. */
- (ETUUID *) UUIDForURL: (NSURL *)url
{
	NSString *uuidString = [self executeDBQuery: [NSString stringWithFormat: 
		@"SELECT UUID FROM UUID WHERE URL = '%@';", [url absoluteString]]];
	ETUUID *uuid = nil;

	ETDebugLog(@"Got UUID %@ for %@", uuidString, url);

	if (uuidString != nil)
		uuid = AUTORELEASE([[ETUUID alloc] initWithString: uuidString]);
	
	return uuid;
}

/** Retrieves the URL bound to uuid in the Metadata database. If no such 
    asssociation is found, returns nil. */
- (NSURL *) URLForUUID: (ETUUID *)uuid
{
#ifdef DICT_METADATASERVER
	return [_URLsByUUIDs objectForKey: uuid];
#else

	NSString *urlString = [self executeDBQuery: [NSString stringWithFormat: 
		@"SELECT URL FROM UUID WHERE UUID = '%@';", [uuid stringValue]]];
	NSURL *url = nil;

	ETDebugLog(@" Got URL %@ for %@", urlString, uuid);

	if (urlString != nil)
		url = [NSURL URLWithString: urlString];

	return url;

#endif
}

/** Calls -setURL:forUUID:withObjectVersion:type:modificationDate: with hint
    values, so that only the URL/UUID pair is updated, but not the additional 
    infos that corresponds to the extra parameters. */
- (void) setURL: (NSURL *)url forUUID: (ETUUID *)uuid 
{
	[self setURL: url forUUID: uuid withObjectVersion: -1
	                                             type: nil
	                                          isGroup: NO
	                                        timestamp: [NSDate date]];
}

/** Binds uuid to url by inserting the UUID/URL pair and eventually additional 
    infos in the Metadata database.
    If an UUID/URL pair already exists, it is deleted then the new one is 
    inserted. For a quick update rather a raw delete/insert, see 
    -updateUUID:toObjectVersion:timestamp:. */
//- (void) setURL: (NSURL *)url forUUID: (ETUUID *)uuid withNewVersion: ofObject:
- (void) setURL: (NSURL *)url forUUID: (ETUUID *)uuid
	withObjectVersion: (int)objectVersion 
	             type: (NSString *)objectType 
	          isGroup: (BOOL)isGroup
	        timestamp: (NSDate *)recordTimestamp
{
#ifdef DICT_METADATASERVER
	[_URLsByUUIDs setObject: url forKey: uuid];
#else

	NSString *prevSQLRequest = @"";
	NSString *nextSQLRequest = @"";
	BOOL isUpdate = ([self URLForUUID: uuid] != nil);

	if (isUpdate)
	{
		prevSQLRequest = [NSString stringWithFormat: 
			@"BEGIN; DELETE FROM UUID WHERE UUID = '%@';", [uuid stringValue]];
		nextSQLRequest = @"COMMIT;";
		
	}

	// NOTE: If using NSFileManager is a source of slowness, we could rewrite 
	// that in C with POSIX functions.
	NSDictionary *fileAttributes = [_fm fileAttributesAtPath: [url path] traverseLink: YES];
	unsigned long inode = [fileAttributes fileSystemFileNumber];
	// FIXME: Should be volumeID and may be removed at later point.
	unsigned long deviceID = [fileAttributes fileSystemNumber];

	[self executeDBRequest: [NSString stringWithFormat: 
		@"%@ INSERT INTO UUID (UUID, URL, inode, volumeID, "
		"lastURLModifDate, objectVersion, objectType) " // TODO: Add groupCache
		"VALUES ('%@', '%@', %i, %i, '%@', %i, '%@'); %@", 
			prevSQLRequest,
			[uuid stringValue], 
			[url absoluteString], 
			(unsigned int)inode, /* POSIX defines ino_t as a unsigned int */
			(unsigned int)deviceID, /* POSIX doesn't define dev_t, but probably safe? */
			recordTimestamp, // NOTE: May need to format the output with -descriptionWithLocale:
			objectVersion,
			objectType,
			nextSQLRequest]];

	ETDebugLog(@"Inserted URL %@ for %@", [url absoluteString], uuid);

#endif
}

/** Unbinds uuid from its associated URL by removing the UUID/URL pair and 
    related infos in the Metadata database. */
- (void) removeURLForUUID: (ETUUID *)uuid
{
#ifdef DICT_METADATASERVER
	[_URLsByUUIDs removeObjectForKey: uuid];
#else

	[self executeDBRequest: [NSString stringWithFormat: 
		@"DELETE FROM UUID WHERE UUID = '%@';", [uuid stringValue]]];

	ETDebugLog(@"Deleted URL %@ for %@", urlString, uuid);

#endif
}

/** Updates the UUID/URL pair infos without a raw delete/insert as all
    -setURL:forUUID: methods does.
    This method is used to quickly update the metadata DB each time a managed 
    object is modified: an invocation is recorded and/or an object snapshot 
    taken. */
- (void) updateUUID: (ETUUID *)uuid 
    toObjectVersion: (int)objectVersion 
          timestamp: (NSDate *)recordTimestamp
{
	[self executeDBRequest: [NSString stringWithFormat: 
		@"UPDATE UUID SET lastURLModifDate = '%@', objectVersion = %i WHERE UUID = '%@';",
			recordTimestamp, // NOTE: May need to format the output with -descriptionWithLocale:
			objectVersion,
			[uuid stringValue]]];

	ETDebugLog(@"Updated UUID %@ to %i %@", uuid, objectVersion, recordTimestamp);
}

@end
