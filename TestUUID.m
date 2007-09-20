/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import <UUID/uuid.h>
#import "COUUID.h"
#import "GNUstep.h"

@interface TestUUID: NSObject <UKTest>
@end

@implementation TestUUID
- (BOOL) handleError: (uuid_rc_t) error
{
	switch(error) {
		case UUID_RC_OK:
			return YES;
		default:
			NSLog(@"UUID Error: %d", error);
			return NO;
	}
}
- (void) testV1
{
	uuid_t *uuid = NULL;
	uuid_rc_t result;
	char *str = NULL;

	result = uuid_create(&uuid);
	UKTrue([self handleError: result]);
	result = uuid_make(uuid, UUID_MAKE_V1);
	UKTrue([self handleError: result]);
	result = uuid_export(uuid, UUID_FMT_STR, (void **)&str, NULL);
	UKTrue([self handleError: result]);
	result = uuid_destroy(uuid);
	UKTrue([self handleError: result]);
	NSLog(@"V1: %s", str);
	free(str);
	str = NULL;
}

- (void) testV3
{
	uuid_t *uuid = NULL;
	uuid_t *uuid_ns = NULL;
	uuid_rc_t result;
	char *str = NULL;

	result = uuid_create(&uuid_ns);
	UKTrue([self handleError: result]);
	result = uuid_create(&uuid);
	UKTrue([self handleError: result]);
	result = uuid_load(uuid_ns, "ns:URL");
	UKTrue([self handleError: result]);
	result = uuid_make(uuid, UUID_MAKE_V3, uuid_ns, "http://www.etoile-project.org");
	UKTrue([self handleError: result]);
	result = uuid_export(uuid, UUID_FMT_STR, (void **)&str, NULL);
	UKTrue([self handleError: result]);
	result = uuid_destroy(uuid_ns);
	UKTrue([self handleError: result]);
	result = uuid_destroy(uuid);
	UKTrue([self handleError: result]);
	NSLog(@"V3: %s", str);
	free(str);
	str = NULL;
}

- (void) testString
{
	NSLog(@"Long testing begins. It should be less than minutes.");
	NSMutableSet *set = [[NSMutableSet alloc] init];
	int i, count = 10000;
	for (i = 0; i < count; i++)
	{
		NSString *uuid = [NSString UUIDString];
		UKNotNil(uuid);
		UKFalse([set containsObject: uuid]);
		[set addObject: uuid];
		//NSLog(@"uuid %@", uuid);
	}
	DESTROY(set);
	NSLog(@"Long testing is done");

	NSURL *u1 = [NSURL URLWithString: @"http://www.gnustep.org"];
	NSURL *u2 = [NSURL URLWithString: @"http://www.gnustep.org"];
	NSURL *u3 = [NSURL URLWithString: @"http://www.etoile-project.org"];

	NSString *s1 = [NSString UUIDStringWithURL: u1];
	NSString *s2 = [NSString UUIDStringWithURL: u2];
	NSString *s3 = [NSString UUIDStringWithURL: u3];
	UKStringsEqual(s1, s2);
	UKStringsNotEqual(s1, s3);
}
@end
