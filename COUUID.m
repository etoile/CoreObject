/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COUUID.h"
#import <UUID/uuid.h>

@implementation NSString (COUUID)

+ (NSString *) UUIDString
{
	uuid_t *uuid = NULL;
	uuid_rc_t result;
	char *str = NULL;
	NSString *return_string;

	result = uuid_create(&uuid);
	if (result != UUID_RC_OK)
		return nil;

	result = uuid_make(uuid, UUID_MAKE_V1);
	if (result != UUID_RC_OK)
	{
		uuid_destroy(uuid);
		return nil;
	}

	result = uuid_export(uuid, UUID_FMT_STR, (void **)&str, NULL);
	if (result != UUID_RC_OK)
	{
		uuid_destroy(uuid);
		return nil;
	}

	return_string = [NSString stringWithUTF8String: str];
	uuid_destroy(uuid);
	free(str);
	return return_string;
}

+ (NSString *) UUIDStringWithURL: (NSURL *) url
{
	uuid_t *uuid = NULL;
	uuid_t *uuid_ns = NULL;
	uuid_rc_t result;
	char *str = NULL;
	NSString *return_string;

	result = uuid_create(&uuid);
	if (result != UUID_RC_OK)
		return nil;

	result = uuid_create(&uuid_ns);
	if (result != UUID_RC_OK)
	{
		uuid_destroy(uuid);
		return nil;
	}
	
	result = uuid_load(uuid_ns, "ns:URL");
	if (result != UUID_RC_OK)
	{
		uuid_destroy(uuid);
		uuid_destroy(uuid_ns);
		return nil;
	}
	
	result = uuid_make(uuid, UUID_MAKE_V3, uuid_ns, [[url absoluteString] UTF8String]);
	if (result != UUID_RC_OK)
	{
		uuid_destroy(uuid);
		uuid_destroy(uuid_ns);
		return nil;
	}

	result = uuid_export(uuid, UUID_FMT_STR, (void **)&str, NULL);
	if (result != UUID_RC_OK)
	{
		uuid_destroy(uuid);
		uuid_destroy(uuid_ns);
		return nil;
	}
	return_string = [NSString stringWithUTF8String: str];
	uuid_destroy(uuid);
	uuid_destroy(uuid_ns);
	free(str);
	return return_string;
}

@end
