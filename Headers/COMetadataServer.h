/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>


@interface CORefRecord : NSObject
{
	ETUUID *_uuid;
	NSURL *_url;
	NSArray *_recordInfo;
}

- (id) initWithUUID: (ETUUID *)uuid URL: (NSURL *)url;

- (ETUUID *) UUID;
- (NSURL *) URL;
- (NSArray *) recordInfo;
- (void) setRecordInfo: (NSArray *)info;

@end


@interface COMetadataServer : NSObject
{
	NSURL *_storeURL;
	NSMutableDictionary *_URLsByUUIDs;
}

+ (NSURL *) defaultStoreURL;
+ (id) defaultServer;

- (id) initWithURL: (NSURL *)storeURL;

- (CORefRecord *) refRecordForUUID: (ETUUID *)uuid; // generate ref record by eventually delegating it to NSURLProtocol 
- (ETUUID *) UUIDForURL: (NSURL *)url; // read it in the info.plist of the bundle
- (NSURL *) URLForUUID: (ETUUID *)uuid; // lookup in the db
- (void) setURL: (NSURL *)url forUUID: (ETUUID *)uuid;
- (void) removeURLForUUID: (ETUUID *)uuid;

- (NSURL *) storeURL;
- (NSMutableDictionary *) configurationDictionary;
//- (NSDictionary *) propertyList;
- (void) save;

@end

/* Defaults */

extern NSString *CODefaultMetadataServerURL;
