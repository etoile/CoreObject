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
#define NEW(X) (AUTORELEASE([[X alloc] initWithObjectContext: self]))

/* To eliminate a class name collision with other test suites */
#define SubObject SubRecordedObject
//#define SubGroup SubRecordedGroup

@interface SubObject : COObject
@end

@interface COObject (Test)
- (id) initWithObjectContext: (COObjectContext *)ctxt;
@end


@interface COObjectContext (TestObjectContext) <UKTest>
@end

@implementation COObjectContext (TestObjectContext)

- (id) objectByRollingbackObject: (id)object toVersion: (int)aVersion 
{
	return [self objectByRollingbackObject: object toVersion: aVersion mergeImmediately: NO];
}

- (void) testInit
{
	UKNotNil([[self class] defaultContext]);
}

- (void) testLastVersionOfObject
{
	COObject *object = AUTORELEASE([[SubObject alloc] init]);

	COObjectContext *ctxt = [object objectContext];
	NSArray *manyNames = A(@"A", @"B", @"C", @"D", @"E", @"F", @"I", @"G", @"H");

	//ETLog(@"UUID is %@ for %@ at URL %@ ", [object UUID], object, [ctxt serializationURLForObject: object]);
	UKIntsEqual(-1, [ctxt lastVersionOfObject: object]);

	/* This first recorded invocation results in a snapshot with version 0, 
       immediately followed by an invocation record with version 1. */
	[object setValue: @"me" forProperty: @"whoami"];
	UKIntsEqual(1, [ctxt lastVersionOfObject: object]);
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	UKIntsEqual(2, [ctxt lastVersionOfObject: object]);
	/* We increment the version to a relatively high number, so we can be sure 
	   the test doesn't accidentally pass because we look in the wrong object 
	   bundle. Most of other object bundles created in tests have a version 
	   around 3 or 4. */
	FOREACHI(manyNames, name)
	{
		[object setValue: name forProperty: @"whoami"];
	}
	UKIntsEqual(2 + [manyNames count], [ctxt lastVersionOfObject: object]);
}

- (void) testBasicSnapshotRollback
{
	COObject *object = AUTORELEASE([[SubObject alloc] init]);

	UKObjectsEqual([[self class] defaultContext], [object objectContext]);
	UKIntsEqual(-1, [object objectVersion]);

	/* This first recorded invocation results in a snapshot with version 0, 
       immediately followed by an invocation record with version 1. */
	[object setValue: @"me" forProperty: @"whoami"];
	UKIntsEqual(1, [object objectVersion]);
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];
	UKIntsEqual(3, [object objectVersion]);

	id object1v3 = [[object objectContext] objectByRollingbackObject: object toVersion: 0];
	UKStringsEqual(@"Nobody", [object1v3 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSMutableArray arrayWithObject: @"New York"], [object1v3 valueForProperty: @"otherObjects"]);
}

- (void) testPlaybackBasedRollback
{
	COObject *object = AUTORELEASE([[SubObject alloc] initWithObjectContext: self]);

	UKObjectsEqual(self, [object objectContext]);

	[object setValue: @"me" forProperty: @"whoami"];
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];

	UKIntsEqual(3, [object objectVersion]);

	id object1v1 = [self objectByRollingbackObject: object toVersion: 1];
	UKNil([object1v1 objectContext]);
	UKObjectsEqual([object UUID], [object1v1 UUID]);
	UKStringsEqual(@"me", [object1v1 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSArray arrayWithObject: @"New York"], [object1v1 valueForProperty: @"otherObjects"]);

	id object1v2 = [self objectByRollingbackObject: object toVersion: 2];
	UKObjectsEqual([object UUID], [object1v2 UUID]);
	UKStringsEqual(@"me", [object1v2 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [object1v2 valueForProperty: @"otherObjects"]);

	id object1v3 = [self objectByRollingbackObject: object toVersion: 3];
	UKObjectsEqual([object UUID], [object1v3 UUID]);
	UKStringsEqual(@"everybody", [object1v3 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [object1v3 valueForProperty: @"otherObjects"]);
}

- (void) testMultiObjectPersistency
{
	COObject *object = AUTORELEASE([[SubObject alloc] initWithObjectContext: self]);
	COObject *object2 = AUTORELEASE([[SubObject alloc] initWithObjectContext: self]);

	[object setValue: @"me" forProperty: @"whoami"]; // version 1
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];
	[object setValue: @"you" forProperty: @"whoami"];
	[object setValue: [NSArray array] forProperty: @"otherObjects"];
	[object setValue: @"... hm not sure" forProperty: @"whoami"];
	[object2 setValue: @"fox" forProperty: @"whoami"]; // version 1
	UKIntsEqual(1, [object2 objectVersion]);
	[object setValue: @"Who knows!" forProperty: @"whoami"]; // version 7
	[object2 setValue: @"wolf" forProperty: @"whoami"];
	[object2 setValue: @"rabbit" forProperty: @"whoami"];
	[object setValue: @"My name is no name!" forProperty: @"whoami"];

	UKIntsEqual(8, [object objectVersion]);
	UKIntsEqual(3, [object2 objectVersion]);

	id object1v7 = [self objectByRollingbackObject: object toVersion: 7];
	UKNil([object1v7 objectContext]);
	UKObjectsEqual([object UUID], [object1v7 UUID]);
	UKStringsEqual(@"Who knows!", [object1v7 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSArray array], [object1v7 valueForProperty: @"otherObjects"]);
}

- (void) testMerge
{
	COObject *object = NEW(SubObject);
	COObject *object2 = NEW(SubObject);
	COObject *object3 = NEW(SubObject);
	COGroup *group = NEW(COGroup);
	COGroup *group2 = NEW(COGroup);

	UKObjectsEqual(self, [object objectContext]);
	UKObjectsEqual(self, [group objectContext]);

	[group2 addObject: object2];
	[group addObject: object];
	[group addGroup: group2];
	[group2 addObject: object3];

	[object setValue: @"me" forProperty: @"whoami"]; // version 1
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];

	id objectv1 = [self objectByRollingbackObject: object toVersion: 1 mergeImmediately: YES];
	UKStringsEqual(@"me", [objectv1 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [objectv1 valueForProperty: @"otherObjects"]);
	UKFalse([[group objects] containsObject: object]);
	UKTrue([[group objects] containsObject: objectv1]);
	UKFalse([group containsTemporalInstance: objectv1]); // object1 shouldn't be a temporal instance once it's inserted
	UKObjectsSame([[group objects] objectAtIndex: 0], objectv1);
	UKFalse([[self registeredObjects] containsObject: object]);
	UKTrue([[self registeredObjects] containsObject: objectv1]);
}

- (void) testGroupPersistency
{
	COObject *object = NEW(SubObject);
	COObject *object2 = NEW(SubObject);
	COObject *object3 = NEW(SubObject);
	COGroup *group = NEW(COGroup);
	COGroup *group2 = NEW(COGroup);

	UKObjectsEqual(self, [object3 objectContext]);
	UKObjectsEqual(self, [group objectContext]);
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
	UKNil([group1v0 objectContext]);
	UKIntsEqual(0, [group1v0 objectVersion]);
	UKIntsEqual(2, [group objectVersion]);
	UKIntsEqual(2, [self lastVersionOfObject: group1v0]);
	//UKIntsEqual(2, [group1v0 lastObjectVersion]);
	UKTrue([group1v0 isEmpty]);
	UKFalse([group isEmpty]);
	UKObjectsEqual([group UUID], [group1v0 UUID]);
	/* Don't pass because we test equality only on type, UUID and object version. */
	UKObjectsNotEqual(group, group1v0);
	UKTrue([group1v0 isTemporalInstance: group]); 

	/* Test playback rollback (move forward in time) */
	id group1v2 = [self objectByRollingbackObject: group1v0 toVersion: 2];
	UKIntsEqual(2, [group1v2 objectVersion]);
	UKIntsEqual(0, [group1v0 objectVersion]);
	UKIntsEqual(2, [self lastVersionOfObject: group1v2]);
	UKFalse([group1v2 isEmpty]);
	UKObjectsNotEqual(group1v0, group1v2);
	UKObjectsEqual(group, group1v2); // We have return to 'group' state (most recent version)
	UKObjectsEqual([group1v0 UUID], [group1v2 UUID]);
	UKObjectsEqual([group UUID], [group1v2 UUID]);
	UKTrue([group1v2 isTemporalInstance: group1v0]); 
	// Two objects with the same UUID and version don't qualify as temporal instances
	UKFalse([group1v2 isTemporalInstance: group]);
	// FIXME: 
	//UKObjectsEqual([group objects], [group1v2 objects]);

	/* Test playback rollback (move backward in time) */
	id group1v1 = [self objectByRollingbackObject: group1v2 toVersion: 1];
	UKIntsEqual(1, [group1v1 objectVersion]);
	UKIntsEqual(2, [group1v2 objectVersion]);
	UKFalse([group1v1 isEmpty]);
	UKObjectsNotEqual(group1v2, group1v1);
	UKObjectsEqual([group UUID], [group1v1 UUID]);
	UKTrue([group1v1 isTemporalInstance: group1v2]); 
	UKTrue([group1v1 isTemporalInstance: group1v0]);
	UKTrue([group1v1 isTemporalInstance: group]);
	// NOTE: The next two tests only holds if -objects doesn't return subgroups
	// UKObjectsEqual([group objects], [group1v1 objects]);
	UKObjectsNotEqual([group groups], [group1v1 groups]);
	// FIXME:
	//UKObjectsEqual(object, [[group1v1 objects] objectAtIndex: 0]);
	//UKObjectsSame(object, [[group1v1 objects] objectAtIndex: 0]);
}

- (void) testDummySerialization
{
#if 0
	id baseURL = [ETSerializer defaultLibraryURL];
	id inv = [NSInvocation invocationWithTarget: object selector: @selector(description) arguments: [NSArray array]];
	id serializer = [[ETSerializer serializerWithBackend: [ETSerializerBackendBinary class]
								 			  forURL: baseURL] retain];
	//[serializer serializeObject:object withName:@"TestBaseVersion"];
	//[inv setTarget: nil];
	int version = [serializer newVersion];
	[inv setTarget:nil];
	[serializer serializeObject: inv withName:@"TestDelta"];
	[serializer serializeObject: inv withName:@"Anything"];
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

@implementation COObject (Test)

- (id) initWithObjectContext: (COObjectContext *)ctxt
{
	self = [self init];

	[[self objectContext] unregisterObject: self];
	[ctxt registerObject: self];

	return self;
}

@end
