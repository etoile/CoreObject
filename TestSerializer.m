/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import <UnitKit/UnitKit.h>
#import "COObject.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COUtility.h"

#define TEMP_URL (NSURL *)[NSURL fileURLWithPath: @"/tmp/testManagedCoreObject"]
#define FM [NSFileManager defaultManager]
#define APPEND_PATH(path1, path2) [path1 stringByAppendingPathComponent: path2]
#define SubBasicObject TestSerializerSubBasicObject
#define SubObject TestSerializerSubObject

/* For testing subclass */
@interface SubBasicObject : NSObject
{
	NSString *whoami;
	NSMutableArray *otherObjects;
}
- (NSString *) whoami;
- (NSMutableArray *) otherObjects;
@end

@interface SubObject : COObject 
@end

@interface TestSerializer : NSObject <UKTest>
@end

/* Helper functions taken from EtoileSerialize test suite */

id testRoundTrip(id object)
{
	CREATE_AUTORELEASE_POOL(pool);

	/* Serialize */
	id serializer = [ETSerializer defaultCoreObjectSerializerWithURL: TEMP_URL];
	[serializer serializeObject: object withName: "test"];

	/* Deserialize */
	id deserializer = [serializer deserializer];
	[deserializer setVersion: 0];
	id newInstance = [deserializer restoreObjectGraph];

	DESTROY(pool);

	return newInstance;
}

@implementation TestSerializer

- (NSURL *) serialize: (id)object atURL: (NSURL *)anURL
{
	NSURL *destURL = (anURL != nil ? anURL : TEMP_URL);
	id serializer = [ETSerializer defaultCoreObjectSerializerWithURL: destURL];

	CREATE_AUTORELEASE_POOL(pool);
	[serializer serializeObject: object withName: "test"];
	DESTROY(pool);

	return destURL;
}

- (id) unserializeFromURL: (NSURL *)anURL
{
	NSURL *sourceURL = (anURL != nil ? anURL : TEMP_URL);
	id newInstance = nil;

	// FIXME: Is no autorelease pool necessary here?
	//CREATE_AUTORELEASE_POOL(pool);

	id deserializer = [ETDeserializer defaultCoreObjectDeserializerWithURL: sourceURL];

	[deserializer setBranch: @"root"];
	[deserializer setVersion: 0];

	newInstance = [deserializer restoreObjectGraph];

	//DESTROY(pool);

	return newInstance;
}

- (id) roundTrip: (id)object
{
	return [self unserializeFromURL: [self serialize: object atURL: nil]];
}

- (void) testBasicObjectSerialization
{
	id object1 = AUTORELEASE([[SubBasicObject alloc] init]);
#ifdef DIRECT_ROUNDTRIP
	id object2 = testRoundTrip(object1);
#else
	id object2 = [self roundTrip: object1];
#endif
	NSString *path = [TEMP_URL path];
	BOOL isDir = NO;

	UKTrue([FM fileExistsAtPath: path isDirectory: &isDir]);
	UKTrue(isDir);
	//ETLog(@"path %@ -> %@", path, APPEND_PATH(path, @"root/0.save"));
	UKTrue([FM fileExistsAtPath: APPEND_PATH(path, @"root/0.save") isDirectory: &isDir]);
	UKFalse(isDir);
	UKObjectsEqual([object1 otherObjects], A(@"New York"));

	UKNotNil(object2);
	UKStringsEqual([object2 whoami], [NSString stringWithString: @"Nobody"]);
	UKObjectsEqual([object2 otherObjects], A(@"New York"));
}

- (void) testCOObjectSerialization
{
	id object1 = AUTORELEASE([[SubObject alloc] init]);
#ifdef DIRECT_ROUNDTRIP
	id object2 = testRoundTrip(object1);
#else
	id object2 = [self roundTrip: object1];
#endif
	NSString *path = [TEMP_URL path];
	BOOL isDir = NO;

	UKTrue([FM fileExistsAtPath: path isDirectory: &isDir]);
	UKTrue(isDir);
	//ETLog(@"path %@ -> %@", path, APPEND_PATH(path, @"root/0.save"));
	UKTrue([FM fileExistsAtPath: APPEND_PATH(path, @"root/0.save") isDirectory: &isDir]);
	UKFalse(isDir);
	UKObjectsEqual([object1 valueForProperty: @"otherObjects"], A(@"New York"));

	UKNotNil(object2);
	UKStringsEqual([object2 valueForProperty: @"whoami"], [NSString stringWithString: @"Nobody"]);
	UKObjectsEqual([object2 valueForProperty: @"otherObjects"], A(@"New York"));
}

- (void) testManagedObjectSerialization
{

}

@end


/* NSObject subclass */

@implementation SubBasicObject

- (id) init
{
	SUPERINIT
	whoami = @"Nobody";
	otherObjects = [[NSMutableArray alloc] initWithObjects: @"New York", nil];
	return self;
}

DEALLOC(DESTROY(otherObjects))

- (NSString *) whoami { return whoami; }
- (NSMutableArray *) otherObjects { return otherObjects; }

@end

/* COObject subclasses */

@implementation SubObject

+ (void) initialize
{
	/* We need to repeat what is in COObject 
	   because GNU objc runtime will not call super for this method */
	NSDictionary *pt = [COObject propertiesAndTypes];
	[SubObject addPropertiesAndTypes: pt];

    pt = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt: kCOStringProperty],
            @"whoami",
        [NSNumber numberWithInt: kCOArrayProperty],
            @"otherObjects",
        nil];
    [SubObject addPropertiesAndTypes: pt];

    DESTROY(pt);
}

- (id) init
{
	SUPERINIT
	[self setValue: @"Nobody"
	      forProperty: @"whoami"];
	[self setValue: [NSMutableArray arrayWithObject: @"New York"]
	      forProperty: @"otherObjects"];
	return self;
}

@end

