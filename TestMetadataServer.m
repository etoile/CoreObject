/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import <UnitKit/UnitKit.h>
#import "COMetadataServer.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COUtility.h"

#define FM [NSFileManager defaultManager]
#define TMP_URL [NSURL fileURLWithPath: [FM tempDirectory]]
#define TMP_URL_DIR TMP_URL


@interface TestRefRecord : NSObject <UKTest>
@end

@interface COMetadataServer (TestMetadataServer) <UKTest>
@end


@implementation TestRefRecord

- (void) testInit
{
	id uuid = [ETUUID UUID];
	id url = TMP_URL;
	id record = [[CORefRecord alloc] initWithUUID: uuid URL: url];

	UKNotNil(record);
	UKNotNil([record UUID]);
	UKObjectsEqual(uuid, [record UUID]);
	UKNotNil([record URL]);
	UKObjectsEqual(url, [record URL]);
	UKNotNil(record);
	UKNotNil([record recordInfo]);
	UKObjectsEqual([NSArray array], [record recordInfo]);
}

@end


@implementation COMetadataServer (TestMetadataServer)

- (void) testInit
{
	id url = TMP_URL_DIR;
	id server = [[COMetadataServer alloc] initWithURL: url];

	UKNotNil(server);
	UKNotNil([server storeURL]);
	UKObjectsEqual(url, [server storeURL]);
}

- (id) initForTest
{
	return [self initWithURL: TMP_URL_DIR];
}

+ (void) testDefaultStoreURL
{
	UKNotNil([self defaultStoreURL]);
}

+ (void) testDefaultServer
{
	UKNotNil([self defaultServer]);
}

- (void) testUUIDForURL: (NSURL *)url
{

}

- (void) testURLForUUID
{
	id url = TMP_URL;
	id uuid = [ETUUID UUID];
	id uuid2 = [ETUUID UUID];

	[self setURL: url forUUID: uuid];

	UKNotNil([self URLForUUID: uuid]);
	UKObjectsEqual(url, [self URLForUUID: uuid]);
	UKObjectsNotEqual(url, [self URLForUUID: uuid2]);

	[self setURL: url forUUID: uuid2];

	UKObjectsEqual([self URLForUUID: uuid], [self URLForUUID: uuid2]);

	[self setURL: TMP_URL forUUID: uuid];

	UKObjectsNotEqual([self URLForUUID: uuid], [self URLForUUID: uuid2]);
}

- (void) testRemoveURLForUUID
{
	id url = TMP_URL;
	id uuid = [ETUUID UUID];

	[self setURL: url forUUID: uuid];
	[self removeURLForUUID: uuid];

	UKNil([self URLForUUID: uuid]);
}

@end
