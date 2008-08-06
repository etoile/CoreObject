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
#import "COGroup.h"
#import "COObjectContext.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COUtility.h"

#define FM [NSFileManager defaultManager]
#define TMP_URL [NSURL fileURLWithPath: [FM tempDirectory]]

/* To eliminate a class name collision with other test suites*/
#define SubObject SubRecordedObject
//#define SubGroup SubRecordedGroup

@interface SubObject : COObject
@end

//@interface SubGroup : COGroup
//@end


@interface COObjectContext (TestObjectContext) <UKTest>
@end

@implementation COObjectContext (TestObjectContext)

- (void) testInit
{
	UKNotNil([[self class] defaultContext]);
}

- (void) testBasicSnapshotRollback
{
	COObject *object = AUTORELEASE([[SubObject alloc] init]);

	[object setValue: @"me" forProperty: @"whoami"];
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];

	id object1v3 = [self objectByRollingbackObject: object toVersion: 0];
	UKStringsEqual(@"Nobody", [object1v3 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSMutableArray arrayWithObject: @"New York"], [object1v3 valueForProperty: @"otherObjects"]);
}

- (void) testPlaybackBasedRollback
{
	COObject *object = AUTORELEASE([[SubObject alloc] init]);

	[object setValue: @"me" forProperty: @"whoami"];
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];

	id object1v1 = [self objectByRollingbackObject: object toVersion: 1];
	UKStringsEqual(@"me", [object1v1 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSArray arrayWithObject: @"New York"], [object1v1 valueForProperty: @"otherObjects"]);

	id object1v2 = [self objectByRollingbackObject: object toVersion: 2];
	UKStringsEqual(@"me", [object1v2 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [object1v2 valueForProperty: @"otherObjects"]);

	id object1v3 = [self objectByRollingbackObject: object toVersion: 3];
	UKStringsEqual(@"everybody", [object1v3 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [object1v3 valueForProperty: @"otherObjects"]);
}

- (void) testMultiObjectPersistency
{
	COObject *object = AUTORELEASE([[SubObject alloc] init]);
	COObject *object2 = AUTORELEASE([[SubObject alloc] init]);

	[object setValue: @"me" forProperty: @"whoami"]; // version 1
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];
	[object setValue: @"you" forProperty: @"whoami"];
	[object setValue: [NSArray array] forProperty: @"otherObjects"];
	[object setValue: @"... hm not sure" forProperty: @"whoami"];
	[object2 setValue: @"fox" forProperty: @"whoami"]; // version 1
	[object setValue: @"Who knows!" forProperty: @"whoami"]; // version 7
	[object2 setValue: @"wolf" forProperty: @"whoami"];
	[object2 setValue: @"rabbit" forProperty: @"whoami"];
	[object setValue: @"My name is no name!" forProperty: @"whoami"];

	id object1v7 = [self objectByRollingbackObject: object toVersion: 7];
	UKStringsEqual(@"Who knows!", [object1v7 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSArray array], [object1v7 valueForProperty: @"otherObjects"]);
}

- (void) testGroupPersistency
{
	COObject *object = AUTORELEASE([[SubObject alloc] init]);
	COObject *object2 = AUTORELEASE([[SubObject alloc] init]);
	COObject *object3 = AUTORELEASE([[SubObject alloc] init]);
	COGroup *group = AUTORELEASE([[COGroup alloc] init]);
	COGroup *group2 = AUTORELEASE([[COGroup alloc] init]);

	UKIntsEqual(-1, [object objectVersion]);
	UKIntsEqual(-1, [group objectVersion]);
	UKIntsEqual(-1, [group2 objectVersion]);

	[group2 addObject: object2];
	[group addObject: object];

	UKIntsEqual(-1, [object objectVersion]);
	UKIntsEqual(1, [group objectVersion]);
	UKIntsEqual(1, [group2 objectVersion]);

	[group addGroup: group2];

	UKIntsEqual(2, [group objectVersion]);
	UKIntsEqual(1, [group2 objectVersion]);

	[group2 addObject: object3];

	UKIntsEqual(2, [group2 objectVersion]);

	/* Test snapshot rollback */
	id group1v0 = [self objectByRollingbackObject: group toVersion: 0];
	UKIntsEqual(0, [group1v0 objectVersion]);
	UKIntsEqual(2, [group objectVersion]);
	UKTrue([group1v0 isEmpty]);
	UKFalse([group isEmpty]);
	UKObjectsEqual([group UUID], [group1v0 UUID]);
	/* Pass because we test equality only on UUID and type, probably a valid 
	   choice but we may make it stricter by testing the objectVersion and 
	   introducing another equality test -isTemporalInstance:.
	   Another choice is to keep -isEqual: as is and adds -isTemporarilyEqual: */
	UKObjectsEqual(group, group1v0); 

	/* Test playback rollback (move forward in time) */
	id group1v2 = [self objectByRollingbackObject: group1v0 toVersion: 2];
	UKIntsEqual(2, [group1v2 objectVersion]);
	UKIntsEqual(0, [group1v0 objectVersion]);
	UKFalse([group1v2 isEmpty]);
	UKObjectsEqual([group UUID], [group1v2 UUID]);
	UKObjectsEqual([group objects], [group1v2 objects]);

	/* Test playback rollback (move backward in time) */
	id group1v1 = [self objectByRollingbackObject: group1v2 toVersion: 1];
	UKIntsEqual(1, [group1v1 objectVersion]);
	UKIntsEqual(2, [group1v2 objectVersion]);
	UKFalse([group1v1 isEmpty]);
	UKObjectsEqual([group UUID], [group1v1 UUID]);
	// NOTE: The next two tests only holds if -objects doesn't return subgroups
	UKObjectsEqual([group objects], [group1v1 objects]);
	UKObjectsNotEqual([group groups], [group1v1 groups]);
	UKObjectsEqual(object, [[group1v1 objects] objectAtIndex: 0]);
	//UKObjectsSame(object, [[group1v1 objects] objectAtIndex: 0]); // FIXME
}

- (void) testDummySerialization
{
#if 0
	id baseURL = [ETSerializer defaultLibraryURL];
	id inv = [NSInvocation invocationWithTarget: object selector: @selector(description) arguments: [NSArray array]];
	id serializer = [[ETSerializer serializerWithBackend: [ETSerializerBackendBinary class]
								 			  forURL: baseURL] retain];
	//[serializer serializeObject:object withName:"TestBaseVersion"];
	//[inv setTarget: nil];
	int version = [serializer newVersion];
	[inv setTarget:nil];
	[serializer serializeObject: inv withName:"TestDelta"];
	[serializer serializeObject: inv withName:"Anything"];
#endif
}

@end

@implementation SubObject

+ (void) initialize
{
	[super initialize];

	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt: kCOStringProperty],
            @"whoami",
        [NSNumber numberWithInt: kCOArrayProperty],
            @"otherObjects",
        nil];
    [self addPropertiesAndTypes: pt];
	[self setAutomaticallyMakeNewInstancesPersistent: YES];

    DESTROY(pt);
}

- (id) init
{
	SUPERINIT

	[self disablePersistency];
	[self setValue: @"Nobody"
	      forProperty: @"whoami"];
	[self setValue: [NSMutableArray arrayWithObject: @"New York"]
	      forProperty: @"otherObjects"];
	[self enablePersistency];

	return self;
}

@end
