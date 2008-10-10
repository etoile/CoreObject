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
#import "COGroup.h"
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
	[COObjectContext setCurrentContext: NEW(COObjectContext)]; // for safety
	return [self init];
}

- (void) releaseForTest
{
	[COObjectContext setCurrentContext: NEW(COObjectContext)]; // for safety
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

#if 0
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
#endif

- (void) testCacheObject
{
	id object = NEW(COObject);
	
	UKTrue([self cacheObject: object]);
	UKFalse([self cacheObject: object]);
	UKFalse([self cacheObject: [object copy]]); /* UUID is conserved by copy */
}

- (void) testLastSnapshotVersionOfObjectWithURL
{
	[COObject setAutomaticallyMakeNewInstancesPersistent: YES];
	
	COObject *object = AUTORELEASE([[COObject alloc] init]);

	COObjectContext *ctxt = [object objectContext];
	NSURL *objectURL = [ctxt serializationURLForObject: object];

	ETLog(@"UUID is %@ for %@ at URL %@ ", [object UUID], object, objectURL);
	UKIntsEqual(0, [self lastSnapshotVersionOfObjectWithURL: objectURL]);

	/* This first recorded invocation results in a snapshot with version 0, 
       immediately followed by an invocation record with version 1. */
	[object setValue: @"me" forProperty: @"whoami"];
	UKIntsEqual(0, [self lastSnapshotVersionOfObjectWithURL: objectURL]);
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	/* Snapshot is automatically taken only every 100 invocations by default. */
	UKIntsEqual(0, [self lastSnapshotVersionOfObjectWithURL: objectURL]);
	/* We increment the version to a relatively high number, so we can be sure 
	   the test doesn't accidentally pass because we look in the wrong object 
	   bundle. Most of other object bundles created in tests have a version 
	   around 3 or 4. */
	for (int i = 1; i <= 15; i++)
	{
		[ctxt snapshotObject: object];
	}
	/* Base version is zero so we ignore this first snapshot */
	int nbOfSnapshotsFollowingDeltas = 15;
	int nbOfDeltas = 2;
	int lastSnapshotVersion = nbOfDeltas + nbOfSnapshotsFollowingDeltas;
	
	/* An extra delta that makes the last snapshot version different from the 
	   last object version */
	[object setValue: @"hm" forProperty: @"whoami"];

	UKIntsEqual(lastSnapshotVersion, [self lastSnapshotVersionOfObjectWithURL: objectURL]);

	[COObject setAutomaticallyMakeNewInstancesPersistent: NO];
}

@end

@interface COObjectServer (TestPrivate)
+ (void) makeNewDefaultServer;
@end

@interface TestFaulting : NSObject <UKTest>
{
	id objectServer;
	id object;
	id pendingFaultObject;
	id pendingFaultGroup;
	id group;
	id group2;
}

@end

@implementation TestFaulting

- (void) cacheObjects: (NSArray *)objects
{
	FOREACHI(objects, anObject)
	{
		[objectServer cacheObject: anObject];	
	}
}

- (id) initForTest
{
	[COObject setAutomaticallyMakeNewInstancesPersistent: YES];
	[COGroup setAutomaticallyMakeNewInstancesPersistent: YES];
	[COObjectServer makeNewDefaultServer];
	[COObjectContext setCurrentContext: NEW(COObjectContext)]; 

	objectServer = [COObjectServer defaultServer];
	object = [[COObject alloc] init];
	pendingFaultObject = [[COObject alloc] init];
	pendingFaultGroup = [[COGroup alloc] init];
	group = [[COGroup alloc] init];
	group2 = [[COGroup alloc] init];

	[self cacheObjects: 
		A(object, pendingFaultObject, pendingFaultGroup, group, group2)];
	[group addMember: object];
	[group addMember: [pendingFaultObject UUID]];
	/* Be careful to call -addGroup: instead of -addMember: when inserting a 
	   fault marker for a group. -addMember: cannot detect if the parameter 
	   is a group if you pass an UUID as a fault marker. */
	[group2 addGroup: [pendingFaultGroup UUID]];
	[pendingFaultGroup addMember: [pendingFaultObject UUID]];
	[group setHasFaults: YES];
	[group2 setHasFaults: YES];	
	[pendingFaultGroup setHasFaults: YES];

	return self;
}

- (void) releaseForTest
{
	[COObject setAutomaticallyMakeNewInstancesPersistent: NO];
	[COGroup setAutomaticallyMakeNewInstancesPersistent: NO];
	[COObjectServer makeNewDefaultServer];
	[COObjectContext setCurrentContext: NEW(COObjectContext)];

	DESTROY(object);
	DESTROY(pendingFaultObject);
	DESTROY(pendingFaultGroup);
	DESTROY(group);
	DESTROY(group2);

	[super release];	
}

- (void) checkResolvedFaults
{
	/* For now, -tryResolveFault: doesn't check whether other faults remain */
	UKTrue([group hasFaults]);
	UKTrue([group2 hasFaults]);
	UKTrue([pendingFaultGroup hasFaults]);
	UKObjectsEqual(A(object, pendingFaultObject), [group members]);
	UKObjectsEqual(A(pendingFaultGroup), [group2 members]);
	UKObjectsEqual(A(pendingFaultObject), [pendingFaultGroup members]);	
}

- (void) testResolvePendingFaultsWithinCachedObjectGraph
{
	[objectServer resolvePendingFaultsWithinCachedObjectGraph];
	
	[self checkResolvedFaults];
}

- (void) testResolveAllFaultsForUUID
{
	[objectServer resolveAllFaultsForUUID: [pendingFaultObject UUID]];
	[objectServer resolveAllFaultsForUUID: [pendingFaultGroup UUID]];

	[self checkResolvedFaults];
}

@end
