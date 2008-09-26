/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import <UnitKit/UnitKit.h>
#import "COObjectServer.h"
#import "COMetadataServer.h"
#import "COObject.h"
#import "COObjectContext.h"
#import "COSerializer.h"
#import "CODeserializer.h"

#define FM [NSFileManager defaultManager]
#define TMP_URL [NSURL fileURLWithPath: [FM tempDirectory]]
#define NEW(X) (AUTORELEASE([[X alloc] init]))

@interface COObjectServer (TestObjectServer) <UKTest>
@end

@implementation COObjectServer (TestObjectServer)

- (id) initForTest
{
	return [self init];
}

- (void) releaseForTest
{
	[super release];
}

- (void) testObjectForUUID
{
	// TODO: Test for exception on nil uuid.
	
	id object = NEW(COObject);
	id uuid = [object UUID];
	
	UKNil([self objectForUUID: uuid]);
	
	[self cacheObject: object];
	UKObjectsSame(object, [self objectForUUID:  uuid]);
	
	/* Test transparent deserialization when no object is cached. */
	id url = TMP_URL;
	[self removeCachedObject: object];
	[[self metadataServer] setURL: url forUUID: uuid];
	[ETSerializer serializeObject: object toURL: url];
	id newInstance = [self objectForUUID: uuid];
	
	UKObjectsEqual(object, newInstance);
	UKObjectsNotSame(object, newInstance);
	 /* Be sure the new instance gets properly cached */
	UKObjectsSame(newInstance, [self objectForUUID: uuid]);
}

- (void) testManagedObjectForURL
{
	// TODO: Test for exception on nil url.
	
	id object = NEW(COObject);
	id url = TMP_URL;
	
	UKNil([self managedObjectForURL: url]);
	
	[ETSerializer serializeObject: object toURL: url];
	id newInstance = [self managedObjectForURL: url];
	UKNotNil(newInstance);
	UKObjectsNotSame(object, newInstance);
	UKNil([self managedObjectForURL: url]);

	[self removeCachedObject: newInstance];
	newInstance = [self managedObjectForURL: url];
	UKNotNil(newInstance);
	
	[self removeCachedObject: newInstance];
	[self cacheObject: [ETDeserializer deserializeObjectWithURL: url]];
	UKNotNil([self managedObjectForURL: url]);
	
}

- (void) testCacheObject
{
	id object = NEW(COObject);
	
	UKTrue([self cacheObject: object]);
	UKFalse([self cacheObject: object]);
	UKFalse([self cacheObject: [object copy]]); /* UUID is conserved by copy */
}

@end
