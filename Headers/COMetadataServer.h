/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <postgresql/libpq-fe.h>

/** Before being able to  create a DB, both the rights to access the PostgreSQL 
    server and to create a DB must be granted to the user with the following 
    command:
    sudo -u postgres createuser --no-superuser --no-createrole --createdb username
    setup-coreobject.sh script takes care of that. If you run the setup.sh 
    script that takes care of setting up the whole Etoile environment, the
    CoreObject setup script will be automically run.
    -setUpDBWithName: manages the rest of the metadata DB creation, and the DB 
    can eventually be fully reset by calling -resetDBWithName: followed by 
    -setUpDBWithName:. You never need to worry about these methods normally, 
    because -initWithURL:shouldCreateDBIfNeeded: knows how to handle all the 
    details. */
@interface COMetadataServer : NSObject
{
	NSURL *_storeURL;
#ifdef DICT_METADATASERVER
	NSMutableDictionary *_URLsByUUIDs;
#else /* PGSQL */
	PGconn *conn;
#endif
	NSFileManager *_fm; /* Cache */
}

+ (NSURL *) defaultStoreURL;
+ (id) defaultServer;

- (id) initWithURL: (NSURL *)storeURL shouldCreateDBIfNeeded: (BOOL)canCreateDB;

- (ETUUID *) UUIDForURL: (NSURL *)url; // read it in the info.plist of the bundle
- (NSURL *) URLForUUID: (ETUUID *)uuid; // lookup in the db
- (void) setURL: (NSURL *)url forUUID: (ETUUID *)uuid;
- (void) setURL: (NSURL *)url forUUID: (ETUUID *)uuid
	withObjectVersion: (int)objectVersion 
	             type: (NSString *)objectType 
	          isGroup: (BOOL)isGroup
	        timestamp: (NSDate *)recordTimestamp;
- (void) removeURLForUUID: (ETUUID *)uuid;
- (void) updateUUID: (ETUUID *)uuid 
    toObjectVersion: (int)objectVersion
          timestamp: (NSDate *)recordTimestamp;
- (int) objectVersionForUUID: (ETUUID *)anUUID;

- (NSURL *) storeURL;
- (NSMutableDictionary *) configurationDictionary;
// TODO: Should we support exporting the metadata DB as a plist?
//- (NSDictionary *) propertyList;

/* DB Interaction */

+ (NSString *) defaultDBName;
+ (NSURL *) defaultDBURL;

- (BOOL) setUpWithURL: (NSURL *)dbURL shouldCreateDBIfNeeded: (BOOL)canCreateDB;
- (void) setUpDBWithURL: (NSURL *)dbURL;
- (BOOL) executeDBRequest: (NSString *)SQLRequest;
- (id) executeDBQuery: (NSString *)SQLRequest;
- (PGresult *) executeRawPGSQLQuery: (NSString *)SQLRequest;
- (void) handleDBRequestFailure;
- (void) installDBEventListener;
- (BOOL) openDBConnectionWithURL: (NSURL *)dbURL;
- (void) closeDBConnection;

@end

/* Defaults */

extern NSURL *CODefaultMetadataServerURL;
