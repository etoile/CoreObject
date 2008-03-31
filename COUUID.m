/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COUUID.h"

@implementation COUUID
- (id) init
{
	if(nil == (self = [super init])) { return nil; }
	int status;
	uuid_create(&uuid, &status);
	if(status != uuid_s_ok)
	{
		[self release];
		return nil;
	}
	return self;
}
- (id) initWithString:(NSString*)aString
{
	if(nil == (self = [super init])) { return nil; }
	int status;
	uuid_from_string([aString UTF8String], &uuid, &status);
	if(status != uuid_s_ok)
	{
		[self release];
		return nil;
	}
	return self;
}
- (BOOL) isEqualTo:(id)anObject
{
	if(![anObject isKindOfClass:[self class]])
	{
		return NO;
	}
	uuid_t *u2 = [anObject uuid];
	int status;
	return (uuid_compare(&uuid, u2, &status) == 0);
}
- (NSString*) stringValue
{
	char * str;
	int status;
	uuid_to_string(&uuid, &str, &status);
	if(status != uuid_s_ok)
	{
		return nil;
	}
	NSString * u = [NSString stringWithUTF8String:str];
	free(str);
	return u;
}
- (uuid_t*) uuid
{
	return &uuid;
}
@end


@implementation NSString (COUUID)
+ (NSString *) UUIDString
{
	COUUID * uuid = [[COUUID alloc] init];
	NSString * str = [uuid stringValue];
	[uuid release];
	return str;
}
@end
