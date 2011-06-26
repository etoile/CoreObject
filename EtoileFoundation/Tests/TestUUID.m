/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "Macros.h"
#import "ETUUID.h"
#import "EtoileCompatibility.h"
#include "glibc_hack_unistd.h"

@interface TestUUID: NSObject <UKTest>
@end

@implementation TestUUID

- (void) testUUIDObject
{
	id uuid = [ETUUID UUID];

	UKNotNil(uuid);
	UKNotNil([uuid stringValue]);
	UKTrue([uuid UUIDValue] != NULL);

	id uuid2 = [[ETUUID alloc] initWithUUID: [uuid UUIDValue]];

	UKObjectsEqual(uuid, uuid2);

	id uuid3 = [[ETUUID alloc] initWithString: [uuid stringValue]];

	UKObjectsEqual(uuid, uuid3);
	UKObjectsEqual([uuid stringValue], [uuid3 stringValue]);

	id uuidString = [NSString UUIDString];
	id uuid4 = [[ETUUID alloc] initWithString: uuidString];
	id uuid5 = [[ETUUID alloc] initWithString: uuidString];

	UKObjectsEqual(uuidString, [uuid4 stringValue]);
	UKObjectsNotEqual(uuid, uuid4);
	UKObjectsEqual(uuid5, uuid4);
}

- (void) testHash
{
	id uuid = [ETUUID UUID];

	UKTrue([uuid hash] == [uuid hash]);
	UKFalse([uuid hash] == [[ETUUID UUID] hash]);
	
	/* Test collection lookup */
	NSDictionary *dict = D(@"uuid1", uuid, @"uuid2", [ETUUID UUID]);
	id uuidClone = AUTORELEASE([[ETUUID alloc] initWithUUID: [uuid UUIDValue]]);

	UKObjectsEqual(@"uuid1", [dict objectForKey: uuid]);
	UKObjectsEqual(@"uuid1", [dict objectForKey: uuidClone]);
	UKNil([dict objectForKey: [ETUUID UUID]]);

	/* Test hash collisions a bit */
	NSMutableSet *hashSet = [NSMutableSet set];
	NSNumber *hashNumber  = nil;

	BOOL fail = NO;
	for (int i = 0; i < 10000; i++)
	{
		uuid = [ETUUID UUID];
		hashNumber = [NSNumber numberWithUnsignedInt: [uuid hash]];

		if ([hashSet containsObject: hashNumber])
		{
			NSLog(@"Generated invalid hash %@ with UUID %@ at iteration %d", 
				hashNumber, uuid, i);
			fail = YES;
		}

		[hashSet addObject: hashNumber];
	}
	UKFalse(fail);
}

- (void) testString
{
	NSMutableSet *set = [[NSMutableSet alloc] init];
	int i, count = 10000;

	/* Check collisions inside a random sequence */
	BOOL fail = NO;
	for (i = 0; i < count; i++)
	{
		NSString *uuid = [NSString UUIDString];

		if (uuid == nil || [set containsObject: uuid])
		{
			NSLog(@"Generated invalid UUID %@ at iteration %d", uuid, i);
			fail = YES;
		}

		[set addObject: uuid];
		//NSLog(@"uuid %@", uuid);
	}
	UKFalse(fail);

	/* Check collision accross random sequences. If such a collision occurs, it 
	   is normally a seed collision that results in two or more identical 
	   random sequences. 
	   This loop puts pressure on the entropy pool, hence after after few 
	   iterations ETSRandomDev (and probably srandomdev too) quickly switches to 
	   the fallback seed creation based on gettimeofday(), which is the only 
	   thing really exerced here. 
	   A more exhaustive test would involve more iterations and relatively 
	   random pid and junk value. These doesn't changed within a process time.*/
	fail = NO;
	for (i = 0; i < 2000; i++)
	{
		 /* Wait 1 microsecond, otherwise collisions are numerous within a 
		    single process, and beyond 3000 iterations collisions occur also. */
		usleep(1);
		[ETUUID initialize]; /* Will call srandomdev or equivalent */
		NSString *uuid = [NSString UUIDString];

		if (uuid == nil || [set containsObject: uuid])
		{
			NSLog(@"Generated invalid UUID %@ at iteration %d", uuid, i);
			fail = YES;
		}

		[set addObject: uuid];
		//NSLog(@"uuid %@", uuid);
	}
	UKFalse(fail);

	DESTROY(set);
}

@end
