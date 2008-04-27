/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COMetadataServer.h"
#import "GNUstep.h"

#define DEFAULTS [NSUserDefaults standardUserDefaults]
#define FM [NSFileManager defaultManager]

NSString *CODefaultMetadataServerURL = nil;
//NSString *COStoreConfigurationFile = @"StoreConfiguration.plist";

static COMetadataServer *metadataServer = nil;


@implementation CORefRecord : NSObject

- (id) initWithUUID: (ETUUID *)uuid URL: (NSURL *)url
{
	SUPERINIT

	ASSIGN(_uuid, uuid);
	ASSIGN(_url, url);
	[self setRecordInfo: [NSArray array]];

	return self;
}

DEALLOC(DESTROY(_uuid); DESTROY(_url); DESTROY(_recordInfo));

- (ETUUID *) UUID
{
	return _uuid;
}

- (NSURL *) URL
{
	return _url;
}

- (NSArray *) recordInfo
{
	return _recordInfo;
}

- (void) setRecordInfo: (NSArray *)info
{
	ASSIGN(_recordInfo, info);
}

@end


@implementation COMetadataServer

+ (void) initialize
{
	if (self == [COMetadataServer class])
	{
		CODefaultMetadataServerURL = [[NSURL fileURLWithPath: @"~/CoreObjectMetadata"] absoluteString];
	}
}

/** Returns the URL of the default metadata server. 
	This URL points to a bundle where all CoreObject metadatas are stored. Hence 
	the URL can be used to locate both the metadata store and server. */
+ (NSURL *) defaultStoreURL
{
	// FIXME: Use Defaults
	return [NSURL URLWithString: CODefaultMetadataServerURL];
}

/** Returns the default metadata server. 
	For each user, CoreObject maintains a different default metadata store. 
	This method takes care of creating a new metadata store if none can be found
	at the default server URL. It typically happens when CoreObject is run for 
	for the first time. */
+ (id) defaultServer
{
	if (metadataServer == nil)
		metadataServer = [[self alloc] initWithURL: [self defaultStoreURL]];

#if 0	
	/* Found no existing metadata store, we must create one */
	if (metadataServer == nil)
		metadataServer = [[self alloc] createWithURL: [self defaultServerURL]];
#endif

	return metadataServer;
}

/** <init />
	Instantiates and returns a new metadata server instance that will use the 
	metadata store located at baseURL. 
	If no metadata store exists at the given URL, returns nil. */
- (id) initWithURL: (NSURL *)storeURL
{
	SUPERINIT

	ASSIGN(_storeURL, storeURL);
	_URLsByUUIDs = [[NSMutableDictionary alloc] initWithCapacity: 10000];

	return self;
}

- (void) dealloc
{
	DESTROY(_storeURL);
	DESTROY(_URLsByUUIDs);
	[super dealloc];
}

/** Returns the property list that encodes the configuration of the metadata 
	server. This propery list can be edited to control the behavior of the 
	metadata server. */
- (NSMutableDictionary *) configurationDictionary
{
	return nil; // FIXME: Implement
}

/** Returns the URL that was used to instantiate the receiver and where the 
	metadata store is located. */
- (NSURL *) storeURL
{
	return _storeURL;
}

/** Generates ref record by eventually delegating it to NSURLProtocol. */
- (CORefRecord *) refRecordForUUID: (ETUUID *)UUID
{
	NSURL *url = [self URLForUUID: UUID];
	CORefRecord *record = nil;

	if (url != nil)
		record = AUTORELEASE([[CORefRecord alloc] initWithUUID: UUID URL: url]);

	return record;
}

/** Reads UUID in the info.plist of the bundle at url. */
- (ETUUID *) UUIDForURL: (NSURL *)url
{
	return nil; // FIXME: Implement
}

/** Retrieves the URL bound to UUID in the UUID/URL database. */
- (NSURL *) URLForUUID: (ETUUID *)uuid
{
	return [_URLsByUUIDs objectForKey: uuid];
}

/** Binds uuid to url by inserting the UUID/URL pair in the UUID/URL database. */
- (void) setURL: (NSURL *)url forUUID: (ETUUID *)uuid
{
	// TODO: Build a ref record and calls a method that stores the ref record 
	// in a dict or a db.
	[_URLsByUUIDs setObject: url forKey: uuid];
}

/** Unbinds uuid from its associated URL by removing the UUID/URL pair in the
	UUID/URL database. */
- (void) removeURLForUUID: (ETUUID *)uuid
{
	[_URLsByUUIDs removeObjectForKey: uuid];
}

/** Triggers the save of the metadata server state at the serialization URL 
	defined by -storeURL. 
	The save includes the serialization of the store/server configuration and 
	all URL/UUID pairs not yet flushed if the URL/UUID storage backend is a 
	simple dictionary and not a DB. */
- (void) save
{
	//[COSerializer serializeObject: self];
}

@end
