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
#import "COObjectServer.h"
#import "COUtility.h"

#define VISUAL_TEST

#define TEMP_URL (NSURL *)[NSURL fileURLWithPath: @"/tmp/testManagedCoreObject"]
#define FM [NSFileManager defaultManager]
#define APPEND_PATH(path1, path2) [path1 stringByAppendingPathComponent: path2]
#define SubBasicObject TestSerializerSubBasicObject
#define SubObject TestSerializerSubObject

@implementation ETSerializer (Test)
+ (NSURL *) libraryURLForTest
{
	NSString *path = [[FM currentDirectoryPath] stringByAppendingPathComponent: @"TestLibrary"];
	BOOL isDir = NO;
	BOOL hasCreatedDir = [FM createDirectoryAtPath: path attributes: nil];

	if (hasCreatedDir == NO && 
	  ([FM fileExistsAtPath: path isDirectory: &isDir] == NO || isDir == NO))
	{
		ETLog(@"WARNING: Failed to create test library at path %@, a file with "
			"the same name may already exists", path);
	}

	return [NSURL fileURLWithPath: path];
}
@end

/* For testing subclass */
@interface SubBasicObject : NSObject
{
	NSString *whoami;
	NSMutableArray *otherObjects;
@public
	id managedObject;
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
	[serializer serializeObject: object withName: @"test"];

	/* Deserialize */
	id deserializer = [serializer deserializer];
	[deserializer setVersion: 0];
	id newInstance = [deserializer restoreObjectGraph];

	DESTROY(pool);

	return newInstance;
}

@implementation TestSerializer

- (NSURL *) serialize: (id)object atURL: (NSURL *)destURL
{
	id serializer = [ETSerializer defaultCoreObjectSerializerWithURL: destURL];

	CREATE_AUTORELEASE_POOL(pool);
	[serializer serializeObject: object withName: @"test"];
	DESTROY(pool);

	return destURL;
}

- (Class) visualBackendClass
{
	return [ETSerializerBackendXML class];
	//return [ETSerializerBackendExample class];
}

- (void) visualSerialize: (id)object
{
	id serializer = [ETSerializer serializerWithBackend: [self visualBackendClass] forURL: nil];

	CREATE_AUTORELEASE_POOL(pool);
	[serializer serializeObject: object withName: @"visualtest"];
	DESTROY(pool);
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
	return [self unserializeFromURL: [self serialize: object atURL: TEMP_URL]];
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

- (void) testBasicManagedCoreObjectGraphSerialization
{
	id object1 = AUTORELEASE([[SubObject alloc] init]);
	id refObject1 = AUTORELEASE([[SubObject alloc] init]);
	[object1 setValue: A(refObject1, @"New York") forProperty: @"otherObjects"];

	/* First serialize refObject1 in order it can be found as a serialized 
	   object on disk when deserializing object1. */
	NSURL *refObjectURL = [[ETSerializer defaultLibraryURL] URLByAppendingPath: 
		[[refObject1 UUID] stringValue]];
	[ETSerializer serializeObject: refObject1 toURL: refObjectURL];

	/* Check refObject1 serialization */
	NSString *path = [refObjectURL path];
	BOOL isDir = NO;
	//ETLog(@"path %@ -> %@", path, APPEND_PATH(path, @"root/0.save"));
	UKTrue([FM fileExistsAtPath: path isDirectory: &isDir]);
	UKTrue(isDir);

	/* Then serializes object1 and recreates a new instance by deserializing it */
	id object2 = [self roundTrip: object1];

	/* Check object1 serialization */
	UKTrue([FM fileExistsAtPath: [TEMP_URL path] isDirectory: &isDir]);
	UKTrue(isDir);
	//ETLog(@"path %@ -> %@", path, APPEND_PATH(path, @"root/0.save"));
	UKTrue([FM fileExistsAtPath: APPEND_PATH(path, @"root/0.save") isDirectory: &isDir]);
	UKFalse(isDir);
	UKObjectsEqual(A(refObject1, @"New York"), [object1 valueForProperty: @"otherObjects"]);

	/* Check the managed core object graph is properly recreated by deserialization */
	UKNotNil(object2);
	UKStringsEqual([object2 valueForProperty: @"whoami"], [NSString stringWithString: @"Nobody"]);
	UKIntsEqual(2, [[object2 valueForProperty: @"otherObjects"] count]);
	UKStringsEqual(@"New York", [[object2 valueForProperty: @"otherObjects"] lastObject]);
	id loadedRefObject = [[object2 valueForProperty: @"otherObjects"] firstObject];
	UKObjectsEqual([refObject1 UUID], [loadedRefObject UUID]);
	UKObjectsEqual(refObject1, loadedRefObject);
	UKObjectsNotSame(refObject1, loadedRefObject);
}

- (void) testBasicObjectWithManagedObjectIVarSerialization
{
	SubBasicObject *object1 = AUTORELEASE([[SubBasicObject alloc] init]);
	id managedObject = AUTORELEASE([[SubObject alloc] init]);
	object1->managedObject = managedObject;

	/* Autmatic persistency îs disabled on SubObject class so we can carry our 
	   tests without all the CoreObject machinery. However we must cache the 
	   managedObject instance manually, in order to ensure -loadUUID:withName: 
	   will find it in the managed object cache. */
	UKNil([managedObject objectContext]);
	[[COObjectServer defaultServer] cacheObject: managedObject];
	UKNotNil([[COObjectServer defaultServer] cachedObjectForUUID: [managedObject UUID]]);

#ifdef VISUAL_TEST
	[self visualSerialize: object1];
#endif
	SubBasicObject *object2 = [self roundTrip: object1];

	UKObjectsSame(managedObject, object2->managedObject);
}

- (void) dummyMethodWithUUID: (ETUUID *)anUUID { }

- (void) testInvocationWithUUID
{
	id object1 = AUTORELEASE([[SubObject alloc] init]);

	/* Test UUID object serialization */
	id inv = [NSInvocation invocationWithTarget: self 
	                                   selector: @selector(dummyMethodWithUUID:) 
	                                  arguments: A([object1 UUID])];

	[inv setTarget: nil];
#ifdef VISUAL_TEST
	[self visualSerialize: inv];
#endif
	id newInv = [self roundTrip: inv];
	id newUUID = nil;

	UKNil([newInv target]);
	// FIXME: Shouldn't EtoileSerialize or GNUstep NSInvocation implementation 
	// looks up the existing selector instead of creating a new one?
	//UKTrue([inv selector] == [newInv selector]);
	UKStringsEqual(NSStringFromSelector([inv selector]), NSStringFromSelector([newInv selector]));
	/* Serializing an ETUUID instance must result in an UUID object on 
	   deserialization the UUID must not be turned into 'object1' for example. 
	   Only managed objects are serialized as UUIDs and then these UUIDs turned 
	   back into objects on deserialization. */
	[newInv getArgument: &newUUID atIndex: 2];
	UKObjectsEqual([object1 UUID], newUUID);

	/* Test managed Object to UUID serialization */
	inv = [NSInvocation invocationWithTarget: self 
	                                selector: @selector(dummyMethodWithUUID:) 
	                               arguments: A(object1)];

	[[COObjectServer defaultServer] cacheObject: object1];
	[inv setTarget: nil];
#ifdef VISUAL_TEST
	[self visualSerialize: inv];
#endif
	newInv = [self roundTrip: inv];
	id newObject1 = nil;

	UKStringsEqual(NSStringFromSelector([inv selector]), NSStringFromSelector([newInv selector]));
	[newInv getArgument: &newObject1 atIndex: 2];
	UKObjectsSame(object1, newObject1);
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
	[self setAutomaticallyMakeNewInstancesPersistent: NO];

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

