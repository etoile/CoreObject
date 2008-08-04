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
	id object = AUTORELEASE([[SubObject alloc] init]);

	[object setValue: @"me" forProperty: @"whoami"];
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];

	id object1v3 = [self objectByRollingbackObject: object toVersion: 0];
	UKStringsEqual(@"Nobody", [object1v3 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSMutableArray arrayWithObject: @"New York"], [object1v3 valueForProperty: @"otherObjects"]);
}

- (void) testPlaybackBasedRollback
{
	id object = AUTORELEASE([[SubObject alloc] init]);

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
	id object = AUTORELEASE([[SubObject alloc] init]);
	id object2 = AUTORELEASE([[SubObject alloc] init]);

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

	// TODO: Come up with something prettier and less verbose such as 
	// -[COObject disablePersistency] and -enablePersistency may be...
	[[self objectContext] unregisterObject: self];
	[self setValue: @"Nobody"
	      forProperty: @"whoami"];
	[self setValue: [NSMutableArray arrayWithObject: @"New York"]
	      forProperty: @"otherObjects"];
	[[self objectContext] registerObject: self];

	return self;
}

@end
